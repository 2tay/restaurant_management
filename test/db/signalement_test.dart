// Signalements (SYNC_PERSONNEL_PLAN.md, step 3): « signalé au gérant et au
// propriétaire ».
//
// One mechanism: a notification of kind `personnel`, filed by
// `AccountRepository.signal`. Its id comes from the situation, so the same
// situation is filed once however many tablets settle it; and a manager and
// the owner each read it for themselves.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart'
    show EmployeeIds, StoreIds;
import 'package:stock_inventory/models/models.dart';

import '../support/db_fixture.dart';

const _store = StoreIds.sablon;

void main() {
  late AppDatabase db;
  late AccountRepository account;

  setUp(() async {
    db = await openSeededDatabase();
    account = AccountRepository(db);
    // The seeded feed starts read, so the counts below are the signalement's.
    await account.markAllRead(_store);
  });

  tearDown(() => db.close());

  Future<bool> signal([String key = 'double_clock_in:day-1']) =>
      account.signal(
        storeId: _store,
        key: key,
        title: 'Double pointage : Noah',
        body: 'À vérifier.',
        employeeId: EmployeeIds.noah,
      );

  Future<NotificationItem> signalementFor(EmployeeRole viewer) async =>
      (await account.notifications(
        _store,
        viewer: viewer,
      )).singleWhere((n) => n.kind == NotificationKind.personnel);

  test('is a personnel notification about the employee', () async {
    expect(await signal(), isTrue);

    final item = await signalementFor(EmployeeRole.owner);
    expect(item.id, AccountRepository.signalId('double_clock_in:day-1'));
    expect(item.relatedEmployeeId, EmployeeIds.noah);
    expect(item.isRead, isFalse);
    expect(await account.unreadNotificationCount(
      _store,
      viewer: EmployeeRole.owner,
    ), 1);
  });

  test('the same situation is filed once', () async {
    expect(await signal(), isTrue);
    expect(await signal(), isFalse);
    expect(await signal('double_clock_in:day-2'), isTrue);

    final all = await account.notifications(_store);
    expect(
      all.where((n) => n.kind == NotificationKind.personnel),
      hasLength(2),
    );
  });

  test('the id is the same on every tablet, and fits the column', () {
    final id = AccountRepository.signalId('double_clock_in:day-1');
    expect(AccountRepository.signalId('double_clock_in:day-1'), id);
    expect(AccountRepository.signalId('double_clock_in:day-2'), isNot(id));
    expect(id.length, lessThanOrEqualTo(64));
  });

  test('a manager reading it does not hide it from the owner', () async {
    await signal();

    expect(
      await account.markRead(
        AccountRepository.signalId('double_clock_in:day-1'),
        viewer: EmployeeRole.manager,
      ),
      isTrue,
    );

    expect((await signalementFor(EmployeeRole.manager)).isRead, isTrue);
    expect((await signalementFor(EmployeeRole.owner)).isRead, isFalse);
    expect(await account.unreadNotificationCount(
      _store,
      viewer: EmployeeRole.manager,
    ), 0);
    expect(await account.unreadNotificationCount(
      _store,
      viewer: EmployeeRole.owner,
    ), 1);
  });

  test('"tout marquer comme lu" marks it for that role only', () async {
    await signal();

    expect(await account.markAllRead(_store, viewer: EmployeeRole.owner), 1);
    expect(await account.markAllRead(_store, viewer: EmployeeRole.owner), 0);

    expect((await signalementFor(EmployeeRole.owner)).isRead, isTrue);
    expect((await signalementFor(EmployeeRole.manager)).isRead, isFalse);
  });

  test('other notifications stay read for everyone at once', () async {
    final delivery = (await account.emit(
      storeId: _store,
      kind: NotificationKind.delivery,
      title: 'Livraison',
      body: 'Reçue.',
    ))!;

    await account.markRead(delivery.id, viewer: EmployeeRole.manager);

    final asOwner = (await account.notifications(
      _store,
      viewer: EmployeeRole.owner,
    )).singleWhere((n) => n.id == delivery.id);
    expect(asOwner.isRead, isTrue);
  });
}
