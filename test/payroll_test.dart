// The payroll rules — the maths, the "Payer" lock, and the permanence of a
// paid period. Styled like orders_test.dart: this is the part of the phase
// with actual behaviour, run against the in-memory layer.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/core/utils/payroll_math.dart';
import 'package:stock_inventory/mock_data/mock_data.dart';
import 'package:stock_inventory/models/models.dart';

import 'support/mock_reset.dart';

Attendance _day(
  int daysAgoValue, {
  required String employeeId,
  required (int, int) clockIn,
  required (int, int) clockOut,
  PaymentStatus payment = PaymentStatus.unpaid,
}) {
  final date = DateTime.now().subtract(Duration(days: daysAgoValue));
  final d = DateTime(date.year, date.month, date.day);
  return Attendance(
    id: 'pay-test-$employeeId-$daysAgoValue',
    storeId: StoreIds.sablon,
    employeeId: employeeId,
    date: d,
    status: AttendanceStatus.done,
    clockInAt: DateTime(d.year, d.month, d.day, clockIn.$1, clockIn.$2),
    clockOutAt: DateTime(d.year, d.month, d.day, clockOut.$1, clockOut.$2),
    pauses: const [],
    paymentStatus: payment,
  );
}

void main() {
  setUp(restoreMockData);

  group('the maths', () {
    test('an extra is paid their hourly rate; a fixed employee a derived one',
        () {
      final settings = MockQueries.storeSettings(StoreIds.sablon);
      final julien = MockQueries.employeeById(EmployeeIds.julien)!; // extra, 13 €/h
      final karim = MockQueries.employeeById(EmployeeIds.karim)!; // fixed, 2400

      expect(hourlyRate(julien, settings), 13);

      // 2400 / 26 working days / 8h ≈ 11.54 €/h.
      expect(
        hourlyRate(karim, settings),
        closeTo(2400 / 26 / 8, 0.001),
      );
    });

    test('overtime hours carry the multiplier premium', () {
      final settings = MockQueries.storeSettings(StoreIds.sablon);
      final julien = MockQueries.employeeById(EmployeeIds.julien)!;
      // Sablon closes at 17:00; Noah has no personal schedule.
      final day = _day(
        1,
        employeeId: EmployeeIds.julien,
        clockIn: const (9, 0),
        clockOut: const (18, 0), // 1h overtime
      );

      // 9h worked, 1h of it overtime. Base 9×13 + premium (1.5−1)×13×1.
      final expected = 9 * 13 + (settings.overtimeMultiplier - 1) * 13;
      expect(
        dayAmount(day, julien, settings, scheduledEndMinutes: 17 * 60),
        closeTo(expected, 0.001),
      );
    });

    test('a day that is not done is worth nothing', () {
      final settings = MockQueries.storeSettings(StoreIds.sablon);
      final julien = MockQueries.employeeById(EmployeeIds.julien)!;
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
    test('sums the unpaid finished days and stores nothing', () {
      mockAttendances.addAll([
        _day(4, employeeId: EmployeeIds.julien, clockIn: (9, 0), clockOut: (15, 0)),
        _day(5, employeeId: EmployeeIds.julien, clockIn: (9, 0), clockOut: (16, 0)),
      ]);

      final periodsBefore = mockPayrollPeriods.length;
      final preview = PayrollMutations.preview(
        EmployeeIds.julien,
        StoreIds.sablon,
      );

      expect(preview.days, hasLength(2));
      expect(preview.amount, greaterThan(0));
      expect(mockPayrollPeriods.length, periodsBefore);
      expect(
        MockQueries.attendanceById('pay-test-employee-julien-4')!.paymentStatus,
        PaymentStatus.unpaid,
      );
    });

    test('is empty when everything owed is already paid', () {
      // Marc has no attendance rows at all.
      final preview = PayrollMutations.preview(
        EmployeeIds.marc,
        StoreIds.sablon,
      );
      expect(preview.isEmpty, isTrue);
      expect(preview.amount, 0);
    });
  });

  group('pay', () {
    test('creates the period, locks every covered day, freezes the rate', () {
      mockAttendances.addAll([
        _day(4, employeeId: EmployeeIds.julien, clockIn: (9, 0), clockOut: (15, 0)),
        _day(5, employeeId: EmployeeIds.julien, clockIn: (9, 0), clockOut: (16, 0)),
      ]);
      final owed = PayrollMutations.preview(
        EmployeeIds.julien,
        StoreIds.sablon,
      ).amount;

      final period = PayrollMutations.pay(
        EmployeeIds.julien,
        StoreIds.sablon,
        paidByEmployeeId: EmployeeIds.marc,
      )!;

      expect(period.status, PayrollStatus.paid);
      expect(period.computedAmount, closeTo(owed, 0.001));
      expect(period.appliedRate, 13);
      expect(period.workedDays, 2);

      for (final id in ['pay-test-employee-julien-4', 'pay-test-employee-julien-5']) {
        final day = MockQueries.attendanceById(id)!;
        expect(day.paymentStatus, PaymentStatus.paid);
        expect(day.payrollPeriodId, period.id);
      }

      // Nothing left owed.
      expect(
        PayrollMutations.preview(EmployeeIds.julien, StoreIds.sablon).isEmpty,
        isTrue,
      );
    });

    test('a later raise does not move a period already paid', () {
      mockAttendances.add(
        _day(4, employeeId: EmployeeIds.julien, clockIn: (9, 0), clockOut: (15, 0)),
      );
      final period = PayrollMutations.pay(
        EmployeeIds.julien,
        StoreIds.sablon,
        paidByEmployeeId: EmployeeIds.marc,
      )!;
      final frozen = period.computedAmount;

      EmployeeMutations.update(EmployeeIds.julien, pay: 99);

      expect(
        MockQueries.payrollPeriodById(period.id)!.computedAmount,
        frozen,
      );
      expect(MockQueries.payrollPeriodById(period.id)!.appliedRate, 13);
    });

    test('a day locked by a payment refuses every attendance write', () {
      mockAttendances.add(
        _day(4, employeeId: EmployeeIds.julien, clockIn: (9, 0), clockOut: (15, 0)),
      );
      PayrollMutations.pay(
        EmployeeIds.julien,
        StoreIds.sablon,
        paidByEmployeeId: EmployeeIds.marc,
      );

      const id = 'pay-test-employee-julien-4';
      expect(AttendanceMutations.startPause(id), isNull);
      expect(AttendanceMutations.clockOut(id), isNull);
    });

    test('paying when nothing is owed returns null', () {
      expect(
        PayrollMutations.pay(
          EmployeeIds.marc,
          StoreIds.sablon,
          paidByEmployeeId: EmployeeIds.marc,
        ),
        isNull,
      );
    });
  });

  test('the seed has one paid period, consistent with its days', () {
    expect(
      mockPayrollPeriods.where((p) => p.status == PayrollStatus.paid),
      isNotEmpty,
    );
    for (final period in mockPayrollPeriods) {
      final covered = mockAttendances.where(
        (a) => a.payrollPeriodId == period.id,
      );
      expect(covered, isNotEmpty, reason: period.id);
      expect(
        covered.every((a) => a.paymentStatus == PaymentStatus.paid),
        isTrue,
      );
    }
  });

  test('reset restores both mockPayrollPeriods and the day locks', () {
    mockAttendances.add(
      _day(4, employeeId: EmployeeIds.julien, clockIn: (9, 0), clockOut: (15, 0)),
    );
    final before = mockPayrollPeriods.length;
    PayrollMutations.pay(
      EmployeeIds.julien,
      StoreIds.sablon,
      paidByEmployeeId: EmployeeIds.marc,
    );
    expect(mockPayrollPeriods.length, before + 1);

    MockWrite.reset();
    expect(mockPayrollPeriods.length, before);
  });
}
