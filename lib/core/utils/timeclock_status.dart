import '../../models/time_entry.dart';

/// Constants the pointage rules are written against.
///
/// Store-wide for now rather than per-employee — see the brief's assumption
/// 3 and 8. `stalePartialOrderDays` is the precedent for promoting a constant
/// like this to a per-store setting later, if it turns out to be wanted.
abstract final class PointageRules {
  /// A break longer than this is flagged `isLate` when it ends.
  static const Duration maxBreakDuration = Duration(minutes: 30);

  /// The baseline "Heures supplémentaires" is measured against.
  static const Duration standardWorkDayDuration = Duration(hours: 8);
}

/// How long the break lasted. Null until `breakEndAt` is set.
Duration? breakDuration(TimeEntry entry) {
  final start = entry.breakStartAt;
  final end = entry.breakEndAt;
  if (start == null || end == null) return null;
  return end.difference(start);
}

/// How long was actually worked, excluding the break. Null until
/// `clockOutAt` is set.
Duration? workedDuration(TimeEntry entry) {
  final clockIn = entry.clockInAt;
  final clockOut = entry.clockOutAt;
  if (clockIn == null || clockOut == null) return null;

  final total = clockOut.difference(clockIn);
  final onBreak = breakDuration(entry) ?? Duration.zero;
  final worked = total - onBreak;
  return worked.isNegative ? Duration.zero : worked;
}

/// How far worked time ran past the standard work day. Null until worked
/// duration is known, floored at zero rather than going negative for a short
/// day.
Duration? overtime(TimeEntry entry) {
  final worked = workedDuration(entry);
  if (worked == null) return null;

  final over = worked - PointageRules.standardWorkDayDuration;
  return over.isNegative ? Duration.zero : over;
}
