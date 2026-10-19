// Calendar days through the sync (SyncTables.dayColumns).
//
// A day of pointage is « Karim, 12 October », not a moment. It used to travel
// as midnight in the sending tablet's time zone, and a tablet in another time
// zone read it back at 01:00 — where « Payer ce jour » found nothing to pay —
// or on the day before. A day now travels as midnight UTC of its date and
// comes back as local midnight of that date.

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/database/sync_tables.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/models/models.dart';
import 'package:stock_inventory/services/auth_service.dart';
import 'package:stock_inventory/services/sync_service.dart';

import '../support/db_fixture.dart';
import '../support/fake_account_backend.dart';

void main() {
  group('the rule', () {
    test('a day received is local midnight of its date, whatever the time '
        'zone it was sent from', () {
      final october12 = DateTime(2026, 10, 12);
      for (final sent in [
        '2026-10-12T00:00:00.000Z', // the new way: midnight UTC
        '2026-10-11T22:00:00+00:00', // Brussels in summer (UTC+2), the old way
        '2026-10-11T23:00:00+00:00', // UTC+1
        '2026-10-12T05:00:00+00:00', // five hours behind UTC
        '2026-10-12T00:00:00+02:00', // with the offset kept
      ]) {
        expect(SyncTables.dayReceived(sent), october12, reason: sent);
      }
    });

    test('a day sent is midnight UTC of its local date, even one received '
        'shifted before', () {
      for (final local in [
        DateTime(2026, 10, 12),
        DateTime(2026, 10, 12, 1), // the phone's 01:00
        DateTime(2026, 10, 11, 22), // shifted to the day before
      ]) {
        expect(
          SyncTables.daySent(_asStored(local)),
          '2026-10-12T00:00:00.000Z',
          reason: '$local',
        );
      }
    });

    test('a pay period\'s bounds and a journée are days too; a moment is not', () {
      expect(SyncTables.dayColumns['attendances'], {'date'});
      expect(SyncTables.dayColumns['business_days'], {'date'});
      expect(SyncTables.dayColumns['payroll_periods'], {
        'start_date',
        'end_date',
      });
      expect(SyncTables.dayColumns['attendance_sessions'], isNull);
    });
  });

  group('two tablets', () {
    late FakeAccountBackend server;
    late String organization;

    setUp(() async {
      server = FakeAccountBackend();
      organization = server.addOrganization('Brasserie');
      server.addUser(
        'owner@resto.be',
        'motdepasse',
        organizationId: organization,
      );
      await server.signIn(email: 'owner@resto.be', password: 'motdepasse');
    });

    Future<AppDatabase> newDevice() async {
      final db = openEmptyDatabase();
      await server.registerDevice(await DeviceRepository(db).deviceId());
      await DeviceAccessRepository(db).writeAccount(
        email: 'owner@resto.be',
        organizationId: organization,
        organizationName: 'Brasserie',
        role: 'owner',
      );
      return db;
    }

    Future<void> sync(AppDatabase db) async {
      final result = await SyncRunner(db: db, backend: server).run();
      expect(result.outcome, isNot(SyncOutcome.failed), reason: result.detail);
    }

    DateTime on(int day, int hour) => DateTime(2026, 10, day, hour);

    /// A store, its owner and Karim, hired on 1 January; Karim worked on the
    /// 12th, 08:00 → 16:00, and the journée is closed. Made on A, synced to B.
    Future<({Store store, Employee owner, Employee cook, Attendance day})>
    workedDay(AppDatabase a, AppDatabase b) async {
      final store = await StoreRepository(a).createStore(
        name: 'Brasserie',
        addressLine: '',
        postalCode: '',
        city: 'Namur',
        phone: '081',
      );
      Future<Employee> employee(String first, EmployeeRole role) async =>
          (await EmployeeRepository(a).create(
            storeId: store.id,
            firstName: first,
            lastName: 'Test',
            pin: 'PIN-$first',
            phone: '081',
            email: '$first@resto.be',
            role: role,
            pay: 15,
            hireDate: DateTime(2026, 1, 1),
          ))!;
      final owner = await employee('Léa', EmployeeRole.owner);
      final cook = await employee('Karim', EmployeeRole.staff);
      final entry = (await AttendanceRepository(
        a,
      ).clockIn(cook.id, store.id, now: on(12, 8)))!;
      await AttendanceRepository(a).clockOut(entry.id, now: on(12, 16));
      final journee = (await BusinessDayRepository(a).current(store.id))!;
      await BusinessDayRepository(a, clock: () => on(12, 23)).close(
        journee.id,
        closedByEmployeeId: owner.id,
      );
      await sync(a);
      await sync(b);
      return (
        store: store,
        owner: owner,
        cook: cook,
        day: (await AttendanceRepository(a).attendance(entry.id))!,
      );
    }

    test('the server gets midnight UTC; the other tablet gets its own '
        'midnight', () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await workedDay(a, b);

      expect(
        server.serverRows['attendances|${shop.day.id}']!['date'],
        '2026-10-12T00:00:00.000Z',
      );
      final journee = server.serverRows.entries.singleWhere(
        (e) => e.key.startsWith('business_days|'),
      );
      expect(journee.value['date'], '2026-10-12T00:00:00.000Z');

      final onB = (await AttendanceRepository(b).attendance(shop.day.id))!;
      expect(onB.date, DateTime(2026, 10, 12));
    });

    test('a day the server still holds the old way arrives on its date, and '
        'can be paid', () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await workedDay(a, b);

      // As a tablet in Brussels sent it before: 12 October 00:00+02:00.
      final old = {
        ...server.serverRows['attendances|${shop.day.id}']!,
        'date': '2026-10-11T22:00:00+00:00',
      };
      await SyncApplier(b).apply(
        shop.store.id,
        PullPage(
          changes: [PulledChange(seq: 999, table: 'attendances', row: old)],
          nextAfter: 999,
          hasMore: false,
        ),
      );

      final onB = (await AttendanceRepository(b).attendance(shop.day.id))!;
      expect(onB.date, DateTime(2026, 10, 12));
      final period = await PayrollRepository(b).pay(
        shop.cook.id,
        shop.store.id,
        from: onB.date,
        to: onB.date,
        paidByEmployeeId: shop.owner.id,
      );
      expect(period, isNotNull);

      // The payment goes up with its bounds as days too.
      await sync(b);
      final sent = server.serverRows['payroll_periods|${period!.id}']!;
      expect(sent['start_date'], '2026-10-12T00:00:00.000Z');
      expect(sent['end_date'], '2026-10-12T00:00:00.000Z');
    });

    test('« Payer ce jour » pays a day stored at 01:00, as on the phone',
        () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await workedDay(a, b);

      // The phone's day: 12 October at 01:00, received shifted.
      await (b.update(b.attendances)..where((r) => r.id.equals(shop.day.id)))
          .write(AttendancesCompanion(date: Value(on(12, 1))));
      final day = (await AttendanceRepository(b).attendance(shop.day.id))!;
      expect(day.date, on(12, 1));

      final payroll = PayrollRepository(b);
      final preview = await payroll.preview(
        shop.cook.id,
        shop.store.id,
        from: day.date,
        to: day.date,
      );
      expect(preview.days, hasLength(1), reason: 'it used to find nothing');
      expect(
        await payroll.pay(
          shop.cook.id,
          shop.store.id,
          from: day.date,
          to: day.date,
          paidByEmployeeId: shop.owner.id,
          expected: preview,
        ),
        isNotNull,
      );
    });

    test('the attendance history up to the 12th shows a day stored at 01:00',
        () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await workedDay(a, b);
      await (b.update(b.attendances)..where((r) => r.id.equals(shop.day.id)))
          .write(AttendancesCompanion(date: Value(on(12, 1))));

      final page = await AttendanceRepository(
        b,
      ).watchPage(shop.store.id, from: on(12, 0), to: on(12, 0)).first;
      expect([for (final d in page.rows) d.id], [shop.day.id]);
    });
  });

}

/// [local] as drift stores it: ISO-8601 with the tablet's offset.
String _asStored(DateTime local) {
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final hours = offset.inHours.abs().toString().padLeft(2, '0');
  final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
  return '${local.toIso8601String()}$sign$hours:$minutes';
}
