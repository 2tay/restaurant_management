import '../../core/utils/timeclock_status.dart';
import '../../models/models.dart';
import '../mock_queries.dart';
import '../mock_reference.dart';
import '../mock_time_entries.dart';
import 'mock_write.dart';

/// Writes against the pointage — clock-in, break start, break end, clock-out.
///
/// **The only file that writes a [TimeEntry].** Same split as
/// `movement_mutations.dart` owning an item's quantity: `EmployeeMutations`
/// owns the personnel record, this file alone owns the attendance trail, so
/// the two can never disagree about who touched what.
///
/// Every method refuses the wrong prior state rather than coercing it, the
/// same defensive posture `OrderMutations` takes with a sent order or a
/// partial receipt — a card that got out of sync with what actually happened
/// on the floor is worse than a tap that silently does nothing.
abstract final class TimeclockMutations {
  /// `Pointer`. Refuses if today's entry already exists for this employee —
  /// one [TimeEntry] per employee per calendar day.
  ///
  /// [now] defaults to the real clock; tests pass an explicit value so a
  /// break's duration can be pinned instead of depending on wall-clock time
  /// actually passing between two calls.
  static TimeEntry? clockIn(
    String employeeId,
    String storeId, {
    DateTime? now,
  }) {
    if (MockQueries.timeEntryForToday(employeeId) != null) return null;

    final entry = TimeEntry(
      id: MockWrite.id('te'),
      storeId: storeId,
      employeeId: employeeId,
      date: dayOnly(0),
      status: TimeEntryStatus.onShift,
      clockInAt: now ?? DateTime.now(),
      isLate: false,
    );

    mockTimeEntries.add(entry);
    MockWrite.changed();
    return entry;
  }

  /// `Pause`. Refuses unless the entry is `onShift` **and** has not already
  /// had a break today. One break per day is enforced here, not only by the
  /// UI hiding the button — [breakEndAt] being set is what tells the two
  /// apart, since after `Reprendre` the status is `onShift` again.
  static TimeEntry? startBreak(String entryId, {DateTime? now}) {
    final index = mockTimeEntries.indexWhere((e) => e.id == entryId);
    if (index == -1) return null;

    final existing = mockTimeEntries[index];
    if (existing.status != TimeEntryStatus.onShift) return null;
    if (existing.breakEndAt != null) return null;

    final updated = TimeEntry(
      id: existing.id,
      storeId: existing.storeId,
      employeeId: existing.employeeId,
      date: existing.date,
      status: TimeEntryStatus.onBreak,
      clockInAt: existing.clockInAt,
      breakStartAt: now ?? DateTime.now(),
      breakEndAt: existing.breakEndAt,
      clockOutAt: existing.clockOutAt,
      isLate: existing.isLate,
    );

    mockTimeEntries[index] = updated;
    MockWrite.changed();
    return updated;
  }

  /// `Reprendre`. Refuses unless the entry is currently `onBreak`. Computes
  /// how long the break ran through [breakDuration] — the same derivation
  /// every other screen reads — and flags [TimeEntry.isLate] when it exceeds
  /// [PointageRules.maxBreakDuration].
  static TimeEntry? endBreak(String entryId, {DateTime? now}) {
    final index = mockTimeEntries.indexWhere((e) => e.id == entryId);
    if (index == -1) return null;

    final existing = mockTimeEntries[index];
    if (existing.status != TimeEntryStatus.onBreak) return null;

    final withBreakEnd = TimeEntry(
      id: existing.id,
      storeId: existing.storeId,
      employeeId: existing.employeeId,
      date: existing.date,
      status: TimeEntryStatus.onShift,
      clockInAt: existing.clockInAt,
      breakStartAt: existing.breakStartAt,
      breakEndAt: now ?? DateTime.now(),
      clockOutAt: existing.clockOutAt,
      isLate: existing.isLate,
    );

    final duration = breakDuration(withBreakEnd);
    final late = duration != null && duration > PointageRules.maxBreakDuration;

    final updated = TimeEntry(
      id: withBreakEnd.id,
      storeId: withBreakEnd.storeId,
      employeeId: withBreakEnd.employeeId,
      date: withBreakEnd.date,
      status: withBreakEnd.status,
      clockInAt: withBreakEnd.clockInAt,
      breakStartAt: withBreakEnd.breakStartAt,
      breakEndAt: withBreakEnd.breakEndAt,
      clockOutAt: withBreakEnd.clockOutAt,
      isLate: late,
    );

    mockTimeEntries[index] = updated;
    MockWrite.changed();
    return updated;
  }

  /// `Fin de journée`. Refuses unless the entry is currently `onShift` — in
  /// particular it refuses while `onBreak`, so nobody clocks out mid-break by
  /// mistake.
  static TimeEntry? clockOut(String entryId, {DateTime? now}) {
    final index = mockTimeEntries.indexWhere((e) => e.id == entryId);
    if (index == -1) return null;

    final existing = mockTimeEntries[index];
    if (existing.status != TimeEntryStatus.onShift) return null;

    final updated = TimeEntry(
      id: existing.id,
      storeId: existing.storeId,
      employeeId: existing.employeeId,
      date: existing.date,
      status: TimeEntryStatus.clockedOut,
      clockInAt: existing.clockInAt,
      breakStartAt: existing.breakStartAt,
      breakEndAt: existing.breakEndAt,
      clockOutAt: now ?? DateTime.now(),
      isLate: existing.isLate,
    );

    mockTimeEntries[index] = updated;
    MockWrite.changed();
    return updated;
  }
}
