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

/// One break segment inside a session. There can be several — the button
/// offers `Pause` again after every `Reprendre`, up to `Fin de journée`.
class AttendancePause {
  const AttendancePause({required this.startAt, this.endAt});

  final DateTime startAt;

  /// Null while the break is still running.
  final DateTime? endAt;
}

/// One Pointer → Fin de journée cycle inside a day. There can be several — an
/// employee may clock out for a few hours and come back the same day, so a
/// day is a list of these rather than a single clock-in/clock-out pair.
class AttendanceSession {
  const AttendanceSession({
    required this.clockInAt,
    this.clockOutAt,
    this.pauses = const [],
  });

  final DateTime clockInAt;

  /// Null while this cycle is still running.
  final DateTime? clockOutAt;

  /// Oldest first. Empty until the first `Pause` of this cycle.
  final List<AttendancePause> pauses;
}

/// One employee's attendance for one calendar day.
///
/// Created lazily on the first `Pointer` of the day — a day with no row
/// simply means not clocked in yet, which needs no row. One row per employee
/// per day: `(storeId, employeeId, date)` is unique — but that one row can
/// hold several [sessions], since an employee may clock in, clock out for a
/// few hours, and clock back in the same day.
///
/// Immutable, no logic — see `core/utils/attendance_status.dart` for the
/// durations derived from these timestamps. The sessions are embedded here
/// rather than a separate list, the same way `PurchaseOrder` embeds its
/// lines.
class Attendance {
  const Attendance({
    required this.id,
    required this.storeId,
    required this.employeeId,
    required this.date,
    required this.status,
    required this.sessions,
    required this.paymentStatus,
    this.payrollPeriodId,
    this.maxBreakMinutes,
  });

  final String id;
  final String storeId;
  final String employeeId;

  /// Normalized to midnight — the work day this row is for, not when it was
  /// created.
  final DateTime date;

  final AttendanceStatus status;

  /// Oldest first. Empty means not clocked in yet today.
  final List<AttendanceSession> sessions;

  final PaymentStatus paymentStatus;

  /// Set when a `PayrollPeriod` locks this day (Phase 5). While set, the day
  /// is immutable — `AttendanceMutations` refuses every write against it.
  final String? payrollPeriodId;

  /// The break allowance this day is judged against, frozen when the row was
  /// created so a later change to the store's setting never rewrites what
  /// "pause dépassée" meant for it.
  ///
  /// Null on rows from before schema v3 that predate the backfill, and
  /// whenever the writer could not resolve one — callers fall back to the
  /// store's live `maxBreakMinutes`.
  final int? maxBreakMinutes;
}
