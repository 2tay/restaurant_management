/// Where one employee's working day stands.
enum AttendanceStatus {
  /// No row exists yet for the day — nothing to represent, so this value is
  /// never stored; it is what the absence of an [Attendance] means.
  notClockedIn,

  /// Clocked in, not on a break.
  working,

  /// Mid-break.
  onBreak,

  /// The day is finished.
  done,
}

/// Whether a day's hours have been settled by a payroll run.
enum PaymentStatus { unpaid, paid }

/// One break segment inside a day. There can be several — the button offers
/// `Pause` again after every `Reprendre`, up to `Fin de journée`.
class AttendancePause {
  const AttendancePause({required this.startAt, this.endAt});

  final DateTime startAt;

  /// Null while the break is still running.
  final DateTime? endAt;
}

/// One employee's attendance for one calendar day.
///
/// Created lazily on the first `Pointer` of the day — a day with no row
/// simply means not clocked in yet, which needs no row. One row per employee
/// per day: `(storeId, employeeId, date)` is unique.
///
/// Immutable, no logic — see `core/utils/attendance_status.dart` for the
/// durations derived from these timestamps. The pauses are embedded here
/// rather than a separate list, the same way `PurchaseOrder` embeds its
/// lines.
class Attendance {
  const Attendance({
    required this.id,
    required this.storeId,
    required this.employeeId,
    required this.date,
    required this.status,
    required this.pauses,
    required this.paymentStatus,
    this.clockInAt,
    this.clockOutAt,
    this.payrollPeriodId,
    this.scheduledStartMinutes,
    this.scheduledEndMinutes,
    this.maxBreakMinutes,
  });

  final String id;
  final String storeId;
  final String employeeId;

  /// Normalized to midnight — the work day this row is for, not when it was
  /// created.
  final DateTime date;

  final AttendanceStatus status;

  final DateTime? clockInAt;
  final DateTime? clockOutAt;

  /// Oldest first. Empty until the first `Pause`.
  final List<AttendancePause> pauses;

  final PaymentStatus paymentStatus;

  /// Set when a `PayrollPeriod` locks this day (Phase 5). While set, the day
  /// is immutable — `AttendanceMutations` refuses every write against it.
  final String? payrollPeriodId;

  /// The schedule and break allowance this day is judged against, frozen when
  /// the row was created so a later change to the store hours or this
  /// employee's schedule never rewrites what "en retard" / "heures supp." /
  /// "pause dépassée" meant for it. All in minutes since midnight, except
  /// [maxBreakMinutes] which is a duration.
  ///
  /// Null on rows from before schema v3 that predate the backfill, and
  /// whenever the writer could not resolve one — see
  /// `evaluationContext` in `core/utils/attendance_status.dart`, which falls
  /// back to the live resolved schedule.
  final int? scheduledStartMinutes;
  final int? scheduledEndMinutes;
  final int? maxBreakMinutes;
}
