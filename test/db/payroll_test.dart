// The payroll rules — the maths, the "Payer" lock, and the permanence of a
// paid period, against the database.
//
// Ported from `test/payroll_test.dart`. The `hourlyRate` / `dayAmount`
// arithmetic groups operate on plain objects and are unchanged; `preview` /
// `pay` / `days` run against a seeded in-memory database at a fixed instant.
// `PayrollRepository.pay` is the only writer of a `PayrollPeriod` and the only
// path that locks an attendance day to a run — one transaction, proven to roll
// back whole.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/core/utils/payroll_math.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/mappers/mappers.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart'
    show EmployeeIds, PayrollPeriodIds, StoreIds;
import 'package:stock_inventory/models/models.dart';

import '../support/db_fixture.dart';

void main() {
  late AppDatabase db;
  late PayrollRepository payroll;
  late EmployeeRepository employees;

  setUp(() async {
    db = await openSeededDatabase();
    payroll = PayrollRepository(db);
    employees = EmployeeRepository(db);
  });

  DateTime daysAgo(int n) => seedInstant.subtract(Duration(days: n));

  /// Inserts a finished day for [employeeId] at Sablon, [n] days before the
  /// seed instant, with the given clock times and no breaks.
  Future<void> seedDoneDay(
    int n, {
    required String employeeId,
    required (int, int) clockIn,
    required (int, int) clockOut,
    String? payrollPeriodId,
  }) async {
    final d = daysAgo(n);
    final day = DateTime(d.year, d.month, d.day);
    await db
        .into(db.attendances)
        .insert(
          attendanceToRow(
            Attendance(
              id: 'pay-test-$employeeId-$n',
              storeId: StoreIds.sablon,
              employeeId: employeeId,
              date: day,
              status: AttendanceStatus.done,
              clockInAt: DateTime(
                day.year,
                day.month,
                day.day,
                clockIn.$1,
                clockIn.$2,
              ),
              clockOutAt: DateTime(
                day.year,
                day.month,
                day.day,
                clockOut.$1,
                clockOut.$2,
              ),
              pauses: const [],
              paymentStatus: payrollPeriodId == null
                  ? PaymentStatus.unpaid
                  : PaymentStatus.paid,
              payrollPeriodId: payrollPeriodId,
            ),
          ),
        );
  }

  Future<Attendance?> dayById(String id) =>
      AttendanceRepository(db, clock: () => seedInstant).attendance(id);

  group('the maths', () {
    test('an extra is paid their hourly rate; a fixed employee a derived one',
        () async {
      final settings = await StoreRepository(db).settings(StoreIds.sablon);
      final julien = (await employees.employee(EmployeeIds.julien))!; // extra
      final karim = (await employees.employee(EmployeeIds.karim))!; // fixed 2400

      expect(hourlyRate(julien, settings), 13);
      expect(hourlyRate(karim, settings), closeTo(2400 / 26 / 8, 0.001));
    });

    test('overtime hours carry the multiplier premium', () async {
      final settings = await StoreRepository(db).settings(StoreIds.sablon);
      final julien = (await employees.employee(EmployeeIds.julien))!;
      final day = Attendance(
        id: 'x',
        storeId: StoreIds.sablon,
        employeeId: EmployeeIds.julien,
        date: DateTime(2026, 1, 5),
        status: AttendanceStatus.done,
        clockInAt: DateTime(2026, 1, 5, 9),
        clockOutAt: DateTime(2026, 1, 5, 18), // 1h overtime past 17:00
        pauses: const [],
        paymentStatus: PaymentStatus.unpaid,
      );

      final expected =
          9 * 13 + (settings.overtimeMultiplier - 1) * 13; // base + premium
      expect(
        dayAmount(day, julien, settings, scheduledEndMinutes: 17 * 60),
        closeTo(expected, 0.001),
      );
    });

    test('a day that is not done is worth nothing', () async {
      final settings = await StoreRepository(db).settings(StoreIds.sablon);
      final julien = (await employees.employee(EmployeeIds.julien))!;
      final open = Attendance(
        id: 'x',
        storeId: StoreIds.sablon,
        employeeId: EmployeeIds.julien,
        date: DateTime(2026, 1, 5),
        status: AttendanceStatus.working,
        clockInAt: DateTime(2026, 1, 5, 9),
        pauses: const [],
        paymentStatus: PaymentStatus.unpaid,
      );
      expect(
        dayAmount(open, julien, settings, scheduledEndMinutes: 17 * 60),
        0,
      );
    });
  });

  group('preview', () {
    test('sums the unpaid finished days and stores nothing', () async {
      await seedDoneDay(4, employeeId: EmployeeIds.julien, clockIn: (9, 0),
          clockOut: (15, 0));
      await seedDoneDay(5, employeeId: EmployeeIds.julien, clockIn: (9, 0),
          clockOut: (16, 0));

      final periodsBefore =
          (await db.select(db.payrollPeriods).get()).length;
      final preview =
          await payroll.preview(EmployeeIds.julien, StoreIds.sablon);

      expect(preview.days, hasLength(2));
      expect(preview.amount, greaterThan(0));
      expect((await db.select(db.payrollPeriods).get()).length, periodsBefore);
      expect(
        (await dayById('pay-test-${EmployeeIds.julien}-4'))!.paymentStatus,
        PaymentStatus.unpaid,
      );
    });

    test('is empty when nothing is owed', () async {
      // Marc has no attendance rows at all.
      final preview =
          await payroll.preview(EmployeeIds.marc, StoreIds.sablon);
      expect(preview.isEmpty, isTrue);
      expect(preview.amount, 0);
    });

    test('excludes days outside the from bound', () async {
      await seedDoneDay(5, employeeId: EmployeeIds.julien, clockIn: (9, 0),
          clockOut: (17, 0));
      await seedDoneDay(60, employeeId: EmployeeIds.julien, clockIn: (9, 0),
          clockOut: (17, 0));

      expect(
        (await payroll.preview(EmployeeIds.julien, StoreIds.sablon,
                from: daysAgo(30)))
            .days,
        hasLength(1),
      );
      expect(
        (await payroll.preview(EmployeeIds.julien, StoreIds.sablon)).days,
        hasLength(2),
      );
    });

    test('a day before the hire date is never payable', () async {
      // Julien joined ~4 months before the seed — a day 200 days back predates
      // it.
      await seedDoneDay(200, employeeId: EmployeeIds.julien, clockIn: (9, 0),
          clockOut: (17, 0));
      expect(
        (await payroll.preview(EmployeeIds.julien, StoreIds.sablon)).days,
        isEmpty,
      );
    });
  });

  group('pay', () {
    test('creates the period, locks every covered day, freezes the rate',
        () async {
      await seedDoneDay(4, employeeId: EmployeeIds.julien, clockIn: (9, 0),
          clockOut: (15, 0));
      await seedDoneDay(5, employeeId: EmployeeIds.julien, clockIn: (9, 0),
          clockOut: (16, 0));
      final owed =
          (await payroll.preview(EmployeeIds.julien, StoreIds.sablon)).amount;

      final period = (await payroll.pay(
        EmployeeIds.julien,
        StoreIds.sablon,
        paidByEmployeeId: EmployeeIds.marc,
        now: seedInstant,
      ))!;

      expect(period.status, PayrollStatus.paid);
      expect(period.computedAmount, closeTo(owed, 0.001));
      expect(period.appliedRate, 13);
      expect(period.workedDays, 2);

      for (final n in [4, 5]) {
        final day = (await dayById('pay-test-${EmployeeIds.julien}-$n'))!;
        expect(day.paymentStatus, PaymentStatus.paid);
        expect(day.payrollPeriodId, period.id);
      }

      expect(
        (await payroll.preview(EmployeeIds.julien, StoreIds.sablon)).isEmpty,
        isTrue,
      );
    });

    test('a later raise does not move a period already paid', () async {
      await seedDoneDay(4, employeeId: EmployeeIds.julien, clockIn: (9, 0),
          clockOut: (15, 0));
      final period = (await payroll.pay(
        EmployeeIds.julien,
        StoreIds.sablon,
        paidByEmployeeId: EmployeeIds.marc,
        now: seedInstant,
      ))!;
      final frozen = period.computedAmount;

      await employees.update(EmployeeIds.julien, pay: 99);

      final reread = (await payroll.period(period.id))!;
      expect(reread.computedAmount, frozen);
      expect(reread.appliedRate, 13);
    });

    test('a day locked by a payment refuses every attendance write', () async {
      await seedDoneDay(4, employeeId: EmployeeIds.julien, clockIn: (9, 0),
          clockOut: (15, 0));
      await payroll.pay(
        EmployeeIds.julien,
        StoreIds.sablon,
        paidByEmployeeId: EmployeeIds.marc,
        now: seedInstant,
      );

      final attendance = AttendanceRepository(db, clock: () => seedInstant);
      const id = 'pay-test-employee-julien-4';
      expect(await attendance.startPause(id), isNull);
      expect(await attendance.clockOut(id), isNull);
    });

    test('paying when nothing is owed returns null', () async {
      expect(
        await payroll.pay(
          EmployeeIds.marc,
          StoreIds.sablon,
          paidByEmployeeId: EmployeeIds.marc,
        ),
        isNull,
      );
    });

    test('pay(from:, to:) settles only the days in the shown range', () async {
      await seedDoneDay(5, employeeId: EmployeeIds.julien, clockIn: (9, 0),
          clockOut: (17, 0));
      await seedDoneDay(60, employeeId: EmployeeIds.julien, clockIn: (9, 0),
          clockOut: (17, 0));

      final first = (await payroll.pay(
        EmployeeIds.julien,
        StoreIds.sablon,
        from: daysAgo(30),
        to: daysAgo(0),
        paidByEmployeeId: EmployeeIds.marc,
        now: seedInstant,
      ))!;
      expect(first.workedDays, 1);
      expect(
        (await dayById('pay-test-${EmployeeIds.julien}-5'))!.paymentStatus,
        PaymentStatus.paid,
      );
      expect(
        (await dayById('pay-test-${EmployeeIds.julien}-60'))!.paymentStatus,
        PaymentStatus.unpaid,
      );

      // Widening the range settles the older day.
      final second = (await payroll.pay(
        EmployeeIds.julien,
        StoreIds.sablon,
        from: daysAgo(90),
        to: daysAgo(0),
        paidByEmployeeId: EmployeeIds.marc,
        now: seedInstant,
      ))!;
      expect(second.workedDays, 1);
      expect(
        (await dayById('pay-test-${EmployeeIds.julien}-60'))!.paymentStatus,
        PaymentStatus.paid,
      );
    });

    test('two concurrent pay calls leave exactly one period, whole', () async {
      await seedDoneDay(4, employeeId: EmployeeIds.julien, clockIn: (9, 0),
          clockOut: (17, 0));
      await seedDoneDay(5, employeeId: EmployeeIds.julien, clockIn: (9, 0),
          clockOut: (17, 0));

      // The double-submitted "Payer" button. Each `pay` re-reads the payable
      // days inside its own transaction; drift serialises the two, so the
      // second sees both days already locked and finds nothing to pay.
      // (Remove the `_db.transaction` wrapper in `pay` and the second call
      // inserts a stranded period covering zero days — the teeth.)
      final results = await Future.wait([
        payroll.pay(EmployeeIds.julien, StoreIds.sablon,
            paidByEmployeeId: EmployeeIds.marc, now: seedInstant),
        payroll.pay(EmployeeIds.julien, StoreIds.sablon,
            paidByEmployeeId: EmployeeIds.marc, now: seedInstant),
      ]);

      final periods = await db.select(db.payrollPeriods).get();
      final mine = periods.where((p) => p.employeeId == EmployeeIds.julien);
      expect(mine, hasLength(1));

      final period = results.firstWhere((p) => p != null)!;
      for (final n in [4, 5]) {
        expect(
          (await dayById('pay-test-${EmployeeIds.julien}-$n'))!.payrollPeriodId,
          period.id,
        );
      }
    });
  });

  group('days', () {
    test('counts paid and unpaid days independent of the status filter',
        () async {
      await seedDoneDay(4, employeeId: EmployeeIds.julien, clockIn: (9, 0),
          clockOut: (17, 0));
      await seedDoneDay(5, employeeId: EmployeeIds.julien, clockIn: (9, 0),
          clockOut: (17, 0), payrollPeriodId: PayrollPeriodIds.karimSeed);

      final all = await payroll.days(
        StoreIds.sablon,
        employeeId: EmployeeIds.julien,
        pageSize: 500,
      );
      expect(all.paidDays, 1);
      expect(all.unpaidDays, 1);
      expect(all.rows, hasLength(2));

      final unpaidOnly = await payroll.days(
        StoreIds.sablon,
        employeeId: EmployeeIds.julien,
        status: PaymentStatus.unpaid,
        pageSize: 500,
      );
      expect(unpaidOnly.rows, hasLength(1));
      expect(unpaidOnly.totalCount, 1);
      expect(unpaidOnly.paidDays, 1);
      expect(unpaidOnly.unpaidDays, 1);
    });

    test('without an employee id, aggregates every active person', () async {
      await seedDoneDay(4, employeeId: EmployeeIds.julien, clockIn: (9, 0),
          clockOut: (17, 0));
      await seedDoneDay(4, employeeId: EmployeeIds.amelie, clockIn: (9, 0),
          clockOut: (17, 0));

      final store = await payroll.days(StoreIds.sablon, pageSize: 500);
      final julienOnly = await payroll.days(
        StoreIds.sablon,
        employeeId: EmployeeIds.julien,
        pageSize: 500,
      );

      expect(
        store.rows.map((a) => a.employeeId).toSet(),
        containsAll(<String>{EmployeeIds.julien, EmployeeIds.amelie}),
      );
      expect(store.unpaidDays, greaterThan(julienOnly.unpaidDays));
    });

    test('applies the from / to range', () async {
      await seedDoneDay(5, employeeId: EmployeeIds.julien, clockIn: (9, 0),
          clockOut: (17, 0));
      await seedDoneDay(60, employeeId: EmployeeIds.julien, clockIn: (9, 0),
          clockOut: (17, 0));
      final windowed = await payroll.days(
        StoreIds.sablon,
        employeeId: EmployeeIds.julien,
        from: daysAgo(30),
        to: daysAgo(0),
        pageSize: 500,
      );
      expect(windowed.rows, hasLength(1));
    });

    test('excludes days before the hire date', () async {
      await seedDoneDay(200, employeeId: EmployeeIds.julien, clockIn: (9, 0),
          clockOut: (17, 0));
      final data = await payroll.days(
        StoreIds.sablon,
        employeeId: EmployeeIds.julien,
        from: daysAgo(365),
        pageSize: 500,
      );
      expect(data.rows.where((a) => a.id == 'pay-test-${EmployeeIds.julien}-200'),
          isEmpty);
    });

    test('paginates past the page size', () async {
      for (var i = 4; i < 30; i++) {
        await seedDoneDay(i, employeeId: EmployeeIds.julien, clockIn: (9, 0),
            clockOut: (17, 0));
      }
      final first = await payroll.days(
        StoreIds.sablon,
        employeeId: EmployeeIds.julien,
        from: daysAgo(365),
        pageSize: 25,
      );
      expect(first.rows, hasLength(25));
      expect(first.pageCount, 2);

      final second = await payroll.days(
        StoreIds.sablon,
        employeeId: EmployeeIds.julien,
        from: daysAgo(365),
        pageSize: 25,
        page: 1,
      );
      expect(second.page, 1);
      expect(second.rows, hasLength(first.totalCount - 25));
    });

    test('sums the worked hours of the finished days', () async {
      await seedDoneDay(4, employeeId: EmployeeIds.julien, clockIn: (9, 0),
          clockOut: (17, 0));
      final data = await payroll.days(
        StoreIds.sablon,
        employeeId: EmployeeIds.julien,
        pageSize: 500,
      );
      expect(data.worked, greaterThanOrEqualTo(const Duration(hours: 8)));
    });
  });

  test('the seed has paid periods, each consistent with its days', () async {
    final periods = await db.select(db.payrollPeriods).get();
    expect(periods.where((p) => p.status == PayrollStatus.paid), isNotEmpty);

    for (final period in periods) {
      final covered = await (db.select(db.attendances)
            ..where((a) => a.payrollPeriodId.equals(period.id)))
          .get();
      expect(covered, isNotEmpty, reason: period.id);
    }
  });
}
