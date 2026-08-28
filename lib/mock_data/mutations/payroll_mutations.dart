import '../../core/utils/payroll_math.dart';
import '../../models/models.dart';
import '../mock_payroll_periods.dart';
import '../mock_queries.dart';
import 'attendance_mutations.dart';
import 'mock_write.dart';

/// What [PayrollMutations.preview] hands the screen — figured, never stored.
class PayrollPreview {
  const PayrollPreview({
    required this.days,
    required this.workedHours,
    required this.overtimeHours,
    required this.amount,
    required this.appliedRate,
  });

  /// The unpaid, finished days this run would cover, most recent first.
  final List<Attendance> days;
  final double workedHours;
  final double overtimeHours;
  final double amount;
  final double appliedRate;

  bool get isEmpty => days.isEmpty;
}

/// Writes against payroll — the compute-and-pay flow.
///
/// **The only file that writes a [PayrollPeriod], and the only path that ever
/// flips an [Attendance] to `paid`** (via `AttendanceMutations.lockForPayroll`).
/// Same split and same permanence as goods receipts: a paid period is never
/// edited or deleted, [PayrollPeriod.appliedRate] freezes the rate at pay
/// time, and the days it covers can no longer be touched.
abstract final class PayrollMutations {
  /// Everything owed to [employeeId] at [storeId] right now: their unpaid,
  /// finished days and what those come to. Persists nothing — this is the
  /// "before you confirm" view, like a goods-receipt draft.
  ///
  /// [from] / [to] bound it to the date range the history screen is showing —
  /// a day outside that range stays owed until the range is widened. Days
  /// before the employee's hire date are never included, whatever [from] says.
  static PayrollPreview preview(
    String employeeId,
    String storeId, {
    DateTime? from,
    DateTime? to,
  }) {
    final employee = MockQueries.employeeById(employeeId);
    final settings = MockQueries.storeSettings(storeId);
    final days = _payableDays(employeeId, storeId, from: from, to: to);

    if (employee == null || days.isEmpty) {
      return PayrollPreview(
        days: days,
        workedHours: 0,
        overtimeHours: 0,
        amount: 0,
        appliedRate: employee?.pay ?? 0,
      );
    }

    final totals = periodTotals(days, employee, settings);
    return PayrollPreview(
      days: days,
      workedHours: totals.workedHours,
      overtimeHours: totals.overtimeHours,
      amount: periodAmount(days, employee, settings),
      appliedRate: employee.pay,
    );
  }

  /// Pays everything [preview] would show for the same [from] / [to] range —
  /// creates the [PayrollPeriod] and locks its days in one atomic write.
  /// Returns null when there is nothing to pay, the employee is missing, or a
  /// day slipped into `paid` between the preview and here.
  static PayrollPeriod? pay(
    String employeeId,
    String storeId, {
    DateTime? from,
    DateTime? to,
    required String paidByEmployeeId,
    DateTime? now,
  }) {
    final employee = MockQueries.employeeById(employeeId);
    if (employee == null) return null;

    final days = _payableDays(employeeId, storeId, from: from, to: to);
    if (days.isEmpty) return null;

    final settings = MockQueries.storeSettings(storeId);
    final totals = periodTotals(days, employee, settings);
    final dates = days.map((d) => d.date).toList()..sort();
    final at = now ?? DateTime.now();
    final id = MockWrite.id('payroll');

    final locked = AttendanceMutations.lockForPayroll(
      days.map((d) => d.id),
      id,
    );
    if (!locked) return null;

    final period = PayrollPeriod(
      id: id,
      storeId: storeId,
      employeeId: employeeId,
      startDate: dates.first,
      endDate: dates.last,
      workedDays: totals.days,
      totalWorkedHours: totals.workedHours,
      totalOvertimeHours: totals.overtimeHours,
      appliedRate: employee.pay,
      computedAmount: periodAmount(days, employee, settings),
      status: PayrollStatus.paid,
      paidByEmployeeId: paidByEmployeeId,
      paidAt: at,
      createdAt: at,
    );

    mockPayrollPeriods.add(period);
    MockWrite.changed();
    return period;
  }

  /// Unpaid, finished days for this employee at this store — most recent
  /// first. A day that is not `done` is not payable yet. [from] / [to] bound
  /// the range (inclusive, calendar days); the lower bound is never earlier
  /// than the employee's hire date.
  static List<Attendance> _payableDays(
    String employeeId,
    String storeId, {
    DateTime? from,
    DateTime? to,
  }) {
    final employee = MockQueries.employeeById(employeeId);
    final lower = _laterOf(
      from == null ? null : _dayOnly(from),
      employee == null ? null : _dayOnly(employee.hireDate),
    );
    final upper = to == null ? null : _dayOnly(to);

    final days =
        MockQueries.attendancesForEmployee(employeeId)
            .where(
              (a) =>
                  a.storeId == storeId &&
                  a.status == AttendanceStatus.done &&
                  a.paymentStatus == PaymentStatus.unpaid &&
                  (lower == null || !a.date.isBefore(lower)) &&
                  (upper == null || !a.date.isAfter(upper)),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return days;
  }

  static DateTime _dayOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime? _laterOf(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }
}
