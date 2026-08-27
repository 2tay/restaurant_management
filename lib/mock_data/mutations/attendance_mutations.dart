import '../../models/models.dart';
import '../mock_attendances.dart';
import '../mock_queries.dart';
import '../mock_reference.dart';
import 'mock_write.dart';

/// Writes against the pointage — clock-in, breaks, clock-out.
///
/// **The only file that writes an [Attendance].** Same split as
/// `movement_mutations.dart` owning an item's quantity: `EmployeeMutations`
/// owns the personnel record, this file alone owns the attendance trail.
///
/// Every method refuses the wrong prior state rather than coercing it — the
/// same posture `OrderMutations` takes with a sent order — and refuses any
/// write against a day a payroll run has locked ([Attendance.payrollPeriodId]
/// set). Each takes an optional [now] so tests can pin a timestamp instead of
/// depending on wall-clock time passing between two calls.
abstract final class AttendanceMutations {
  /// `Pointer`. Refuses if a row already exists for this employee today —
  /// one [Attendance] per employee per calendar day.
  static Attendance? clockIn(
    String employeeId,
    String storeId, {
    DateTime? now,
  }) {
    if (MockQueries.attendanceForToday(employeeId) != null) return null;

    final entry = Attendance(
      id: MockWrite.id('att'),
      storeId: storeId,
      employeeId: employeeId,
      date: dayOnly(0),
      status: AttendanceStatus.working,
      clockInAt: now ?? DateTime.now(),
      pauses: const [],
      paymentStatus: PaymentStatus.unpaid,
    );

    mockAttendances.add(entry);
    MockWrite.changed();
    return entry;
  }

  /// `Pause`. Refuses unless the day is `working`. There is no cap on the
  /// number of breaks — the button offers `Pause` again after every
  /// `Reprendre`.
  static Attendance? startPause(String attendanceId, {DateTime? now}) {
    return _mutate(attendanceId, (entry) {
      if (entry.status != AttendanceStatus.working) return null;
      return _copy(
        entry,
        status: AttendanceStatus.onBreak,
        pauses: [
          ...entry.pauses,
          AttendancePause(startAt: now ?? DateTime.now()),
        ],
      );
    });
  }

  /// `Reprendre`. Refuses unless the day is `onBreak`. Closes the open break.
  static Attendance? endPause(String attendanceId, {DateTime? now}) {
    return _mutate(attendanceId, (entry) {
      if (entry.status != AttendanceStatus.onBreak) return null;
      final openIndex = entry.pauses.indexWhere((p) => p.endAt == null);
      if (openIndex == -1) return null;

      final pauses = [...entry.pauses];
      pauses[openIndex] = AttendancePause(
        startAt: pauses[openIndex].startAt,
        endAt: now ?? DateTime.now(),
      );
      return _copy(entry, status: AttendanceStatus.working, pauses: pauses);
    });
  }

  /// `Fin de journée`. Refuses unless the day is `working` — in particular it
  /// refuses while `onBreak`, so nobody clocks out mid-break by mistake.
  static Attendance? clockOut(String attendanceId, {DateTime? now}) {
    return _mutate(attendanceId, (entry) {
      if (entry.status != AttendanceStatus.working) return null;
      return _copy(
        entry,
        status: AttendanceStatus.done,
        clockOutAt: now ?? DateTime.now(),
      );
    });
  }

  /// Locks a set of finished days against a payroll run — sets their
  /// `paymentStatus` to `paid` and stamps [payrollPeriodId]. Called only by
  /// `PayrollMutations.pay`, so the attendance rows still have exactly one
  /// writer (this file), the same way order receiving goes through
  /// `MovementMutations` rather than writing item quantities itself. Does
  /// **not** call `MockWrite.changed()` — the caller batches the whole
  /// payment into one signal. Refuses (returns false, touches nothing) if any
  /// id is missing or already paid.
  static bool lockForPayroll(
    Iterable<String> attendanceIds,
    String payrollPeriodId,
  ) {
    final indices = <int>[];
    for (final id in attendanceIds) {
      final index = mockAttendances.indexWhere((a) => a.id == id);
      if (index == -1) return false;
      if (mockAttendances[index].paymentStatus == PaymentStatus.paid) {
        return false;
      }
      indices.add(index);
    }

    for (final index in indices) {
      final entry = mockAttendances[index];
      mockAttendances[index] = Attendance(
        id: entry.id,
        storeId: entry.storeId,
        employeeId: entry.employeeId,
        date: entry.date,
        status: entry.status,
        clockInAt: entry.clockInAt,
        clockOutAt: entry.clockOutAt,
        pauses: entry.pauses,
        paymentStatus: PaymentStatus.paid,
        payrollPeriodId: payrollPeriodId,
      );
    }
    return true;
  }

  // ---------------------------------------------------------------------------

  /// Applies [transform] to the row, or returns null if the row is missing,
  /// locked by payroll, or [transform] itself refuses (wrong prior state).
  static Attendance? _mutate(
    String attendanceId,
    Attendance? Function(Attendance entry) transform,
  ) {
    final index = mockAttendances.indexWhere((a) => a.id == attendanceId);
    if (index == -1) return null;

    final entry = mockAttendances[index];
    if (entry.paymentStatus == PaymentStatus.paid) return null;

    final updated = transform(entry);
    if (updated == null) return null;

    mockAttendances[index] = updated;
    MockWrite.changed();
    return updated;
  }

  static Attendance _copy(
    Attendance entry, {
    AttendanceStatus? status,
    DateTime? clockInAt,
    DateTime? clockOutAt,
    List<AttendancePause>? pauses,
  }) => Attendance(
    id: entry.id,
    storeId: entry.storeId,
    employeeId: entry.employeeId,
    date: entry.date,
    status: status ?? entry.status,
    clockInAt: clockInAt ?? entry.clockInAt,
    clockOutAt: clockOutAt ?? entry.clockOutAt,
    pauses: pauses ?? entry.pauses,
    paymentStatus: entry.paymentStatus,
    payrollPeriodId: entry.payrollPeriodId,
  );
}
