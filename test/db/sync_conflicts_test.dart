// Conflicts settled on receipt (SYNC_PLAN.md, Phase 7).
//
// Two tablets of one restaurant, offline, both create "the" row for one key.
// The server keeps both; each device, on receiving the other's row, runs the
// same rule, and after a round of syncs both devices hold the same result.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/core/utils/attendance_status.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/models/models.dart';
import 'package:stock_inventory/services/auth_service.dart';
import 'package:stock_inventory/services/sync_service.dart';

import '../support/db_fixture.dart';
import '../support/fake_account_backend.dart';

void main() {
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
    expect(result.outcome, SyncOutcome.done, reason: result.detail);
  }

  /// Syncs both devices until neither has anything left to send.
  Future<void> settle(AppDatabase a, AppDatabase b) async {
    for (var round = 0; round < 4; round++) {
      await sync(a);
      await sync(b);
    }
    expect(await OutboxRepository(a).pendingCount(), 0);
    expect(await OutboxRepository(b).pendingCount(), 0);
  }

  /// A's first day, synced to B: an establishment and two employees.
  Future<({Store store, Employee owner, Employee cook})> shared(
    AppDatabase a,
    AppDatabase b,
  ) async {
    final store = await StoreRepository(a).createStore(
      name: 'Brasserie',
      addressLine: '',
      postalCode: '',
      city: 'Namur',
      phone: '081',
    );
    Future<Employee> employee(
      String first,
      String pin,
      EmployeeRole role,
    ) async => (await EmployeeRepository(a).create(
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

  group('two clock-ins for one employee on one day', () {
    test('become one day holding both sessions, on both tablets', () async {
      final a = await newDevice();
      final b = await newDevice();
      final day = await shared(a, b);
      final morning = DateTime(2026, 10, 12, 8);

      // Both tablets clock Karim in, offline.
      await AttendanceRepository(
        a,
      ).clockIn(day.cook.id, day.store.id, now: morning);
      await AttendanceRepository(b).clockIn(
        day.cook.id,
        day.store.id,
        now: morning.add(const Duration(minutes: 3)),
      );

      await settle(a, b);

      for (final (name, db) in [('A', a), ('B', b)]) {
        final days = await AttendanceRepository(db).forEmployee(day.cook.id);
        expect(days, hasLength(1), reason: 'one live day on $name');
        expect(
          days.single.sessions,
          hasLength(2),
          reason: 'no time lost on $name',
        );
        expect(
          attendanceAnomalies(days.single, maxBreakMinutes: 30, now: morning),
          contains(AttendanceAnomaly.doublePointage),
          reason: 'flagged for the manager on $name',
        );
      }
      final keptOnA = (await AttendanceRepository(
        a,
      ).forEmployee(day.cook.id)).single;
      final keptOnB = (await AttendanceRepository(
        b,
      ).forEmployee(day.cook.id)).single;
      expect(keptOnA.id, keptOnB.id, reason: 'the same day kept everywhere');
      expect(keptOnA.status, AttendanceStatus.working);
    });

    test('are explained on the sync page', () async {
      final a = await newDevice();
      final b = await newDevice();
      final day = await shared(a, b);
      final morning = DateTime(2026, 10, 12, 8);
      await AttendanceRepository(
        a,
      ).clockIn(day.cook.id, day.store.id, now: morning);
      await AttendanceRepository(
        b,
      ).clockIn(day.cook.id, day.store.id, now: morning);

      await settle(a, b);

      final notes = [
        ...await SyncErrorRepository(a).all(),
        ...await SyncErrorRepository(b).all(),
      ];
      expect(notes.map((n) => n.reason), contains('resolved_double_clock_in'));
      expect(notes.map((n) => n.reason), isNot(contains('receive_conflict')));
    });

    // Rule P1 « signalé double pointage », and step 3: one signalement on
    // every tablet, read separately by a manager and by the owner.
    test('are signalled once, and read separately on every tablet', () async {
      final a = await newDevice();
      final b = await newDevice();
      final day = await shared(a, b);
      final morning = DateTime(2026, 10, 12, 8);
      await AttendanceRepository(
        a,
      ).clockIn(day.cook.id, day.store.id, now: morning);
      await AttendanceRepository(
        b,
      ).clockIn(day.cook.id, day.store.id, now: morning);

      await settle(a, b);

      Future<List<NotificationItem>> flags(
        AppDatabase db,
        EmployeeRole viewer,
      ) async => [
        for (final n in await AccountRepository(
          db,
        ).notifications(day.store.id, viewer: viewer))
          if (n.kind == NotificationKind.personnel) n,
      ];

      final onA = (await flags(a, EmployeeRole.owner)).single;
      final onB = (await flags(b, EmployeeRole.owner)).single;
      expect(onB.id, onA.id);
      expect(onA.relatedEmployeeId, day.cook.id);
      expect(onA.title, contains('Karim'));

      // The manager reads it on A, the owner on B.
      await AccountRepository(
        a,
      ).markRead(onA.id, viewer: EmployeeRole.manager);
      await AccountRepository(b).markRead(onB.id, viewer: EmployeeRole.owner);
      await settle(a, b);

      // Each read travels as its own column (step 4), so both tablets end
      // with both reads.
      for (final db in [a, b]) {
        expect((await flags(db, EmployeeRole.manager)).single.isRead, isTrue);
        expect((await flags(db, EmployeeRole.owner)).single.isRead, isTrue);
      }
      for (final db in [a, b]) {
        expect(await flags(db, EmployeeRole.manager), hasLength(1));
      }
    });
  });

  // Rules E2 and E3 (SYNC_PERSONNEL_PLAN.md, step 4): an edit sends only the
  // fields it changed.
  group('two tablets editing one employee', () {
    Future<Employee> cookOn(AppDatabase db, String id) async =>
        (await EmployeeRepository(db).employee(id))!;

    test('different fields: both edits are kept everywhere', () async {
      final a = await newDevice();
      final b = await newDevice();
      final day = await shared(a, b);

      await EmployeeRepository(a).update(day.cook.id, phone: '0499 11 22 33');
      await EmployeeRepository(b).update(day.cook.id, lastName: 'Benali');

      await settle(a, b);

      for (final db in [a, b]) {
        final cook = await cookOn(db, day.cook.id);
        expect(cook.phone, '0499 11 22 33');
        expect(cook.lastName, 'Benali');
      }
    });

    test('the same field: the last one sent wins, the same everywhere',
        () async {
      final a = await newDevice();
      final b = await newDevice();
      final day = await shared(a, b);

      await EmployeeRepository(a).update(day.cook.id, phone: '0499 00 00 0A');
      await EmployeeRepository(b).update(day.cook.id, phone: '0499 00 00 0B');

      // A sends first, B last.
      await settle(a, b);

      expect((await cookOn(a, day.cook.id)).phone, '0499 00 00 0B');
      expect((await cookOn(b, day.cook.id)).phone, '0499 00 00 0B');
    });

    test('archived on one, edited on the other: stays archived', () async {
      final a = await newDevice();
      final b = await newDevice();
      final day = await shared(a, b);

      expect(await EmployeeRepository(a).archive(day.cook.id), isTrue);
      await EmployeeRepository(b).update(day.cook.id, phone: '0499 44 55 66');

      await settle(a, b);

      for (final db in [a, b]) {
        final cook = await cookOn(db, day.cook.id);
        expect(cook.archivedAt, isNotNull);
        expect(cook.phone, '0499 44 55 66');
      }
    });
  });

  // Signing in reads the employees and writes nothing: nothing to send.
  test('signing in sends nothing', () async {
    final a = await newDevice();
    final b = await newDevice();
    await shared(a, b);

    await CredentialRepository(a).authenticate('Léa@resto.be', 'PIN-LEA');
    await CredentialRepository(a).authenticate('Léa@resto.be', 'PIN-X');

    expect(await OutboxRepository(a).pendingCount(), 0);
  });

  // SYNC_PERSONNEL_PLAN.md, step 6: the pointage board and the history on
  // two tablets.
  group('the pointage on two tablets', () {
    final morning = DateTime(2026, 10, 12, 8);
    DateTime at(int hour, [int minute = 0]) =>
        DateTime(2026, 10, 12, hour, minute);

    Future<Attendance> dayOf(AppDatabase db, String employeeId) async =>
        (await AttendanceRepository(db).forEmployee(employeeId)).single;

    Future<List<NotificationItem>> flags(AppDatabase db, String storeId) async =>
        [
          for (final n in await AccountRepository(db).notifications(storeId))
            if (n.kind == NotificationKind.personnel) n,
        ];

    test('after a double arrival, one exit ends both arrivals (P1, P3)',
        () async {
      final a = await newDevice();
      final b = await newDevice();
      final day = await shared(a, b);
      await AttendanceRepository(a).clockIn(day.cook.id, day.store.id, now: morning);
      await AttendanceRepository(b).clockIn(day.cook.id, day.store.id, now: morning);
      await settle(a, b);

      final merged = await dayOf(a, day.cook.id);
      expect(merged.sessions, hasLength(2));
      expect(merged.status, AttendanceStatus.working);
      await AttendanceRepository(a).clockOut(merged.id, now: at(17));
      await settle(a, b);

      for (final db in [a, b]) {
        final entry = await dayOf(db, day.cook.id);
        expect(entry.status, AttendanceStatus.done);
        expect(entry.sessions.every((s) => s.clockOutAt == at(17)), isTrue);
      }
    });

    test('a pause on one tablet, the exit on the other (P3)', () async {
      final a = await newDevice();
      final b = await newDevice();
      final day = await shared(a, b);
      final id = (await AttendanceRepository(
        a,
      ).clockIn(day.cook.id, day.store.id, now: morning))!.id;
      await settle(a, b);

      await AttendanceRepository(a).startPause(id, now: at(12));
      await AttendanceRepository(b).clockOut(id, now: at(14));
      await settle(a, b);

      for (final db in [a, b]) {
        final entry = await dayOf(db, day.cook.id);
        expect(entry.status, AttendanceStatus.done);
        // 8:00–14:00, the break from 12:00 runs to the exit.
        expect(workedDuration(entry), const Duration(hours: 4));
      }
    });

    test('two exits for one arrival: the earliest, signalled (P4)', () async {
      final a = await newDevice();
      final b = await newDevice();
      final day = await shared(a, b);
      final id = (await AttendanceRepository(
        a,
      ).clockIn(day.cook.id, day.store.id, now: morning))!.id;
      await settle(a, b);

      await AttendanceRepository(a).clockOut(id, now: at(17));
      await AttendanceRepository(b).clockOut(id, now: at(17, 30));
      await settle(a, b);

      for (final db in [a, b]) {
        expect((await dayOf(db, day.cook.id)).sessions.single.clockOutAt, at(17));
        final signalled = await flags(db, day.store.id);
        expect(signalled, hasLength(1));
        expect(signalled.single.title, contains('Deux départs'));
      }
    });

    test('two exits a few minutes apart: the earliest, quietly', () async {
      final a = await newDevice();
      final b = await newDevice();
      final day = await shared(a, b);
      final id = (await AttendanceRepository(
        a,
      ).clockIn(day.cook.id, day.store.id, now: morning))!.id;
      await settle(a, b);

      await AttendanceRepository(b).clockOut(id, now: at(17, 5));
      await AttendanceRepository(a).clockOut(id, now: at(17));
      // B sends first this time: the earlier exit arrives last and still wins.
      await settle(b, a);

      for (final db in [a, b]) {
        expect((await dayOf(db, day.cook.id)).sessions.single.clockOutAt, at(17));
        expect(await flags(db, day.store.id), isEmpty);
      }
    });

    test('two managers set the exit: the earliest, always signalled (H1)',
        () async {
      final a = await newDevice();
      final b = await newDevice();
      final day = await shared(a, b);
      await AttendanceRepository(a).clockIn(day.cook.id, day.store.id, now: morning);
      await settle(a, b);
      final journee = (await BusinessDayRepository(a).current(day.store.id))!;
      final id = (await dayOf(a, day.cook.id)).id;

      // Both close the journée, each entering a forgotten exit for Karim.
      await BusinessDayRepository(a, clock: () => at(23)).close(
        journee.id,
        closedByEmployeeId: day.owner.id,
        exits: {id: at(17)},
      );
      await BusinessDayRepository(b, clock: () => at(23)).close(
        journee.id,
        closedByEmployeeId: day.owner.id,
        exits: {id: at(17, 10)},
      );
      await settle(a, b);

      for (final db in [a, b]) {
        final session = (await dayOf(db, day.cook.id)).sessions.single;
        expect(session.clockOutAt, at(17));
        expect(session.exitSetByEmployeeId, day.owner.id);
        expect(await flags(db, day.store.id), hasLength(1));
      }
    });

    test('an arrival after the close on the other tablet is removed (P6)',
        () async {
      final a = await newDevice();
      final b = await newDevice();
      final day = await shared(a, b);
      final id = (await AttendanceRepository(
        a,
      ).clockIn(day.cook.id, day.store.id, now: morning))!.id;
      await settle(a, b);
      final journee = (await BusinessDayRepository(a).current(day.store.id))!;

      // A ends the day and closes the journée; B, offline, still sees it
      // open and Léa clocks in there.
      await AttendanceRepository(a).clockOut(id, now: at(17));
      await BusinessDayRepository(a, clock: () => at(17, 30)).close(
        journee.id,
        closedByEmployeeId: day.owner.id,
      );
      expect(
        await AttendanceRepository(
          b,
        ).clockIn(day.owner.id, day.store.id, now: at(17, 45)),
        isNotNull,
      );
      await settle(a, b);

      for (final db in [a, b]) {
        final kept = await BusinessDayRepository(db).businessDay(journee.id);
        expect(kept!.closedAt, isNotNull);
        // The close wins: Léa's arrival at 17:45 is removed, with her day.
        expect(await AttendanceRepository(db).forEmployee(day.owner.id), isEmpty);
        final signalled = await flags(db, day.store.id);
        expect(signalled, hasLength(1));
        expect(signalled.single.title, contains('après la fermeture'));
        expect(signalled.single.body, contains('supprimé'));
        expect(signalled.single.relatedEmployeeId, day.owner.id);
      }
    });

    test('a shift still open at the close on the other tablet ends at the '
        'close (P6)', () async {
      final a = await newDevice();
      final b = await newDevice();
      final day = await shared(a, b);
      await AttendanceRepository(a).clockIn(day.owner.id, day.store.id, now: morning);
      await settle(a, b);
      final journee = (await BusinessDayRepository(a).current(day.store.id))!;

      // B, offline, clocks Karim in and starts his break; A, not knowing,
      // ends Léa's day and closes the journée at 17:30.
      final karim = (await AttendanceRepository(
        b,
      ).clockIn(day.cook.id, day.store.id, now: at(16)))!;
      await AttendanceRepository(b).startPause(karim.id, now: at(17));
      await AttendanceRepository(a).clockOut(
        (await dayOf(a, day.owner.id)).id,
        now: at(17),
      );
      await BusinessDayRepository(a, clock: () => at(17, 30)).close(
        journee.id,
        closedByEmployeeId: day.owner.id,
      );
      await settle(a, b);

      for (final db in [a, b]) {
        final shift = await dayOf(db, day.cook.id);
        expect(shift.status, AttendanceStatus.done);
        expect(shift.sessions.single.clockOutAt, at(17, 30));
        expect(shift.sessions.single.exitSetByEmployeeId, day.owner.id);
        expect(shift.sessions.single.pauses.single.endAt, at(17, 30));
        final signalled = await flags(db, day.store.id);
        expect(signalled, hasLength(1));
        expect(signalled.single.body, contains('départ est mis à 17:30'));
        expect(signalled.single.relatedEmployeeId, day.cook.id);
      }
    });

    test('a removed duplicate is removed on every tablet (P1)', () async {
      final a = await newDevice();
      final b = await newDevice();
      final day = await shared(a, b);
      await AttendanceRepository(a).clockIn(day.cook.id, day.store.id, now: morning);
      await AttendanceRepository(b).clockIn(day.cook.id, day.store.id, now: morning);
      await settle(a, b);

      final merged = await dayOf(a, day.cook.id);
      await AttendanceRepository(
        a,
      ).deleteDuplicateSession(merged.id, merged.sessions.last.id!);
      await settle(a, b);

      for (final db in [a, b]) {
        final entry = await dayOf(db, day.cook.id);
        expect(entry.sessions, hasLength(1));
        expect(entry.status, AttendanceStatus.working);
      }
    });
  });

  // SYNC_PERSONNEL_PLAN.md, step 7: paying on two tablets.
  group('payments on two tablets', () {
    DateTime on(int day, int hour) => DateTime(2026, 10, day, hour);

    /// Karim works [day] from 8:00 to 16:00 on [db], and the journée is
    /// closed — 8 hours at 15 €.
    Future<void> workDay(
      AppDatabase db,
      ({Store store, Employee owner, Employee cook}) shop,
      int day,
    ) async {
      final entry = (await AttendanceRepository(
        db,
      ).clockIn(shop.cook.id, shop.store.id, now: on(day, 8)))!;
      await AttendanceRepository(db).clockOut(entry.id, now: on(day, 16));
      final journee = (await BusinessDayRepository(db).current(shop.store.id))!;
      await BusinessDayRepository(db, clock: () => on(day, 23)).close(
        journee.id,
        closedByEmployeeId: shop.owner.id,
      );
    }

    Future<Attendance> dayOn(AppDatabase db, String cookId, int day) async =>
        (await AttendanceRepository(
          db,
        ).forEmployee(cookId)).singleWhere((a) => a.date == DateTime(2026, 10, day));

    Future<List<NotificationItem>> flags(AppDatabase db, String storeId) async =>
        [
          for (final n in await AccountRepository(db).notifications(storeId))
            if (n.kind == NotificationKind.personnel) n,
        ];

    test('the same day paid twice: the first keeps it, the second is a '
        '« paiement en double » (PA1)', () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);
      await workDay(a, shop, 12);
      await workDay(a, shop, 13);
      await settle(a, b);

      // A pays the 12th; B, offline, pays the 12th and the 13th.
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
        expect(
          (await dayOn(db, shop.cook.id, 12)).payrollPeriodId,
          first.id,
          reason: 'the 12th stays with the payment that arrived first',
        );
        expect((await dayOn(db, shop.cook.id, 13)).payrollPeriodId, second.id);
        final marked = (await PayrollRepository(db).period(second.id))!;
        expect(marked.doublePaymentAmount, 120);
        expect((await PayrollRepository(db).period(first.id))!
            .doublePaymentAmount, isNull);
        final signalled = await flags(db, shop.store.id);
        expect(signalled, hasLength(1));
        expect(signalled.single.title, contains('Paiement en double'));
        expect(signalled.single.body, contains('120,00 €'));
        expect(signalled.single.relatedTarget, 'payroll');
      }
    });

    test('a change reaching a paid day is not applied, and signalled (PA2)',
        () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);
      // Karim forgot to clock out; both tablets hold his open day.
      await AttendanceRepository(
        a,
      ).clockIn(shop.cook.id, shop.store.id, now: on(12, 8));
      await settle(a, b);
      final journee = (await BusinessDayRepository(a).current(shop.store.id))!;
      final id = (await dayOn(a, shop.cook.id, 12)).id;

      // A closes at 16:00 and pays; B, offline, closes at 17:00.
      await BusinessDayRepository(a, clock: () => on(12, 23)).close(
        journee.id,
        closedByEmployeeId: shop.owner.id,
        exits: {id: on(12, 16)},
      );
      await PayrollRepository(a).pay(
        shop.cook.id,
        shop.store.id,
        paidByEmployeeId: shop.owner.id,
      );
      await BusinessDayRepository(b, clock: () => on(12, 23)).close(
        journee.id,
        closedByEmployeeId: shop.owner.id,
        exits: {id: on(12, 17)},
      );
      await settle(a, b);

      for (final db in [a, b]) {
        final day = await dayOn(db, shop.cook.id, 12);
        expect(day.payrollPeriodId, isNotNull);
        expect(day.sessions.single.clockOutAt, on(12, 16));
        final signalled = await flags(db, shop.store.id);
        expect(signalled, hasLength(1));
        expect(signalled.single.title, contains('Jour déjà payé'));
        expect(signalled.single.body, contains('1h00 non payée'));
      }
    });
  });

  // SYNC_PERSONNEL_PLAN.md, step 8: employees on two tablets.
  group('employees on two tablets', () {
    DateTime on(int day, int hour) => DateTime(2026, 10, day, hour);

    Future<Employee> addSami(
      AppDatabase db,
      String storeId, {
      required String phone,
      double pay = 15,
      String email = 'sami@resto.be',
    }) async => (await EmployeeRepository(db).create(
      storeId: storeId,
      firstName: 'Sami',
      lastName: 'Test',
      pin: 'CIN-SAMI',
      phone: phone,
      email: email,
      role: EmployeeRole.staff,
      pay: pay,
    ))!;

    Future<List<EmployeeRow>> samis(AppDatabase db) async => [
      for (final e in await db.select(db.employees).get())
        if (e.pin == 'CIN-SAMI' && e.deletedAt == null) e,
    ];

    Future<List<NotificationItem>> flags(AppDatabase db, String storeId) async =>
        [
          for (final n in await AccountRepository(db).notifications(storeId))
            if (n.kind == NotificationKind.personnel) n,
        ];

    test('the same CIN added on both: one record, days together (E1)',
        () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);
      final onA = await addSami(a, shop.store.id, phone: '0471', pay: 15);
      final onB = await addSami(b, shop.store.id, phone: '0472', pay: 16);
      await AttendanceRepository(a).clockIn(onA.id, shop.store.id, now: on(12, 8));
      await AttendanceRepository(b).clockIn(onB.id, shop.store.id, now: on(12, 9));

      await settle(a, b);

      final kept = onA.id.compareTo(onB.id) < 0 ? onA : onB;
      for (final db in [a, b]) {
        final live = await samis(db);
        expect(live, hasLength(1));
        expect(live.single.id, kept.id);
        expect(live.single.phone, kept.phone);
        expect(live.single.pay, kept.pay);
        // Both arrivals of the 12th, on one day of the kept record.
        final days = await AttendanceRepository(db).forEmployee(kept.id);
        expect(days, hasLength(1));
        expect(days.single.sessions, hasLength(2));
        final signalled = await flags(db, shop.store.id);
        expect(
          signalled.where((n) => n.title.contains('ajouté deux fois')),
          hasLength(1),
        );
        expect(
          signalled.firstWhere((n) => n.title.contains('ajouté deux fois')).body,
          contains('Taux horaire différent'),
        );
      }
    });

    test('the same CIN in two stores: two people, signalled', () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);
      final second = await StoreRepository(b).createStore(
        name: 'Annexe',
        addressLine: '',
        postalCode: '',
        city: 'Namur',
        phone: '081',
      );
      await settle(a, b);

      await addSami(a, shop.store.id, phone: '0471');
      await addSami(b, second.id, phone: '0472');
      await settle(a, b);

      for (final db in [a, b]) {
        expect(await samis(db), hasLength(2));
        final signalled = [
          ...await flags(db, shop.store.id),
          ...await flags(db, second.id),
        ];
        expect(signalled, hasLength(1));
        expect(signalled.single.title, contains('Même CIN'));
      }
    });

    test('retired on one, pointed on the other: hours kept, signalled (E4)',
        () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);

      await EmployeeRepository(a).archive(shop.cook.id, at: on(12, 7));
      await AttendanceRepository(
        b,
      ).clockIn(shop.cook.id, shop.store.id, now: on(12, 8));
      await settle(a, b);

      for (final db in [a, b]) {
        final cook = (await EmployeeRepository(db).employee(shop.cook.id))!;
        expect(cook.archivedAt, isNotNull);
        expect(await AttendanceRepository(db).forEmployee(cook.id), hasLength(1));
        final signalled = await flags(db, shop.store.id);
        expect(signalled, hasLength(1));
        expect(signalled.single.title, contains('après le retrait'));
        expect(signalled.single.relatedTarget, 'payroll');
      }
    });

    test('the rate changed on both: the last wins, signalled (E2)', () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);

      await EmployeeRepository(a).update(shop.cook.id, pay: 16);
      await EmployeeRepository(b).update(shop.cook.id, pay: 17);
      await settle(a, b);

      for (final db in [a, b]) {
        expect((await EmployeeRepository(db).employee(shop.cook.id))!.pay, 17);
        final signalled = await flags(db, shop.store.id);
        expect(signalled, hasLength(1));
        expect(signalled.single.body, contains('taux horaire'));
      }
    });

    test('retired on one, retired and brought back on the other: the last '
        'decision wins, signalled (E5)', () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);

      await EmployeeRepository(a).archive(shop.cook.id, at: on(12, 7));
      await EmployeeRepository(b).archive(shop.cook.id, at: on(12, 9));
      await EmployeeRepository(b).restore(shop.cook.id);
      await settle(a, b);

      for (final db in [a, b]) {
        expect(
          (await EmployeeRepository(db).employee(shop.cook.id))!.archivedAt,
          isNull,
        );
        final signalled = await flags(db, shop.store.id);
        expect(signalled, hasLength(1));
        expect(signalled.single.body, contains('réactivation est gardée'));
      }
    });

    test('a rate changed once, then again elsewhere: not signalled', () async {
      final a = await newDevice();
      final b = await newDevice();
      final shop = await shared(a, b);

      await EmployeeRepository(a).update(shop.cook.id, pay: 16);
      await settle(a, b);
      await EmployeeRepository(b).update(shop.cook.id, pay: 17);
      await settle(a, b);

      expect(await flags(a, shop.store.id), isEmpty);
    });
  });

  // Rule P5 (SYNC_PERSONNEL_PLAN.md): one journée per store and date.
  group('two journées opened for one store and date', () {
    Future<List<BusinessDayRow>> liveDays(AppDatabase db) =>
        (db.select(db.businessDays)..where((d) => d.deletedAt.isNull())).get();

    test('keep the smaller id on both tablets, and no pointage moves',
        () async {
      final a = await newDevice();
      final b = await newDevice();
      final day = await shared(a, b);
      final morning = DateTime(2026, 10, 12, 8);

      // Offline, each tablet's first Pointer opens "the" journée.
      await AttendanceRepository(
        a,
      ).clockIn(day.cook.id, day.store.id, now: morning);
      await AttendanceRepository(
        b,
      ).clockIn(day.owner.id, day.store.id, now: morning);
      final ids = [
        (await liveDays(a)).single.id,
        (await liveDays(b)).single.id,
      ]..sort();

      await settle(a, b);

      for (final db in [a, b]) {
        final kept = (await liveDays(db)).single;
        expect(kept.id, ids.first);
        expect(kept.date, DateTime(2026, 10, 12));
        final days = await (db.select(
          db.attendances,
        )..where((r) => r.deletedAt.isNull())).get();
        expect(days, hasLength(2));
        expect(days.map((r) => r.date).toSet(), {DateTime(2026, 10, 12)});
      }
      final notes = [
        ...await SyncErrorRepository(a).all(),
        ...await SyncErrorRepository(b).all(),
      ];
      expect(
        notes.map((n) => n.reason),
        contains('resolved_double_business_day'),
      );
      expect(notes.map((n) => n.reason), isNot(contains('receive_conflict')));
    });

    test('a close made on either tablet is kept', () async {
      final a = await newDevice();
      final b = await newDevice();
      final day = await shared(a, b);
      final morning = DateTime(2026, 10, 12, 8);
      final evening = DateTime(2026, 10, 12, 23);

      final onA = (await BusinessDayRepository(a).open(
        day.store.id,
        now: morning,
      ))!;
      final onB = (await BusinessDayRepository(b).open(
        day.store.id,
        now: morning,
      ))!;
      // Close the one that will be dropped, so the close has to move.
      final dropped = onA.id.compareTo(onB.id) > 0 ? a : b;
      final droppedId = dropped == a ? onA.id : onB.id;
      await BusinessDayRepository(dropped).close(
        droppedId,
        closedByEmployeeId: day.owner.id,
        now: evening,
      );

      await settle(a, b);

      for (final db in [a, b]) {
        final kept = (await liveDays(db)).single;
        expect(kept.id, isNot(droppedId));
        expect(kept.closedAt, evening);
        expect(kept.closedByEmployeeId, day.owner.id);
      }
    });
  });

  test('the day already linked to a pay period is the one kept', () async {
    final a = await newDevice();
    final b = await newDevice();
    final day = await shared(a, b);
    final morning = DateTime(2026, 10, 12, 8);
    final local = (await AttendanceRepository(
      b,
    ).clockIn(day.cook.id, day.store.id, now: morning))!;
    await b
        .into(b.payrollPeriods)
        .insert(
          PayrollPeriodsCompanion.insert(
            id: 'period-1',
            employeeId: day.cook.id,
            storeId: day.store.id,
            startDate: DateTime(2026, 10),
            endDate: DateTime(2026, 10, 31),
            workedDays: 1,
            totalWorkedHours: 8,
            appliedRate: 15,
            computedAmount: 120,
            status: PayrollStatus.paid,
            createdAt: morning,
          ),
        );
    await b.customStatement(
      "UPDATE attendances SET payroll_period_id = 'period-1' WHERE id = ?",
      [local.id],
    );

    // Another tablet's day for the same employee and date, unpaid, with an
    // id that would win the tie-break.
    await SyncApplier(b).apply(
      day.store.id,
      PullPage(
        changes: [
          PulledChange(
            seq: 900,
            table: 'attendances',
            row: {
              'id': '0-other-day',
              'store_id': day.store.id,
              'employee_id': day.cook.id,
              'date': local.date.toUtc().toIso8601String(),
              'status': 'working',
              'max_break_minutes': 30,
              'payroll_period_id': null,
              'updated_at': '2026-10-12T06:00:00.000Z',
              'deleted_at': null,
            },
          ),
        ],
        nextAfter: 900,
        hasMore: false,
      ),
    );

    final days = await AttendanceRepository(b).forEmployee(day.cook.id);
    expect(days.single.id, local.id, reason: 'the paid day stays');
  });

  test('the same supplier linked twice keeps the most recent link', () async {
    final a = await newDevice();
    final b = await newDevice();
    final day = await shared(a, b);
    final category = (await CatalogRepository(
      a,
    ).createCategory(storeId: day.store.id, name: 'Légumes'))!;
    final unit = (await CatalogRepository(a).createUnit(
      storeId: day.store.id,
      name: 'Kilogramme',
      abbreviation: 'kg',
    ))!;
    final item = (await ItemRepository(a).create(
      storeId: day.store.id,
      name: 'Tomates',
      categoryId: category.id,
      unitId: unit.id,
      lowStockThreshold: 1,
    ))!;
    final supplier = await SupplierRepository(a).create(
      storeId: day.store.id,
      name: 'Maraîcher',
      contactName: 'X',
      email: 'x@example.be',
      phone: '0',
      addressLine: 'Rue 1',
      postalCode: '5000',
      city: 'Namur',
    );
    await sync(a);
    await sync(b);

    await SupplierRepository(
      a,
    ).linkItem(itemId: item.id, supplierId: supplier.id, pricePerUnit: 2);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await SupplierRepository(
      b,
    ).linkItem(itemId: item.id, supplierId: supplier.id, pricePerUnit: 3);

    await settle(a, b);

    for (final db in [a, b]) {
      final prices = await SupplierRepository(db).pricesForItem(item.id);
      expect(prices, hasLength(1));
      expect(prices.single.pricePerUnit, 3, reason: 'B linked last');
      expect(prices.single.isDefault, isTrue);
    }
  });

  test(
    'duplicate categories merge, and the merge reaches the other tablet',
    () async {
      final a = await newDevice();
      final b = await newDevice();
      final day = await shared(a, b);
      final unit = (await CatalogRepository(
        a,
      ).createUnit(storeId: day.store.id, name: 'Pièce', abbreviation: 'pc'))!;
      await sync(a);
      await sync(b);

      // Both tablets create "Boissons" offline, and file an article under it.
      final onA = (await CatalogRepository(
        a,
      ).createCategory(storeId: day.store.id, name: 'Boissons'))!;
      final onB = (await CatalogRepository(
        b,
      ).createCategory(storeId: day.store.id, name: 'Boissons'))!;
      final cola = (await ItemRepository(b).create(
        storeId: day.store.id,
        name: 'Cola',
        categoryId: onB.id,
        unitId: unit.id,
        lowStockThreshold: 1,
      ))!;
      await settle(a, b);
      expect(
        (await CatalogRepository(
          a,
        ).categories(day.store.id)).where((c) => c.name == 'Boissons'),
        hasLength(2),
        reason: 'nobody was blocked offline',
      );

      expect(
        await CatalogRepository(a).mergeCategories(onB.id, onA.id),
        isTrue,
      );
      await settle(a, b);

      for (final db in [a, b]) {
        final names = (await CatalogRepository(
          db,
        ).categories(day.store.id)).map((c) => c.name);
        expect(names.where((n) => n == 'Boissons'), hasLength(1));
        expect((await ItemRepository(db).item(cola.id))!.categoryId, onA.id);
      }
    },
  );

  test('overlapping sessions are detected, back-to-back ones are not', () {
    Attendance day(List<AttendanceSession> sessions) => Attendance(
      id: 'd',
      storeId: 's',
      employeeId: 'e',
      date: DateTime(2026, 10, 12),
      status: AttendanceStatus.done,
      sessions: sessions,
      paymentStatus: PaymentStatus.unpaid,
    );
    DateTime at(int h, [int m = 0]) => DateTime(2026, 10, 12, h, m);

    expect(
      hasOverlappingSessions(
        day([
          AttendanceSession(clockInAt: at(8), clockOutAt: at(12)),
          AttendanceSession(clockInAt: at(12), clockOutAt: at(16)),
        ]),
      ),
      isFalse,
    );
    expect(
      hasOverlappingSessions(
        day([
          AttendanceSession(clockInAt: at(8), clockOutAt: at(12)),
          AttendanceSession(clockInAt: at(8, 5), clockOutAt: at(12)),
        ]),
      ),
      isTrue,
    );
    expect(
      hasOverlappingSessions(
        day([
          AttendanceSession(clockInAt: at(8)),
          AttendanceSession(clockInAt: at(9)),
        ]),
      ),
      isTrue,
      reason: 'a second clock-in while the first is still open',
    );
  });
}
