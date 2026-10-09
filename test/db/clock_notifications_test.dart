// Arrivée and départ notifications: an employee's Pointer and Fin de journée
// reach the feed only when the owner has switched them on.

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stock_inventory/core/utils/formatters.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart'
    show EmployeeIds, StoreIds;
import 'package:stock_inventory/models/models.dart';

import '../support/db_fixture.dart';

void main() {
  late AppDatabase db;
  late AccountRepository account;
  late StoreRepository stores;

  // The app initialises it in `main()`; the times in the texts need it.
  setUpAll(() => initializeDateFormatting(Formatters.locale));

  setUp(() async {
    db = await openSeededDatabase();
    account = AccountRepository(db);
    stores = StoreRepository(db);
  });

  AttendanceRepository repo({DateTime? at}) =>
      AttendanceRepository(db, clock: () => at ?? seedInstant);

  /// The arrivées and départs in the feed, oldest first.
  Future<List<NotificationItem>> pointages() async {
    final all = await account.notifications(StoreIds.sablon);
    return all
        .where(
          (n) =>
              n.kind == NotificationKind.clockIn ||
              n.kind == NotificationKind.clockOut,
        )
        .toList()
        .reversed
        .toList();
  }

  Future<Attendance> clockIn(String employeeId, {DateTime? at}) async =>
      (await repo(at: at).clockIn(employeeId, StoreIds.sablon, now: at))!;

  Future<void> switchOn({bool clockIn = true, bool clockOut = true}) =>
      stores.setNotificationPreference(
        StoreIds.sablon,
        clockIn: clockIn,
        clockOut: clockOut,
      );

  test('both switches are off by default', () async {
    final settings = await stores.settings(StoreIds.sablon);
    expect(settings.notifyClockIn, isFalse);
    expect(settings.notifyClockOut, isFalse);
  });

  test('switched off, a Pointer and a Fin de journée file nothing', () async {
    final day = await clockIn(EmployeeIds.noah);
    await repo().clockOut(day.id);

    expect(await pointages(), isEmpty);
  });

  test('switched on, an arrivée and a départ each file one notification',
      () async {
    await switchOn();

    final day = await clockIn(
      EmployeeIds.noah,
      at: seedInstant.subtract(const Duration(hours: 2)),
    );
    await repo().clockOut(day.id);

    final filed = await pointages();
    expect(filed.map((n) => n.kind), [
      NotificationKind.clockIn,
      NotificationKind.clockOut,
    ]);
    expect(filed.first.title, 'Arrivée : Noah Van Damme');
    expect(filed.last.title, 'Départ : Noah Van Damme');
    expect(filed.every((n) => n.relatedEmployeeId == EmployeeIds.noah), isTrue);
    expect(filed.every((n) => !n.isRead), isTrue);
  });

  test('only the switch that is on files', () async {
    await switchOn(clockOut: false);

    final day = await clockIn(EmployeeIds.noah);
    await repo().clockOut(day.id);

    expect((await pointages()).map((n) => n.kind), [NotificationKind.clockIn]);
  });

  // The dedupe of `emit` is per employee: a second employee's arrival is not
  // a repeat of the first one's.
  test('two employees arriving file two arrivées', () async {
    await switchOn();

    await clockIn(EmployeeIds.noah);
    await clockIn(EmployeeIds.julien);

    final filed = await pointages();
    expect(filed, hasLength(2));
    expect(filed.map((n) => n.relatedEmployeeId).toSet(), {
      EmployeeIds.noah,
      EmployeeIds.julien,
    });
  });

  test('a split shift files two arrivées and two départs', () async {
    await switchOn();
    final morning = seedInstant.subtract(const Duration(hours: 4));
    final noon = seedInstant.subtract(const Duration(hours: 2));
    final evening = seedInstant.subtract(const Duration(hours: 1));

    final day = await clockIn(EmployeeIds.noah, at: morning);
    await repo(at: noon).clockOut(day.id, now: noon);
    await clockIn(EmployeeIds.noah, at: evening);
    await repo().clockOut(day.id);

    expect((await pointages()).map((n) => n.kind), [
      NotificationKind.clockIn,
      NotificationKind.clockOut,
      NotificationKind.clockIn,
      NotificationKind.clockOut,
    ]);
  });

  // An exit a manager enters in the employee's place is not a départ that
  // is happening now.
  test('an exit entered by a manager files no départ', () async {
    await switchOn();

    final day = await clockIn(
      EmployeeIds.noah,
      at: seedInstant.subtract(const Duration(hours: 3)),
    );
    await repo().endShift(
      day.id,
      seedInstant.subtract(const Duration(hours: 1)),
      setByEmployeeId: EmployeeIds.marc,
    );

    expect((await pointages()).map((n) => n.kind), [NotificationKind.clockIn]);
  });
}
