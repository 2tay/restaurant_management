import 'package:drift/drift.dart';

import '../../models/attendance.dart';
import '../database/app_database.dart';

/// Takes its sessions separately, because this is where the shape changes.
///
/// `Attendance.sessions` is an embedded list on the model and a child table in
/// the schema — the same asymmetry `order_mapper.dart` carries for order
/// lines. Sessions are expected oldest-first already (see
/// `attendanceSessionsFromRows`).
///
/// **`Attendance.paymentStatus` is derived, not stored.** There is no
/// `payment_status` column; a day is `paid` exactly when it points at a payroll
/// period, `unpaid` otherwise. One nullable FK, one source of truth.
Attendance attendanceFromRows(
  AttendanceRow row,
  List<AttendanceSession> sessions,
) => Attendance(
  id: row.id,
  storeId: row.storeId,
  employeeId: row.employeeId,
  date: row.date,
  status: row.status,
  sessions: sessions,
  paymentStatus: row.payrollPeriodId == null
      ? PaymentStatus.unpaid
      : PaymentStatus.paid,
  payrollPeriodId: row.payrollPeriodId,
  maxBreakMinutes: row.maxBreakMinutes,
);

/// The attendance row only. Its sessions are written separately — see
/// [sessionToRow] — and `paymentStatus` is not written at all: it is read back
/// from [Attendance.payrollPeriodId].
AttendancesCompanion attendanceToRow(Attendance attendance) =>
    AttendancesCompanion.insert(
      id: attendance.id,
      storeId: attendance.storeId,
      employeeId: attendance.employeeId,
      date: attendance.date,
      status: attendance.status,
      payrollPeriodId: Value(attendance.payrollPeriodId),
      maxBreakMinutes: Value(attendance.maxBreakMinutes),
    );

/// One session, with its pauses re-sorted by their `position` column so a
/// cycle always rebuilds oldest-break-first regardless of the order the pause
/// rows came back in.
AttendanceSession attendanceSessionFromRow(
  AttendanceSessionRow row,
  List<AttendancePauseRow> pauseRows,
) {
  final ordered = [...pauseRows]
    ..sort((a, b) => a.position.compareTo(b.position));
  return AttendanceSession(
    clockInAt: row.clockInAt,
    clockOutAt: row.clockOutAt,
    pauses: ordered.map(pauseFromRow).toList(),
  );
}

/// The session carries neither its day's id nor its own position on the
/// model — it only ever exists inside one [Attendance], as an element of an
/// ordered list — so the caller supplies both.
///
/// [id] defaults to a slug built from the day and the position, which is what
/// the seed wants (debuggable, stable across a re-seed). The attendance
/// repository passes a fresh uuid instead when a cycle is opened at runtime.
AttendanceSessionsCompanion sessionToRow(
  AttendanceSession session, {
  required String attendanceId,
  required int position,
  String? id,
}) => AttendanceSessionsCompanion.insert(
  id: id ?? '$attendanceId-session-$position',
  attendanceId: attendanceId,
  position: position,
  clockInAt: session.clockInAt,
  clockOutAt: Value(session.clockOutAt),
);

AttendancePause pauseFromRow(AttendancePauseRow row) =>
    AttendancePause(startAt: row.startAt, endAt: row.endAt);

/// The pause carries neither its session's id nor its own position on the
/// model — it only ever exists inside one [AttendanceSession], as an element
/// of an ordered list — so the caller supplies both.
///
/// [id] defaults to a slug built from the session and the position, which is
/// what the seed wants (debuggable, stable across a re-seed). The attendance
/// repository passes a fresh uuid instead when a break is opened at runtime.
AttendancePausesCompanion pauseToRow(
  AttendancePause pause, {
  required String sessionId,
  required int position,
  String? id,
}) => AttendancePausesCompanion.insert(
  id: id ?? '$sessionId-pause-$position',
  sessionId: sessionId,
  position: position,
  startAt: pause.startAt,
  endAt: Value(pause.endAt),
);
