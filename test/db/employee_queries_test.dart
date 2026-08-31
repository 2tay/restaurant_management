// The employee-module read repositories, checked against the implementation
// they replace.
//
// `MockQueries` is still here and still correct, and the seeded database is
// built from the same dataset. The employee module is date-anchored — the seed
// shifts its timestamps by a whole number of days — so every time of day is
// preserved and the two implementations agree on everything that is not tied to
// a specific calendar date. Where they cannot agree (the absolute "today", the
// reads the plan asked to be rewritten as SQL) the difference is asserted
// directly.
//
// Goes away with `MockQueries` in stage 10.

import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/core/utils/attendance_status.dart';
import 'package:stock_inventory/core/utils/payroll_math.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/mock_data/mock_data.dart';
import 'package:stock_inventory/models/models.dart';

import '../support/db_fixture.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await openSeededDatabase();
  });

  // The seed anchors the employee module on `seedInstant`'s calendar, so that
  // is what "now" is for every clock-sensitive read below.
  AttendanceRepository attendance() =>
      AttendanceRepository(db, clock: () => seedInstant);

  Set<String> ids(Iterable<dynamic> rows) =>
      rows.map((r) => r.id as String).toSet();

  group('employees', () {
    test('the roster holds the same people as the dataset', () async {
      final repo = EmployeeRepository(db);
      expect(
        ids(await repo.employees(StoreIds.sablon)),
        ids(MockQueries.employeesForStore(StoreIds.sablon)),
      );
      expect(
        ids(await repo.employees(StoreIds.testCalcul)),
        ids(MockQueries.employeesForStore(StoreIds.testCalcul)),
      );
      expect(await repo.employees(StoreIds.saintGilles), isEmpty);
    });

    test('active hides the archived record but it still resolves by id',
        () async {
      final repo = EmployeeRepository(db);
      final active = await repo.activeEmployees(StoreIds.sablon);

      expect(
        ids(active),
        ids(MockQueries.activeEmployeesForStore(StoreIds.sablon)),
      );
      expect(ids(active), isNot(contains(EmployeeIds.camille)));
      expect((await repo.employee(EmployeeIds.camille))?.archivedAt, isNotNull);
    });

    test('is ordered by display name', () async {
      final names = (await EmployeeRepository(db).employees(StoreIds.sablon))
          .map((e) => e.firstName)
          .toList();
      expect(names, orderedEquals([...names]..sort()));
    });

    test('CIN and email lookups are account-wide and self-excluding', () async {
      final repo = EmployeeRepository(db);
      final marc = (await repo.employee(EmployeeIds.marc))!;

      expect((await repo.employeeByCin(' ${marc.cin} '))?.id, marc.id);
      expect((await repo.employeeByEmail(marc.email.toUpperCase()))?.id, marc.id);
      expect(
        await repo.employeeByCin(marc.cin, excludingId: marc.id),
        isNull,
        reason: 'an edit must not collide with the row being edited',
      );
      expect(await repo.employeeByEmail('nobody@example.be'), isNull);
    });
  });

  group('credentials', () {
    test('resolve for a seeded employee and miss cleanly otherwise', () async {
      final repo = CredentialRepository(db);
      expect(await repo.forEmployee(EmployeeIds.marc), isNotNull);
      expect(
        (await repo.forEmployee(EmployeeIds.amelie))?.employeeId,
        EmployeeIds.amelie,
      );
      expect(await repo.forEmployee('employee-nope'), isNull);
    });
  });

  group('pointage reads', () {
    test('today resolves the in-progress row and is null when there is none',
        () async {
      final repo = attendance();

      expect(
        (await repo.today(EmployeeIds.karim))?.id,
        MockQueries.attendanceForToday(EmployeeIds.karim)!.id,
      );
      expect(
        await repo.today(EmployeeIds.noah),
        isNull,
        reason: 'Noah has no row today',
      );
    });

    test('watchToday pushes the same row', () async {
      final row =
          await attendance().watchToday(EmployeeIds.fatima).first;
      expect(row?.id, MockQueries.attendanceForToday(EmployeeIds.fatima)!.id);
      expect(row?.pauses, isNotEmpty);
    });

    test('one employee\'s history is most-recent-day-first, with its pauses',
        () async {
      final rows = await attendance().forEmployee(EmployeeIds.karim);

      expect(ids(rows), ids(MockQueries.attendancesForEmployee(EmployeeIds.karim)));
      for (var i = 1; i < rows.length; i++) {
        expect(
          rows[i - 1].date.isBefore(rows[i].date),
          isFalse,
          reason: 'newest day first',
        );
      }
      final withPause = rows.firstWhere((a) => a.pauses.isNotEmpty);
      expect(
        withPause.pauses.map((p) => p.startAt),
        orderedEquals([...withPause.pauses.map((p) => p.startAt)]..sort()),
      );
    });

    test('the store log paginates and keeps its order', () async {
      final repo = attendance();
      final expected = MockQueries.attendancesForStore(StoreIds.sablon);

      final all = await repo.page(StoreIds.sablon, pageSize: 100);
      expect(all.totalCount, expected.totalCount);
      expect(ids(all.rows), ids(expected.rows));

      final first = await repo.page(StoreIds.sablon, pageSize: 3, page: 0);
      final second = await repo.page(StoreIds.sablon, pageSize: 3, page: 1);
      expect(first.rows, hasLength(3));
      expect(first.pageCount, (expected.totalCount + 2) ~/ 3);
      expect(
        ids(first.rows).intersection(ids(second.rows)),
        isEmpty,
        reason: 'pages do not overlap',
      );

      // Clamped past the end.
      final beyond = await repo.page(StoreIds.sablon, pageSize: 3, page: 999);
      expect(beyond.page, first.pageCount - 1);
    });

    test('the store log filters combine with AND', () async {
      final repo = attendance();

      final working = await repo.page(
        StoreIds.sablon,
        status: AttendanceStatus.working,
        pageSize: 100,
      );
      expect(
        working.rows.every((a) => a.status == AttendanceStatus.working),
        isTrue,
      );
      expect(
        working.totalCount,
        MockQueries.attendancesForStore(
          StoreIds.sablon,
          status: AttendanceStatus.working,
        ).totalCount,
      );

      final karim = await repo.page(
        StoreIds.sablon,
        employeeId: EmployeeIds.karim,
        pageSize: 100,
      );
      expect(karim.rows.every((a) => a.employeeId == EmployeeIds.karim), isTrue);
    });

    test('the KPI header agrees with the mock, arithmetic included', () async {
      final stats = await attendance().stats(StoreIds.sablon);
      final expected = MockQueries.attendanceStatsForStore(StoreIds.sablon);

      expect(stats.days, expected.days);
      expect(stats.worked, expected.worked);
      expect(stats.overtime, expected.overtime);
      expect(stats.lateArrivals, expected.lateArrivals);
      expect(stats.lateBreaks, expected.lateBreaks);
    });

    test('the KPI header narrows to one employee', () async {
      final stats = await attendance().stats(
        StoreIds.sablon,
        employeeId: EmployeeIds.amelie,
      );
      final expected = MockQueries.attendanceStatsForStore(
        StoreIds.sablon,
        employeeId: EmployeeIds.amelie,
      );
      expect(stats.days, expected.days);
      expect(stats.worked, expected.worked);
      expect(stats.overtime, expected.overtime);
    });
  });

  group('payroll reads', () {
    test('a run resolves by id, and an employee\'s runs are most-recent first',
        () async {
      final repo = PayrollRepository(db);
      expect(await repo.period(PayrollPeriodIds.karimSeed), isNotNull);
      expect(
        ids(await repo.forEmployee(EmployeeIds.karim)),
        ids(MockQueries.payrollPeriodsForEmployee(EmployeeIds.karim)),
      );
    });

    test('the store history filters on the rolling window', () async {
      final repo = PayrollRepository(db);

      final all = await repo.page(StoreIds.sablon, now: seedInstant);
      expect(all.totalCount, 1);

      final none = await repo.page(
        StoreIds.sablon,
        withinDays: 0,
        now: seedInstant,
      );
      expect(none.totalCount, 0, reason: 'the run was paid before the cutoff');

      final wide = await repo.page(
        StoreIds.sablon,
        withinDays: 3650,
        now: seedInstant,
      );
      expect(wide.totalCount, 1);
    });

    test('the store history searches on employee name', () async {
      final repo = PayrollRepository(db);
      final hit = await repo.page(StoreIds.testCalcul, employeeQuery: 'hakim');
      expect(hit.rows.map((p) => p.employeeId), [EmployeeIds.hakim]);

      final miss = await repo.page(
        StoreIds.testCalcul,
        employeeQuery: 'nobody',
      );
      expect(miss.totalCount, 0);
    });

    test('the day-by-day view matches the mock, KPI figures included', () async {
      final repo = PayrollRepository(db);

      for (final storeId in [StoreIds.sablon, StoreIds.testCalcul]) {
        final got = await repo.days(storeId, pageSize: 500);
        final expected = MockQueries.payrollDays(storeId, pageSize: 500);

        expect(got.totalCount, expected.totalCount, reason: storeId);
        expect(ids(got.rows), ids(expected.rows), reason: storeId);
        expect(got.paidDays, expected.paidDays, reason: storeId);
        expect(got.unpaidDays, expected.unpaidDays, reason: storeId);
        expect(got.worked, expected.worked, reason: storeId);
        expect(got.overtime, expected.overtime, reason: storeId);
      }
    });

    test('the day-by-day view scopes to one employee and honours the status '
        'filter without moving the KPI counts', () async {
      final repo = PayrollRepository(db);

      final all = await repo.days(
        StoreIds.testCalcul,
        employeeId: EmployeeIds.ayoub,
        pageSize: 500,
      );
      final paidOnly = await repo.days(
        StoreIds.testCalcul,
        employeeId: EmployeeIds.ayoub,
        status: PaymentStatus.paid,
        pageSize: 500,
      );

      expect(all.rows.every((a) => a.employeeId == EmployeeIds.ayoub), isTrue);
      expect(
        paidOnly.rows.every((a) => a.paymentStatus == PaymentStatus.paid),
        isTrue,
      );
      expect(paidOnly.totalCount, all.paidDays);
      expect(
        paidOnly.paidDays,
        all.paidDays,
        reason: 'the KPI counts stay over the whole range',
      );
      expect(paidOnly.unpaidDays, all.unpaidDays);
    });
  });

  group('store settings', () {
    test('reads back the full six-field record', () async {
      final settings = await StoreRepository(db).settings(StoreIds.sablon);
      final expected = MockQueries.storeSettings(StoreIds.sablon);

      expect(settings.openMinutes, expected.openMinutes);
      expect(settings.closeMinutes, expected.closeMinutes);
      expect(settings.maxBreakMinutes, expected.maxBreakMinutes);
      expect(settings.overtimeMultiplier, expected.overtimeMultiplier);
      expect(settings.workingDaysPerMonth, expected.workingDaysPerMonth);
      expect(settings.stalePartialOrderDays, expected.stalePartialOrderDays);
    });

    test('synthesises defaults for a store with no row', () async {
      final settings = await StoreRepository(db).settings('store-nope');
      expect(settings.openMinutes, AttendanceRules.defaultOpenMinutes);
      expect(settings.workingDaysPerMonth, PayrollRules.defaultWorkingDaysPerMonth);
    });
  });

  group('streams push when the data changes', () {
    test('a new pointage row reaches a watcher', () async {
      final repo = attendance();
      final watcher = StreamIterator(repo.watchForEmployee(EmployeeIds.noah));
      addTearDown(watcher.cancel);

      expect(await watcher.moveNext(), isTrue);
      final before = watcher.current.length;

      await db.into(db.attendances).insert(
            AttendancesCompanion.insert(
              id: 'att-noah-live',
              storeId: StoreIds.sablon,
              employeeId: EmployeeIds.noah,
              date: DateTime(2026, 8, 29),
              status: AttendanceStatus.working,
              clockInAt: Value(DateTime(2026, 8, 29, 8)),
            ),
          );

      expect(await watcher.moveNext(), isTrue);
      expect(watcher.current.length, before + 1);
    });
  });
}
