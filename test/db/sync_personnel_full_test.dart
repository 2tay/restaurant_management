// SYNC_PERSONNEL_PLAN.md, steps 1 to 8, end to end — every rule in one place.
//
// Two tablets of one restaurant, a fake server that applies the same rules as
// `push_changes` (partial updates, `overwrote`, `day_already_paid`,
// `paid_day_frozen`), and for each rule the situation the plan describes:
// what each tablet does offline, a few rounds of sync, and what both tablets
// hold afterwards — the same thing on both, and a signalement when the plan
// says « signalé ». The cases that must stay quiet are here too.
//
// The finer cases of each step also live in `sync_conflicts_test.dart`,
// `attendance_merge_test.dart`, `signalement_test.dart`, `outbox_test.dart`
// and `migration_test.dart`.

import 'package:drift/drift.dart' show Variable;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/core/utils/attendance_status.dart';
import 'package:stock_inventory/core/utils/credential_status.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/database/sync_tables.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/models/models.dart';
import 'package:stock_inventory/services/sync_service.dart';

import '../support/db_fixture.dart';
import '../support/fake_account_backend.dart';
import 'schema/schema.dart';

typedef Shop = ({Store store, Employee owner, Employee cook});

void main() {
  late FakeAccountBackend server;
  late String organization;

  setUp(() async {
    server = FakeAccountBackend();
    organization = server.addOrganization('Brasserie');
    server.addUser('owner@resto.be', 'motdepasse', organizationId: organization);
    await server.signIn(email: 'owner@resto.be', password: 'motdepasse');
  });

  // --- Two tablets ------------------------------------------------------------

  Future<AppDatabase> newDevice() async {
    final db = openEmptyDatabase();
    addTearDown(db.close);
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
    expect(result.outcome, SyncOutcome.done, reason: result.detail);
  }

  /// [first] sends first, then [second]; a few rounds, until both are empty.
  Future<void> settle(AppDatabase first, AppDatabase second) async {
    for (var round = 0; round < 4; round++) {
      await sync(first);
      await sync(second);
    }
    expect(await OutboxRepository(first).pendingCount(), 0);
    expect(await OutboxRepository(second).pendingCount(), 0);
  }

  /// A's establishment and two people — Léa the owner, Karim in the kitchen
  /// at 15 € — known to both tablets.
  Future<Shop> shared(AppDatabase a, AppDatabase b) async {
    final store = await StoreRepository(a).createStore(
      name: 'Brasserie',
      addressLine: '',
      postalCode: '',
      city: 'Namur',
      phone: '081',
    );
    Future<Employee> employee(String first, String pin, EmployeeRole role) async =>
        (await EmployeeRepository(a).create(
          storeId: store.id,
          firstName: first,
          lastName: 'Test',
          pin: pin,
          phone: '081',
          email: '$first@resto.be',
          role: role,
          pay: 15,
        ))!;
    final owner = await employee('Léa', 'PIN-LEA', EmployeeRole.owner);
    final cook = await employee('Karim', 'PIN-KARIM', EmployeeRole.staff);
    await sync(a);
    await sync(b);
    return (store: store, owner: owner, cook: cook);
  }

  // --- Reading what a tablet holds --------------------------------------------

  DateTime at(int hour, [int minute = 0, int day = 12]) =>
      DateTime(2026, 10, day, hour, minute);

  Future<List<NotificationItem>> flags(
    AppDatabase db,
    String storeId, {
    EmployeeRole? viewer,
  }) async => [
    for (final n in await AccountRepository(
      db,
    ).notifications(storeId, viewer: viewer))
      if (n.kind == NotificationKind.personnel) n,
  ];

  Future<Attendance> dayOf(AppDatabase db, String employeeId, [int day = 12]) async =>
      (await AttendanceRepository(db).forEmployee(
        employeeId,
      )).singleWhere((a) => a.date == DateTime(2026, 10, day));

  Future<List<BusinessDayRow>> liveJournees(AppDatabase db) =>
      (db.select(db.businessDays)..where((d) => d.deletedAt.isNull())).get();

  /// Karim clocks in at 8:00 on [db], and both tablets see it.
  Future<String> karimIn(AppDatabase a, AppDatabase b, Shop shop) async {
    final id = (await AttendanceRepository(
      a,
    ).clockIn(shop.cook.id, shop.store.id, now: at(8)))!.id;
    await settle(a, b);
    return id;
  }

  /// Karim works [day] 8:00–16:00 on [db] (8 h at 15 €), journée closed.
  Future<void> workDay(AppDatabase db, Shop shop, int day) async {
    final entry = (await AttendanceRepository(
      db,
    ).clockIn(shop.cook.id, shop.store.id, now: at(8, 0, day)))!;
    await AttendanceRepository(db).clockOut(entry.id, now: at(16, 0, day));
    final journee = (await BusinessDayRepository(db).current(shop.store.id))!;
    await BusinessDayRepository(db, clock: () => at(23, 0, day)).close(
      journee.id,
      closedByEmployeeId: shop.owner.id,
    );
  }

  // ===========================================================================
  // Step 1 — the merge: schema v21, upgrades lose nothing
  // ===========================================================================

  group('step 1 — schema v21', () {
    final verifier = SchemaVerifier(GeneratedHelper());

    test('a fresh database is v21', () async {
      final db = openEmptyDatabase();
      addTearDown(db.close);
      expect(db.schemaVersion, 21);
      for (final table in ['business_days', 'login_states']) {
        final found = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
              variables: [Variable<String>(table)],
            )
            .get();
        expect(found, hasLength(1), reason: table);
      }
    });

    for (final from in [13, 16, 20]) {
      test('a v$from install upgrades to v21 cleanly', () async {
        final connection = await verifier.startAt(from);
        final db = AppDatabase.withExecutor(connection);
        await verifier.migrateAndValidate(db, 21);
        await db.close();
      });
    }
  });

  // ===========================================================================
  // Step 2 — the journée de service syncs (P5)
  // ===========================================================================

  group('step 2 — the journée de service', () {
    test('a journée opened on A reaches B, with the new columns', () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);

      await karimIn(a, b, shop);

      final onB = (await BusinessDayRepository(b).current(shop.store.id))!;
      expect(onB.date, DateTime(2026, 10, 12));
      final store = await StoreRepository(b).settings(shop.store.id);
      expect(store.businessDayAutoOpenMinutes, 300);
    });

    test('P5 — opened on both: one kept (the smaller id), nothing moves',
        () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);
      await AttendanceRepository(a).clockIn(shop.cook.id, shop.store.id, now: at(8));
      await AttendanceRepository(b).clockIn(shop.owner.id, shop.store.id, now: at(8));
      final ids = [
        (await liveJournees(a)).single.id,
        (await liveJournees(b)).single.id,
      ]..sort();

      await settle(a, b);

      for (final db in [a, b]) {
        expect((await liveJournees(db)).single.id, ids.first);
        expect((await dayOf(db, shop.cook.id)).sessions, hasLength(1));
        expect((await dayOf(db, shop.owner.id)).sessions, hasLength(1));
      }
    });

    test('P5 — a close made on the journée dropped is kept', () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);
      final onA = (await BusinessDayRepository(a).open(shop.store.id, now: at(8)))!;
      final onB = (await BusinessDayRepository(b).open(shop.store.id, now: at(8)))!;
      final dropped = onA.id.compareTo(onB.id) > 0 ? a : b;
      await BusinessDayRepository(dropped).close(
        dropped == a ? onA.id : onB.id,
        closedByEmployeeId: shop.owner.id,
        now: at(23),
      );

      await settle(a, b);

      for (final db in [a, b]) {
        expect((await liveJournees(db)).single.closedAt, at(23));
      }
    });
  });

  // ===========================================================================
  // Step 3 — signalements: one per situation, read separately
  // ===========================================================================

  group('step 3 — signalements', () {
    test('one signalement on every tablet, read separately by the manager '
        'and the owner', () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);
      // A double pointage (P1) is the situation signalled.
      await AttendanceRepository(a).clockIn(shop.cook.id, shop.store.id, now: at(8));
      await AttendanceRepository(b).clockIn(shop.cook.id, shop.store.id, now: at(8));
      await settle(a, b);

      final onA = (await flags(a, shop.store.id)).single;
      expect((await flags(b, shop.store.id)).single.id, onA.id);
      expect(onA.title, contains('Double pointage'));

      await AccountRepository(a).markRead(onA.id, viewer: EmployeeRole.manager);
      for (final db in [a, b]) {
        await sync(db);
      }
      expect(
        (await flags(b, shop.store.id, viewer: EmployeeRole.manager))
            .single
            .isRead,
        isTrue,
      );
      expect(
        (await flags(b, shop.store.id, viewer: EmployeeRole.owner))
            .single
            .isRead,
        isFalse,
        reason: 'the manager reading it does not hide it from the owner',
      );

      await AccountRepository(b).markRead(onA.id, viewer: EmployeeRole.owner);
      await settle(a, b);
      for (final db in [a, b]) {
        for (final viewer in [EmployeeRole.manager, EmployeeRole.owner]) {
          expect(
            (await flags(db, shop.store.id, viewer: viewer)).single.isRead,
            isTrue,
          );
        }
      }
    });
  });

  // ===========================================================================
  // Step 4 — only the changed fields travel (E2 different fields, E3)
  // ===========================================================================

  group('step 4 — only the changed fields', () {
    test('E2 — different fields on two tablets: both kept', () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);

      await EmployeeRepository(a).update(shop.cook.id, phone: '0499 11 22 33');
      await EmployeeRepository(b).update(shop.cook.id, lastName: 'Benali');
      await settle(a, b);

      for (final db in [a, b]) {
        final cook = (await EmployeeRepository(db).employee(shop.cook.id))!;
        expect(cook.phone, '0499 11 22 33');
        expect(cook.lastName, 'Benali');
      }
    });

    test('E2 — the same field: the last sent wins, the same everywhere',
        () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);

      await EmployeeRepository(a).update(shop.cook.id, phone: '0499 00 00 0A');
      await EmployeeRepository(b).update(shop.cook.id, phone: '0499 00 00 0B');
      await settle(a, b);

      for (final db in [a, b]) {
        expect(
          (await EmployeeRepository(db).employee(shop.cook.id))!.phone,
          '0499 00 00 0B',
        );
      }
    });

    test('E3 — archived on one, edited on the other: stays archived',
        () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);

      await EmployeeRepository(a).archive(shop.cook.id);
      await EmployeeRepository(b).update(shop.cook.id, phone: '0499 44 55 66');
      await settle(a, b);

      for (final db in [a, b]) {
        final cook = (await EmployeeRepository(db).employee(shop.cook.id))!;
        expect(cook.archivedAt, isNotNull);
        expect(cook.phone, '0499 44 55 66');
      }
    });
  });

  // ===========================================================================
  // Step 5 — credentials (C1–C4)
  // ===========================================================================

  group('step 5 — credentials', () {
    const pin = 'PIN-LEA';

    Future<LoginOutcome> signIn(AppDatabase db, String password) async =>
        (await CredentialRepository(db).authenticate(pin, password)).outcome;

    Future<void> withPassword(AppDatabase a, AppDatabase b, Shop shop) async {
      await CredentialRepository(a).setPassword(shop.owner.id, '1111');
      await settle(a, b);
    }

    test('C1 — a sign-in sends nothing and never puts back an old password',
        () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);
      await withPassword(a, b, shop);

      await CredentialRepository(a).setPassword(shop.owner.id, '2222');
      expect(await signIn(b, '1111'), LoginOutcome.success);
      expect(
        await OutboxRepository(b).pendingCount(),
        0,
        reason: 'a sign-in is this tablet\'s own business',
      );
      await settle(a, b);

      for (final db in [a, b]) {
        expect(await signIn(db, '2222'), LoginOutcome.success);
      }
    });

    test('C2 — changed on both: the last wins, signalled', () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);
      await withPassword(a, b, shop);

      await CredentialRepository(a).setPassword(shop.owner.id, '2222');
      await CredentialRepository(b).setPassword(shop.owner.id, '3333');
      await settle(a, b);

      for (final db in [a, b]) {
        expect(await signIn(db, '3333'), LoginOutcome.success);
        final signalled = await flags(db, shop.store.id);
        expect(signalled, hasLength(1));
        expect(signalled.single.title, contains('Mot de passe'));
      }
    });

    test('C2 — changed on A, synced, then on B: not signalled', () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);
      await withPassword(a, b, shop);

      await CredentialRepository(a).setPassword(shop.owner.id, '2222');
      await settle(a, b);
      await CredentialRepository(b).setPassword(shop.owner.id, '3333');
      await settle(a, b);

      expect(await flags(a, shop.store.id), isEmpty);
    });

    test('C3 — a lockout stays on its tablet; a new password lifts it',
        () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);
      await withPassword(a, b, shop);

      for (var i = 0; i < AuthRules.maxFailedAttempts; i++) {
        await signIn(a, '9999');
      }
      await settle(a, b);
      expect(await signIn(a, '1111'), LoginOutcome.locked);
      expect(await signIn(b, '1111'), LoginOutcome.success);

      await CredentialRepository(b).setPassword(shop.owner.id, '3333');
      await settle(a, b);
      expect(await signIn(a, '3333'), LoginOutcome.success);
    });

    test('C4 — the old password works offline until the sync', () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);
      await withPassword(a, b, shop);

      await CredentialRepository(a).setPassword(shop.owner.id, '2222');
      expect(await signIn(b, '1111'), LoginOutcome.success);

      await settle(a, b);
      expect(await signIn(b, '1111'), LoginOutcome.wrongPassword);
      expect(await signIn(b, '2222'), LoginOutcome.success);
    });
  });

  // ===========================================================================
  // Step 6 — the pointage board and history (P1, P3, P4, P6, H1, H2)
  // ===========================================================================

  group('step 6 — pointage and history', () {
    test('P1 — two arrivals: one day; one exit ends both; the duplicate '
        'can be removed', () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);
      await AttendanceRepository(a).clockIn(shop.cook.id, shop.store.id, now: at(8));
      await AttendanceRepository(b).clockIn(shop.cook.id, shop.store.id, now: at(8, 2));
      await settle(a, b);

      final merged = await dayOf(a, shop.cook.id);
      expect(merged.sessions, hasLength(2));
      await AttendanceRepository(a).clockOut(merged.id, now: at(17));
      await settle(a, b);
      for (final db in [a, b]) {
        final day = await dayOf(db, shop.cook.id);
        expect(day.status, AttendanceStatus.done);
        expect(day.sessions.every((s) => s.clockOutAt == at(17)), isTrue);
      }

      await AttendanceRepository(
        b,
      ).deleteDuplicateSession(merged.id, merged.sessions.last.id!);
      await settle(a, b);
      for (final db in [a, b]) {
        expect((await dayOf(db, shop.cook.id)).sessions, hasLength(1));
      }
    });

    test('P3 — a pause on A, the exit on B: the status is recomputed, the '
        'pause ends at the exit', () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);
      final id = await karimIn(a, b, shop);

      await AttendanceRepository(a).startPause(id, now: at(12));
      await AttendanceRepository(b).clockOut(id, now: at(14));
      await settle(a, b);

      for (final db in [a, b]) {
        final day = await dayOf(db, shop.cook.id);
        expect(day.status, AttendanceStatus.done);
        expect(workedDuration(day), const Duration(hours: 4));
      }
    });

    test('P4 — two exits 30 min apart: the earliest, signalled', () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);
      final id = await karimIn(a, b, shop);

      await AttendanceRepository(a).clockOut(id, now: at(17));
      await AttendanceRepository(b).clockOut(id, now: at(17, 30));
      await settle(a, b);

      for (final db in [a, b]) {
        expect((await dayOf(db, shop.cook.id)).sessions.single.clockOutAt, at(17));
        expect((await flags(db, shop.store.id)).single.title, contains('Deux départs'));
      }
    });

    test('P4 — two exits 5 min apart: the earliest, quietly', () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);
      final id = await karimIn(a, b, shop);

      await AttendanceRepository(a).clockOut(id, now: at(17));
      await AttendanceRepository(b).clockOut(id, now: at(17, 5));
      await settle(b, a);

      for (final db in [a, b]) {
        expect((await dayOf(db, shop.cook.id)).sessions.single.clockOutAt, at(17));
        expect(await flags(db, shop.store.id), isEmpty);
      }
    });

    test('H1 — two managers set the forgotten exit: the earliest, signalled',
        () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);
      final id = await karimIn(a, b, shop);
      final journee = (await BusinessDayRepository(a).current(shop.store.id))!;

      await BusinessDayRepository(a, clock: () => at(23)).close(
        journee.id,
        closedByEmployeeId: shop.owner.id,
        exits: {id: at(17)},
      );
      await BusinessDayRepository(b, clock: () => at(23)).close(
        journee.id,
        closedByEmployeeId: shop.owner.id,
        exits: {id: at(17, 5)},
      );
      await settle(a, b);

      for (final db in [a, b]) {
        expect((await dayOf(db, shop.cook.id)).sessions.single.clockOutAt, at(17));
        expect(await flags(db, shop.store.id), hasLength(1));
      }
    });

    test('H2 — a manager\'s correction against Karim\'s own late exit: the '
        'earliest, signalled', () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);
      final id = await karimIn(a, b, shop);
      final journee = (await BusinessDayRepository(a).current(shop.store.id))!;

      // Karim clocks out himself on A at 17:30; on B, the manager closes the
      // journée with his exit at 17:00.
      await AttendanceRepository(a).clockOut(id, now: at(17, 30));
      await BusinessDayRepository(b, clock: () => at(23)).close(
        journee.id,
        closedByEmployeeId: shop.owner.id,
        exits: {id: at(17)},
      );
      await settle(a, b);

      for (final db in [a, b]) {
        final session = (await dayOf(db, shop.cook.id)).sessions.single;
        expect(session.clockOutAt, at(17));
        expect(session.exitSetByEmployeeId, shop.owner.id);
        expect(await flags(db, shop.store.id), hasLength(1));
      }
    });

    test('P6 — the journée closed on A, then Léa pointed on B: the close '
        'wins, her arrival is removed, signalled', () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);
      final id = await karimIn(a, b, shop);
      final journee = (await BusinessDayRepository(a).current(shop.store.id))!;

      await AttendanceRepository(a).clockOut(id, now: at(17));
      await BusinessDayRepository(a, clock: () => at(17, 30)).close(
        journee.id,
        closedByEmployeeId: shop.owner.id,
      );
      await AttendanceRepository(b).clockIn(shop.owner.id, shop.store.id, now: at(17, 45));
      await settle(a, b);

      for (final db in [a, b]) {
        expect(
          (await BusinessDayRepository(db).businessDay(journee.id))!.closedAt,
          isNotNull,
        );
        expect(await AttendanceRepository(db).forEmployee(shop.owner.id), isEmpty);
        final signalled = (await flags(db, shop.store.id)).single;
        expect(signalled.title, contains('après la fermeture'));
        expect(signalled.body, contains('17:45 n\'est pas comptée'));
      }
    });

    test('P6 — Karim still in on B when A closed: his exit is the close, '
        'signalled', () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);
      final lea = (await AttendanceRepository(
        a,
      ).clockIn(shop.owner.id, shop.store.id, now: at(8)))!;
      await settle(a, b);
      final journee = (await BusinessDayRepository(a).current(shop.store.id))!;

      await AttendanceRepository(b).clockIn(shop.cook.id, shop.store.id, now: at(16));
      await AttendanceRepository(a).clockOut(lea.id, now: at(17));
      await BusinessDayRepository(a, clock: () => at(17, 30)).close(
        journee.id,
        closedByEmployeeId: shop.owner.id,
      );
      await settle(a, b);

      for (final db in [a, b]) {
        final session = (await dayOf(db, shop.cook.id)).sessions.single;
        expect(session.clockOutAt, at(17, 30));
        expect(session.exitSetByEmployeeId, shop.owner.id);
        expect(
          (await flags(db, shop.store.id)).single.body,
          contains('départ est mis à 17:30'),
        );
      }
    });
  });

  // ===========================================================================
  // Step 7 — payments (PA1, PA2)
  // ===========================================================================

  group('step 7 — payments', () {
    test('PA1 — the same day paid on both: the first keeps it, the second is '
        'a « paiement en double » with its trop-versé', () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);
      await workDay(a, shop, 12);
      await workDay(a, shop, 13);
      await settle(a, b);

      final first = (await PayrollRepository(a).pay(
        shop.cook.id,
        shop.store.id,
        from: DateTime(2026, 10, 12),
        to: DateTime(2026, 10, 12),
        paidByEmployeeId: shop.owner.id,
      ))!;
      final second = (await PayrollRepository(b).pay(
        shop.cook.id,
        shop.store.id,
        from: DateTime(2026, 10, 12),
        to: DateTime(2026, 10, 13),
        paidByEmployeeId: shop.owner.id,
      ))!;
      await settle(a, b);

      for (final db in [a, b]) {
        expect((await dayOf(db, shop.cook.id, 12)).payrollPeriodId, first.id);
        expect((await dayOf(db, shop.cook.id, 13)).payrollPeriodId, second.id);
        expect(
          (await PayrollRepository(db).period(second.id))!.doublePaymentAmount,
          120,
        );
        final signalled = (await flags(db, shop.store.id)).single;
        expect(signalled.title, contains('Paiement en double'));
        expect(signalled.body, contains('120,00 €'));
      }
    });

    test('PA2 — a later exit reaching a paid day: not applied, signalled '
        'with the difference', () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);
      final id = await karimIn(a, b, shop);
      final journee = (await BusinessDayRepository(a).current(shop.store.id))!;

      await BusinessDayRepository(a, clock: () => at(23)).close(
        journee.id,
        closedByEmployeeId: shop.owner.id,
        exits: {id: at(16)},
      );
      await PayrollRepository(a).pay(
        shop.cook.id,
        shop.store.id,
        paidByEmployeeId: shop.owner.id,
      );
      await BusinessDayRepository(b, clock: () => at(23)).close(
        journee.id,
        closedByEmployeeId: shop.owner.id,
        exits: {id: at(17)},
      );
      await settle(a, b);

      for (final db in [a, b]) {
        final day = await dayOf(db, shop.cook.id);
        expect(day.payrollPeriodId, isNotNull);
        expect(day.sessions.single.clockOutAt, at(16));
        expect(
          (await flags(db, shop.store.id)).single.body,
          contains('1h00 non payée'),
        );
      }
    });
  });

  // ===========================================================================
  // Step 8 — employees (E1, E2, E4, E5, E6)
  // ===========================================================================

  group('step 8 — employees', () {
    Future<Employee> addSami(
      AppDatabase db,
      String storeId, {
      required String phone,
      double pay = 15,
    }) async => (await EmployeeRepository(db).create(
      storeId: storeId,
      firstName: 'Sami',
      lastName: 'Test',
      pin: 'CIN-SAMI',
      phone: phone,
      email: 'sami@resto.be',
      role: EmployeeRole.staff,
      pay: pay,
    ))!;

    Future<List<EmployeeRow>> samis(AppDatabase db) async => [
      for (final e in await db.select(db.employees).get())
        if (e.pin == 'CIN-SAMI' && e.deletedAt == null) e,
    ];

    test('E1 — the same CIN on both, same store: merged, days together, '
        'signalled with the rate difference', () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);
      final onA = await addSami(a, shop.store.id, phone: '0471', pay: 15);
      final onB = await addSami(b, shop.store.id, phone: '0472', pay: 16);
      await AttendanceRepository(a).clockIn(onA.id, shop.store.id, now: at(8));
      await AttendanceRepository(b).clockIn(onB.id, shop.store.id, now: at(9));
      await settle(a, b);

      final kept = onA.id.compareTo(onB.id) < 0 ? onA : onB;
      for (final db in [a, b]) {
        final live = (await samis(db)).single;
        expect(live.id, kept.id);
        expect(live.pay, kept.pay);
        expect((await dayOf(db, kept.id)).sessions, hasLength(2));
        final merged = (await flags(
          db,
          shop.store.id,
        )).where((n) => n.title.contains('ajouté deux fois'));
        expect(merged.single.body, contains('Taux horaire différent'));
      }
    });

    test('E1 — the same CIN in two stores: two people, signalled', () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);
      final annexe = await StoreRepository(b).createStore(
        name: 'Annexe',
        addressLine: '',
        postalCode: '',
        city: 'Namur',
        phone: '081',
      );
      await settle(a, b);

      await addSami(a, shop.store.id, phone: '0471');
      await addSami(b, annexe.id, phone: '0472');
      await settle(a, b);

      for (final db in [a, b]) {
        expect(await samis(db), hasLength(2));
        final signalled = [
          ...await flags(db, shop.store.id),
          ...await flags(db, annexe.id),
        ];
        expect(signalled.single.title, contains('Même CIN'));
      }
    });

    test('E2 — the rate changed on both: the last wins, signalled', () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);

      await EmployeeRepository(a).update(shop.cook.id, pay: 16);
      await EmployeeRepository(b).update(shop.cook.id, pay: 17);
      await settle(a, b);

      for (final db in [a, b]) {
        expect((await EmployeeRepository(db).employee(shop.cook.id))!.pay, 17);
        expect((await flags(db, shop.store.id)).single.body, contains('taux horaire'));
      }
    });

    test('E2 — the role changed on both: the last wins, signalled', () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);

      await EmployeeRepository(a).update(
        shop.cook.id,
        role: EmployeeRole.manager,
        password: '1234',
      );
      await EmployeeRepository(b).update(
        shop.cook.id,
        role: EmployeeRole.owner,
        password: '5678',
      );
      await settle(a, b);

      for (final db in [a, b]) {
        expect(
          (await EmployeeRepository(db).employee(shop.cook.id))!.role,
          EmployeeRole.owner,
        );
        expect(
          (await flags(db, shop.store.id)).map((n) => n.body).join(' '),
          contains('le rôle'),
        );
      }
    });

    test('E4 — retired on A, pointed on B: hours kept, signalled', () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);

      await EmployeeRepository(a).archive(shop.cook.id, at: at(7));
      await AttendanceRepository(b).clockIn(shop.cook.id, shop.store.id, now: at(8));
      await settle(a, b);

      for (final db in [a, b]) {
        expect(
          (await EmployeeRepository(db).employee(shop.cook.id))!.archivedAt,
          isNotNull,
        );
        expect(await AttendanceRepository(db).forEmployee(shop.cook.id), hasLength(1));
        expect(
          (await flags(db, shop.store.id)).single.title,
          contains('après le retrait'),
        );
      }
    });

    test('E5 — retired on A, retired and brought back on B: the last '
        'decision wins, signalled', () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);

      await EmployeeRepository(a).archive(shop.cook.id, at: at(7));
      await EmployeeRepository(b).archive(shop.cook.id, at: at(9));
      await EmployeeRepository(b).restore(shop.cook.id);
      await settle(a, b);

      for (final db in [a, b]) {
        expect(
          (await EmployeeRepository(db).employee(shop.cook.id))!.archivedAt,
          isNull,
        );
        expect(
          (await flags(db, shop.store.id)).single.body,
          contains('réactivation est gardée'),
        );
      }
    });

    test('E6 — the rate changed while a payment runs: the payment keeps the '
        'rate of its moment, no conflict', () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);
      await workDay(a, shop, 12);
      await settle(a, b);

      final paid = (await PayrollRepository(a).pay(
        shop.cook.id,
        shop.store.id,
        paidByEmployeeId: shop.owner.id,
      ))!;
      await EmployeeRepository(b).update(shop.cook.id, pay: 20);
      await settle(a, b);

      for (final db in [a, b]) {
        final period = (await PayrollRepository(db).period(paid.id))!;
        expect(period.appliedRate, 15);
        expect(period.computedAmount, 120);
        expect((await EmployeeRepository(db).employee(shop.cook.id))!.pay, 20);
        expect(await flags(db, shop.store.id), isEmpty);
      }
    });
  });

  // ===========================================================================
  // Every synced table is accounted for
  // ===========================================================================

  test('the personnel tables are synced, the sign-in state is not', () {
    for (final table in [
      'employees',
      'employee_credentials',
      'payroll_periods',
      'attendances',
      'attendance_sessions',
      'attendance_pauses',
      'business_days',
      'notifications',
    ]) {
      expect(SyncTables.synced, contains(table));
    }
    expect(SyncTables.local, contains('login_states'));
  });
}
