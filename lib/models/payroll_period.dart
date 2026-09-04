/// Where a payroll run stands.
enum PayrollStatus {
  /// Figured but not yet validated — never actually persisted in this phase
  /// (the preview is not stored), kept for Phase 2's storage layer.
  computed,

  /// Paid. The covered attendance days are locked.
  paid,
}

/// One payroll run for one employee — the days it covered, the figures it was
/// computed from, and the amount, frozen at the moment "Payer" was tapped.
///
/// Immutable, no logic — same contract as every other model. Same permanence
/// as a confirmed goods receipt: once `paid`, it is never edited or deleted,
/// and the days it covers can no longer be touched by `AttendanceMutations`.
/// A later change to the employee's pay rate does not move a paid period —
/// that is what [appliedRate] captures.
class PayrollPeriod {
  const PayrollPeriod({
    required this.id,
    required this.storeId,
    required this.employeeId,
    required this.startDate,
    required this.endDate,
    required this.workedDays,
    required this.totalWorkedHours,
    required this.totalOvertimeHours,
    required this.appliedRate,
    required this.computedAmount,
    required this.status,
    required this.createdAt,
    this.paidByEmployeeId,
    this.paidAt,
  });

  final String id;
  final String storeId;
  final String employeeId;

  /// The first and last work day this run covered (midnight-normalised).
  final DateTime startDate;
  final DateTime endDate;

  final int workedDays;
  final double totalWorkedHours;
  final double totalOvertimeHours;

  /// Snapshot of the employee's pay (monthly € for a fixed contract, €/h for
  /// an extra) at pay time — so a later raise cannot rewrite history.
  final double appliedRate;

  final double computedAmount;

  final PayrollStatus status;

  /// The owner who validated the run.
  final String? paidByEmployeeId;
  final DateTime? paidAt;

  final DateTime createdAt;
}
