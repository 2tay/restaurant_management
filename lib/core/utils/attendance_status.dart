import 'package:clock/clock.dart';

import '../../models/models.dart';
import 'dates.dart';

/// Constants the pointage rules are written against.
///
/// The break allowance is a per-store setting ([StoreSettings], edited on the
/// store settings screen) — this is only the default a brand-new store starts
/// from.
abstract final class AttendanceRules {
  /// A single break longer than this is flagged "pause dépassée".
  static const int defaultMaxBreakMinutes = 30;

  /// A journée de service open this long is flagged on the board: somebody
  /// most likely forgot to close it, and every Pointer keeps landing on it.
  /// Nothing closes it on its own — that would invent exit times.
  static const Duration businessDayAlertAfter = Duration(hours: 18);

  /// Before this time of day (minutes after midnight) a Pointer does **not**
  /// open a journée by itself: a punch in the night, after the evening's
  /// journée was closed, would otherwise open (and could get closed) the next
  /// day's only journée. "Ouvrir la journée" on the board still opens one on
  /// purpose. The default for a new store — each store sets its own
  /// (`StoreSettings.businessDayAutoOpenMinutes`); 05:00.
  static const int defaultBusinessDayAutoOpenMinutes = 5 * 60;

  /// The last settable minute of the day, 23:59.
  static const int lastMinuteOfDay = 24 * 60 - 1;
}

/// From when, on [day], a Pointer opens the journée by itself — [minutes]
/// after midnight (the store's `businessDayAutoOpenMinutes`).
DateTime businessDayAutoOpenAt(DateTime day, int minutes) =>
    DateTime(day.year, day.month, day.day, 0, minutes);

/// When the board starts flagging [day] as left open —
/// [AttendanceRules.businessDayAlertAfter] after it opened.
DateTime businessDayAlertAt(BusinessDay day) =>
    day.openedAt.add(AttendanceRules.businessDayAlertAfter);

/// [session]'s pauses as they count: one never ended stops at the
/// session's exit, once there is one (SYNC_PERSONNEL_PLAN.md, rule P3 — a
/// pause on one tablet, the exit on another). Still open while the session
/// is.
Iterable<AttendancePause> pausesOf(AttendanceSession session) =>
    session.pauses.map(
      (p) => p.endAt != null || session.clockOutAt == null
          ? p
          : AttendancePause(startAt: p.startAt, endAt: session.clockOutAt),
    );

/// Every pause across every session of the day, in session order.
Iterable<AttendancePause> _allPauses(Attendance entry) =>
    entry.sessions.expand(pausesOf);

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
    for (final pause in pausesOf(session)) {
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
/// back to the caller-supplied live value for a row from before schema v4, or
/// one the writer could not stamp: pass the store's live `maxBreakMinutes`.
int resolvedMaxBreakMinutes(Attendance entry, {required int fallback}) =>
    entry.maxBreakMinutes ?? fallback;

/// A real attendance anomaly — something a manager should look at.
enum AttendanceAnomaly {
  /// One break ran past the store's allowance.
  pauseDepassee,

  /// A day in the past is still open — clocked in and never clocked out —
  /// and it is not the journée de service still running past midnight.
  oubliDePointage,

  /// Two sessions of the day overlap in time. One tablet cannot do that; two
  /// tablets clocking the same person in offline can, and sync merges their
  /// days into one without trimming anything (SYNC_PLAN.md, Phase 7). A
  /// manager decides which hours count.
  doublePointage,
}

/// Whether two sessions of [entry] overlap: one starts before the other
/// ends, or while the other is still open.
bool hasOverlappingSessions(Attendance entry) {
  final sessions = [...entry.sessions]
    ..sort((a, b) => a.clockInAt.compareTo(b.clockInAt));
  for (var i = 1; i < sessions.length; i++) {
    final previousEnd = sessions[i - 1].clockOutAt;
    if (previousEnd == null || sessions[i].clockInAt.isBefore(previousEnd)) {
      return true;
    }
  }
  return false;
}

/// The anomalies of one day, in display order. Purely derived from the
/// existing rules ([hasLateBreak], the clock timestamps) — no new state, no
/// "absent" concept.
///
/// [now] defaults to the wall clock; a test pins it. A day that is still today
/// and legitimately open (someone is working) is not [oubliDePointage], and
/// neither is a day of [openBusinessDay] — the date of the journée de service
/// still open, which runs past midnight: at 00:30 an evening shift begun
/// yesterday is still in service, not forgotten.
List<AttendanceAnomaly> attendanceAnomalies(
  Attendance entry, {
  required int maxBreakMinutes,
  DateTime? now,
  DateTime? openBusinessDay,
}) {
  final result = <AttendanceAnomaly>[];
  if (hasLateBreak(entry, maxBreakMinutes)) {
    result.add(AttendanceAnomaly.pauseDepassee);
  }
  final today = dayOf(now ?? clock.now());
  final last = entry.sessions.lastOrNull;
  final inOpenJournee =
      openBusinessDay != null &&
      dayOf(entry.date) == dayOf(openBusinessDay);
  if (last != null &&
      last.clockOutAt == null &&
      !inOpenJournee &&
      dayOf(entry.date).isBefore(today)) {
    result.add(AttendanceAnomaly.oubliDePointage);
  }
  if (hasOverlappingSessions(entry)) {
    result.add(AttendanceAnomaly.doublePointage);
  }
  return result;
}
