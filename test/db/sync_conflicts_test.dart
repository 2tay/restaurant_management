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

  test('a password set twice keeps the most recent one', () async {
    final a = await newDevice();
    final b = await newDevice();
    final day = await shared(a, b);

    // The owner had no password yet; both tablets set one, offline.
    await CredentialRepository(a).setPassword(day.owner.id, '1111');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await CredentialRepository(b).setPassword(day.owner.id, '2222');

    await settle(a, b);

    for (final db in [a, b]) {
      final login = await CredentialRepository(
        db,
      ).authenticate('PIN-LEA', '2222');
      expect(login.outcome, LoginOutcome.success);
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
