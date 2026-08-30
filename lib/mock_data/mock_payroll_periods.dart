import '../core/utils/payroll_math.dart';
import '../models/payroll_period.dart';
import 'mock_attendances.dart';
import 'mock_employees.dart';
import 'mock_reference.dart';
import 'mock_store_settings.dart';
import 'mock_stores.dart';

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
final List<PayrollPeriod> mockPayrollPeriods = [
  PayrollPeriod(
    id: PayrollPeriodIds.karimSeed,
    storeId: StoreIds.sablon,
    employeeId: EmployeeIds.karim,
    startDate: dayOnly(3),
    endDate: dayOnly(2),
    workedDays: 2,
    totalWorkedHours: 17.25,
    totalOvertimeHours: 0.25,
    appliedRate: 2400,
    computedAmount: 200.53,
    status: PayrollStatus.paid,
    paidByEmployeeId: EmployeeIds.marc,
    paidAt: daysAgo(1),
    createdAt: daysAgo(1),
  ),

  // TestCalcul — the first half of July, already paid. Figures are computed
  // from the very attendance rows the period locks, so the run and the
  // day-by-day paiement table agree.
  _testCalculPeriod(PayrollPeriodIds.testCalculAyoub, EmployeeIds.ayoub),
  _testCalculPeriod(PayrollPeriodIds.testCalculHakim, EmployeeIds.hakim),
];

PayrollPeriod _testCalculPeriod(String id, String employeeId) {
  final employee = mockEmployees.firstWhere((e) => e.id == employeeId);
  final settings = storeSettingsOrDefault(StoreIds.testCalcul);
  final days =
      mockAttendances.where((a) => a.payrollPeriodId == id).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  final totals = periodTotals(days, employee, settings);
  final paidAt = DateTime(2026, 7, 16);

  return PayrollPeriod(
    id: id,
    storeId: StoreIds.testCalcul,
    employeeId: employeeId,
    startDate: days.first.date,
    endDate: days.last.date,
    workedDays: totals.days,
    totalWorkedHours: totals.workedHours,
    totalOvertimeHours: totals.overtimeHours,
    appliedRate: employee.pay,
    computedAmount: periodAmount(days, employee, settings),
    status: PayrollStatus.paid,
    paidByEmployeeId: EmployeeIds.marc,
    paidAt: paidAt,
    createdAt: paidAt,
  );
}
