import '../../../core/utils/payroll_math.dart';
import '../../../models/payroll_period.dart';
import 'attendances.dart';
import 'employees.dart';
import 'reference.dart';
import 'stores.dart';

abstract final class PayrollPeriodIds {
  /// Must match the `payrollPeriodId` on Karim's two paid attendance rows in
  /// `mock_attendances.dart`.
  static const String karimSeed = 'payroll-seed-karim';

  /// The two TestCalcul runs — must match the `payrollPeriodId` on that store's
  /// paid attendance rows (1–15 July 2026).
  static const String testCalculAyoub = 'payroll-testcalcul-ayoub';
  static const String testCalculHakim = 'payroll-testcalcul-hakim';
}

/// One paid payroll run in the seed, so the history list has a real row and
/// the "a paid day is locked" rule is demoable rather than described.
///
/// Marc (the owner) paid Karim for his two finished days, three and two days
/// ago — those rows carry `paymentStatus: paid` and this id.
///
/// Every run's figures are computed from the very attendance rows it locks, at
/// the employee's seeded rate — so the run, the frozen rate the paiement
/// drawer shows, and the day-by-day table all agree.
final List<PayrollPeriod> mockPayrollPeriods = [
  _seedPeriod(
    PayrollPeriodIds.karimSeed,
    EmployeeIds.karim,
    StoreIds.sablon,
    paidAt: daysAgo(1),
  ),

  // TestCalcul — the first half of July, already paid.
  _seedPeriod(
    PayrollPeriodIds.testCalculAyoub,
    EmployeeIds.ayoub,
    StoreIds.testCalcul,
    paidAt: DateTime(2026, 7, 16),
  ),
  _seedPeriod(
    PayrollPeriodIds.testCalculHakim,
    EmployeeIds.hakim,
    StoreIds.testCalcul,
    paidAt: DateTime(2026, 7, 16),
  ),
];

PayrollPeriod _seedPeriod(
  String id,
  String employeeId,
  String storeId, {
  required DateTime paidAt,
}) {
  final employee = mockEmployees.firstWhere((e) => e.id == employeeId);
  final days =
      mockAttendances.where((a) => a.payrollPeriodId == id).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  final totals = periodTotals(days);

  return PayrollPeriod(
    id: id,
    storeId: storeId,
    employeeId: employeeId,
    startDate: days.first.date,
    endDate: days.last.date,
    workedDays: totals.days,
    totalWorkedHours: totals.workedHours,
    appliedRate: employee.pay,
    computedAmount: periodAmount(days, employee),
    status: PayrollStatus.paid,
    paidByEmployeeId: EmployeeIds.marc,
    paidAt: paidAt,
    createdAt: paidAt,
  );
}
