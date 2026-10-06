// Signalements (SYNC_PERSONNEL_PLAN.md, step 3): « signalé au gérant et au
// propriétaire ».
//
// One mechanism: a notification of kind `personnel`, filed by
// `AccountRepository.signal`. Its id comes from the situation, so the same
// situation is filed once however many tablets settle it; and each person —
// every manager, the owner — reads it for themselves (schema v23).

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart'
    show EmployeeIds, StoreIds;
import 'package:stock_inventory/models/models.dart';

import '../support/db_fixture.dart';

const _store = StoreIds.sablon;

const NotificationViewer _owner = (
  id: EmployeeIds.marc,
  role: EmployeeRole.owner,
);
const NotificationViewer _manager = (
  id: EmployeeIds.amelie,
  role: EmployeeRole.manager,
);

/// A second manager: what reading per person, rather than per role, is for.
const NotificationViewer _otherManager = (
  id: EmployeeIds.karim,
  role: EmployeeRole.manager,
);

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

  Future<NotificationItem> signalementFor(NotificationViewer viewer) async =>
      (await account.notifications(
        _store,
        viewer: viewer,
      )).singleWhere((n) => n.kind == NotificationKind.personnel);

  test('is a personnel notification about the employee', () async {
    expect(await signal(), isTrue);

    final item = await signalementFor(_owner);
    expect(item.id, AccountRepository.signalId('double_clock_in:day-1'));
    expect(item.relatedEmployeeId, EmployeeIds.noah);
    expect(item.isRead, isFalse);
    expect(await account.unreadNotificationCount(_store, viewer: _owner), 1);
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
        viewer: _manager,
      ),
      isTrue,
    );

    expect((await signalementFor(_manager)).isRead, isTrue);
    expect((await signalementFor(_owner)).isRead, isFalse);
    expect(await account.unreadNotificationCount(_store, viewer: _manager), 0);
    expect(await account.unreadNotificationCount(_store, viewer: _owner), 1);
  });

  test('one manager reading it does not hide it from another', () async {
    await signal();

    await account.markRead(
      AccountRepository.signalId('double_clock_in:day-1'),
      viewer: _manager,
    );

    expect((await signalementFor(_manager)).isRead, isTrue);
    expect((await signalementFor(_otherManager)).isRead, isFalse);
    expect(
      await account.unreadNotificationCount(_store, viewer: _otherManager),
      1,
    );
  });

  test('"tout marquer comme lu" marks it for that person only', () async {
    await signal();

    expect(await account.markAllRead(_store, viewer: _owner), 1);
    expect(await account.markAllRead(_store, viewer: _owner), 0);

    expect((await signalementFor(_owner)).isRead, isTrue);
    expect((await signalementFor(_manager)).isRead, isFalse);
  });

  test('a read is one row, whose id is the same on every tablet', () async {
    await signal();
    final id = AccountRepository.signalId('double_clock_in:day-1');

    await account.markRead(id, viewer: _manager);
    // Already read: nothing more is written.
    expect(await account.markRead(id, viewer: _manager), isFalse);

    final reads = await db.select(db.notificationReads).get();
    expect(reads, hasLength(1));
    expect(reads.single.id, AccountRepository.readId(id, EmployeeIds.amelie));
    expect(reads.single.employeeId, EmployeeIds.amelie);
    expect(reads.single.storeId, _store);
    // The notification itself is untouched: every other reader shares it.
    final row = await (db.select(
      db.notifications,
    )..where((n) => n.id.equals(id))).getSingle();
    expect(row.isRead, isFalse);
    expect(row.readByManagerAt, isNull);
  });

  // Before schema v23 a signalement was read per role. One already read that
  // way stays read for that role — the upgrade turns nothing unread.
  test('a read by role from before v23 still counts', () async {
    await signal();
    final id = AccountRepository.signalId('double_clock_in:day-1');
    await (db.update(db.notifications)..where((n) => n.id.equals(id))).write(
      NotificationsCompanion(readByManagerAt: Value(DateTime(2026, 10, 1))),
    );

    expect((await signalementFor(_manager)).isRead, isTrue);
    expect((await signalementFor(_otherManager)).isRead, isTrue);
    expect((await signalementFor(_owner)).isRead, isFalse);
    expect(await account.markRead(id, viewer: _manager), isFalse);
  });

  test('other notifications stay read for everyone at once', () async {
    final delivery = (await account.emit(
      storeId: _store,
      kind: NotificationKind.delivery,
      key: 'delivery:test',
      title: 'Livraison',
      body: 'Reçue.',
    ))!;

    await account.markRead(delivery.id, viewer: _manager);

    final asOwner = (await account.notifications(
      _store,
      viewer: _owner,
    )).singleWhere((n) => n.id == delivery.id);
    expect(asOwner.isRead, isTrue);
  });
}
