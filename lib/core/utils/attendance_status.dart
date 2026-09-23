import '../../models/models.dart';

/// Constants the pointage rules are written against.
///
/// The break allowance is a per-store setting ([StoreSettings], edited on the
/// store settings screen) — this is only the default a brand-new store starts
/// from.
abstract final class AttendanceRules {
  /// A single break longer than this is flagged "pause dépassée".
  static const int defaultMaxBreakMinutes = 30;
}

/// Every pause across every session of the day, in session order.
Iterable<AttendancePause> _allPauses(Attendance entry) =>
    entry.sessions.expand((s) => s.pauses);

/// Total time spent on breaks across every session — only counts breaks that
/// have ended.
Duration totalBreak(Attendance entry) {
  var total = Duration.zero;
  for (final pause in _allPauses(entry)) {
    final end = pause.endAt;
    if (end == null) continue;
    total += end.difference(pause.startAt);
  }
  return total;
}

/// The number of pauses taken across every session of the day.
int totalPauseCount(Attendance entry) => _allPauses(entry).length;

/// Whether a break is currently open (the employee is `onBreak`).
bool hasOpenBreak(Attendance entry) =>
    _allPauses(entry).any((p) => p.endAt == null);

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
bool hasLateBreak(Attendance entry, int maxBreakMinutes) => _allPauses(
  entry,
).any((p) => breakOverrun(p, maxBreakMinutes) > Duration.zero);

/// Total time all breaks together ran past the allowance — for the history
/// and payroll figures.
Duration totalBreakOverrun(Attendance entry, int maxBreakMinutes) {
  var total = Duration.zero;
  for (final pause in _allPauses(entry)) {
    total += breakOverrun(pause, maxBreakMinutes);
  }
  return total;
}

/// Hours actually worked across every **finished** session, excluding every
/// break. Null while none has finished yet; a currently open session (if any)
/// does not count until it closes. Floored at zero rather than going
/// negative.
Duration? workedDuration(Attendance entry) {
  final closed = entry.sessions.where((s) => s.clockOutAt != null);
  if (closed.isEmpty) return null;

  var total = Duration.zero;
  for (final session in closed) {
    var sessionBreak = Duration.zero;
    for (final pause in session.pauses) {
      final end = pause.endAt;
      if (end == null) continue;
      sessionBreak += end.difference(pause.startAt);
    }
    final worked = session.clockOutAt!.difference(session.clockInAt) - sessionBreak;
    total += worked.isNegative ? Duration.zero : worked;
  }
  return total;
}

/// The break allowance one [entry] is judged against — `pause dépassée`
/// measures against this.
///
/// Prefers the value frozen on the row when it was created — so a later
/// change to the store's setting cannot rewrite a past day's figure. Falls
/// back to the caller-supplied live value for a row from before schema v3, or
/// one the writer could not stamp: pass the store's live `maxBreakMinutes`.
int resolvedMaxBreakMinutes(Attendance entry, {required int fallback}) =>
    entry.maxBreakMinutes ?? fallback;

/// A real attendance anomaly — something a manager should look at.
enum AttendanceAnomaly {
  /// One break ran past the store's allowance.
  pauseDepassee,

  /// A day in the past is still open — clocked in and never clocked out.
  oubliDePointage,
}

DateTime _dayOnly(DateTime v) => DateTime(v.year, v.month, v.day);

/// The anomalies of one day, in display order. Purely derived from the
/// existing rules ([hasLateBreak], the clock timestamps) — no new state, no
/// "absent" concept.
///
/// [now] defaults to the wall clock; a test pins it. A day that is still today
/// and legitimately open (someone is working) is not [oubliDePointage].
List<AttendanceAnomaly> attendanceAnomalies(
  Attendance entry, {
  required int maxBreakMinutes,
  DateTime? now,
}) {
  final result = <AttendanceAnomaly>[];
  if (hasLateBreak(entry, maxBreakMinutes)) {
    result.add(AttendanceAnomaly.pauseDepassee);
  }
  final today = _dayOnly(now ?? DateTime.now());
  final last = entry.sessions.lastOrNull;
  if (last != null &&
      last.clockOutAt == null &&
      _dayOnly(entry.date).isBefore(today)) {
    result.add(AttendanceAnomaly.oubliDePointage);
  }
  return result;
}
