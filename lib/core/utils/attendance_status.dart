import '../../models/models.dart';

/// Constants the pointage rules are written against.
///
/// The opening hours and the break allowance are a per-store setting
/// ([StoreSettings], edited on the store settings screen) — these are only
/// the defaults a brand-new store starts from. `standardWorkDay` is the
/// baseline Phase 5's payroll measures a fixed-salary day against.
abstract final class AttendanceRules {
  /// 08:00, in minutes since midnight.
  static const int defaultOpenMinutes = 8 * 60;

  /// 17:00, in minutes since midnight.
  static const int defaultCloseMinutes = 17 * 60;

  /// A single break longer than this is flagged "pause dépassée".
  static const int defaultMaxBreakMinutes = 30;

  /// Arriving within this of the scheduled start is not counted as late.
  static const Duration lateGrace = Duration(minutes: 5);

  /// A full working day, for the fixed-salary daily-rate maths in Phase 5.
  static const Duration standardWorkDay = Duration(hours: 8);
}

/// Total time spent on breaks — only counts breaks that have ended.
Duration totalBreak(Attendance entry) {
  var total = Duration.zero;
  for (final pause in entry.pauses) {
    final end = pause.endAt;
    if (end == null) continue;
    total += end.difference(pause.startAt);
  }
  return total;
}

/// Whether a break is currently open (the employee is `onBreak`).
bool hasOpenBreak(Attendance entry) => entry.pauses.any((p) => p.endAt == null);

/// How far a single **ended** break ran past [maxBreakMinutes]. Zero while it
/// is within the allowance or still running.
Duration breakOverrun(AttendancePause pause, int maxBreakMinutes) {
  final end = pause.endAt;
  if (end == null) return Duration.zero;
  final over =
      end.difference(pause.startAt) - Duration(minutes: maxBreakMinutes);
  return over.isNegative ? Duration.zero : over;
}

/// True when any one break segment ran past the store's allowance — the
/// single place the "pause dépassée" mark is decided.
bool hasLateBreak(Attendance entry, int maxBreakMinutes) => entry.pauses.any(
  (p) => breakOverrun(p, maxBreakMinutes) > Duration.zero,
);

/// Total time all breaks together ran past the allowance — for the history
/// and payroll figures.
Duration totalBreakOverrun(Attendance entry, int maxBreakMinutes) {
  var total = Duration.zero;
  for (final pause in entry.pauses) {
    total += breakOverrun(pause, maxBreakMinutes);
  }
  return total;
}

/// Hours actually worked, excluding every break. Null until [clockOutAt] is
/// set; floored at zero rather than going negative.
Duration? workedDuration(Attendance entry) {
  final clockIn = entry.clockInAt;
  final clockOut = entry.clockOutAt;
  if (clockIn == null || clockOut == null) return null;

  final worked = clockOut.difference(clockIn) - totalBreak(entry);
  return worked.isNegative ? Duration.zero : worked;
}

/// The start / end of day this employee is measured against — their own
/// override, or the store's opening hours. Both in minutes since midnight.
({int startMinutes, int endMinutes}) resolvedSchedule(
  Employee employee, {
  required int storeOpenMinutes,
  required int storeCloseMinutes,
}) => (
  startMinutes: employee.scheduledStartMinutes ?? storeOpenMinutes,
  endMinutes: employee.scheduledEndMinutes ?? storeCloseMinutes,
);

int _minutesOfDay(DateTime at) => at.hour * 60 + at.minute;

/// How late the arrival was against [scheduledStartMinutes], past the grace
/// window. Null until clocked in; zero when on time or early.
Duration? lateBy(Attendance entry, int scheduledStartMinutes) {
  final clockIn = entry.clockInAt;
  if (clockIn == null) return null;

  final lateMinutes = _minutesOfDay(clockIn) - scheduledStartMinutes;
  final over = Duration(minutes: lateMinutes) - AttendanceRules.lateGrace;
  return over.isNegative ? Duration.zero : over;
}

/// True once the arrival is late enough to flag — the single place the "en
/// retard" mark is decided.
bool isLate(Attendance entry, int scheduledStartMinutes) =>
    (lateBy(entry, scheduledStartMinutes) ?? Duration.zero) > Duration.zero;

/// How far past [scheduledEndMinutes] the employee clocked out. Null until
/// clocked out; zero when they left on time or early.
Duration? overtimeBy(Attendance entry, int scheduledEndMinutes) {
  final clockOut = entry.clockOutAt;
  if (clockOut == null) return null;

  final overMinutes = _minutesOfDay(clockOut) - scheduledEndMinutes;
  final over = Duration(minutes: overMinutes);
  return over.isNegative ? Duration.zero : over;
}
