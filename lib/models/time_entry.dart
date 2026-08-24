/// Where one employee's working day stands.
enum TimeEntryStatus {
  /// No entry exists yet for the day — nothing to represent, so this value is
  /// never actually stored; it is what the absence of a [TimeEntry] means.
  notClockedIn,

  /// Clocked in, not on a break.
  onShift,

  /// Mid-break.
  onBreak,

  /// The day is finished.
  clockedOut,
}

/// One employee's attendance for one calendar day.
///
/// Created lazily on the first *Pointer* tap of the day — there is no
/// "opening balance" row the way `StockMovement` needs one, because a day
/// with no entry simply means not clocked in yet, which is representable
/// without a row. One entry per employee per day, and one break per day: the
/// button offers `Pointer` → `Pause` → `Reprendre` → `Fin de journée`, never a
/// second `Pause` after `Reprendre`.
///
/// Immutable, no logic — see `core/utils/timeclock_status.dart` for the
/// durations derived from these timestamps.
class TimeEntry {
  const TimeEntry({
    required this.id,
    required this.storeId,
    required this.employeeId,
    required this.date,
    required this.status,
    required this.isLate,
    this.clockInAt,
    this.breakStartAt,
    this.breakEndAt,
    this.clockOutAt,
  });

  final String id;
  final String storeId;
  final String employeeId;

  /// Normalized to midnight — the work day this entry is for, not when it was
  /// created.
  final DateTime date;

  final TimeEntryStatus status;

  final DateTime? clockInAt;
  final DateTime? breakStartAt;
  final DateTime? breakEndAt;
  final DateTime? clockOutAt;

  /// True when the break ran longer than `PointageRules.maxBreakDuration`.
  /// Set once, at `Reprendre`, and never recomputed afterwards.
  final bool isLate;
}
