import '../models/payroll_period.dart';
import 'mock_employees.dart';
import 'mock_reference.dart';
import 'mock_stores.dart';

abstract final class PayrollPeriodIds {
  /// Must match the `payrollPeriodId` on Karim's two paid attendance rows in
  /// `mock_attendances.dart`.
  static const String karimSeed = 'payroll-seed-karim';
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
];
