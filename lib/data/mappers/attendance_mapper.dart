import 'package:drift/drift.dart';

import '../../models/attendance.dart';
import '../database/app_database.dart';

/// Takes its pauses separately, because this is where the shape changes.
///
/// `Attendance.pauses` is an embedded list on the model and a child table in the
/// schema — the same asymmetry `order_mapper.dart` carries for order lines. The
/// pauses are re-sorted here by their `position` column so a day always rebuilds
/// oldest-break-first regardless of the order the rows came back in.
///
/// **`Attendance.paymentStatus` is derived, not stored.** There is no
/// `payment_status` column; a day is `paid` exactly when it points at a payroll
/// period, `unpaid` otherwise. One nullable FK, one source of truth.
Attendance attendanceFromRows(
  AttendanceRow row,
  List<AttendancePauseRow> pauseRows,
) {
  final ordered = [...pauseRows]
    ..sort((a, b) => a.position.compareTo(b.position));
  return Attendance(
    id: row.id,
    storeId: row.storeId,
    employeeId: row.employeeId,
    date: row.date,
    status: row.status,
    pauses: ordered.map(pauseFromRow).toList(),
    paymentStatus: row.payrollPeriodId == null
        ? PaymentStatus.unpaid
        : PaymentStatus.paid,
    clockInAt: row.clockInAt,
    clockOutAt: row.clockOutAt,
    payrollPeriodId: row.payrollPeriodId,
  );
}

/// The attendance row only. Its pauses are written separately — see
/// [pauseToRow] — and `paymentStatus` is not written at all: it is read back
/// from [Attendance.payrollPeriodId].
AttendancesCompanion attendanceToRow(Attendance attendance) =>
    AttendancesCompanion.insert(
      id: attendance.id,
      storeId: attendance.storeId,
      employeeId: attendance.employeeId,
      date: attendance.date,
      status: attendance.status,
      clockInAt: Value(attendance.clockInAt),
      clockOutAt: Value(attendance.clockOutAt),
      payrollPeriodId: Value(attendance.payrollPeriodId),
    );

AttendancePause pauseFromRow(AttendancePauseRow row) =>
    AttendancePause(startAt: row.startAt, endAt: row.endAt);

/// The pause carries neither its day's id nor its own position on the model —
/// it only ever exists inside one [Attendance], as an element of an ordered
/// list — so the caller supplies both.
///
/// [id] defaults to a slug built from the day and the position, which is what
/// the seed wants (debuggable, stable across a re-seed). The attendance
/// repository passes a fresh uuid instead when a break is opened at runtime.
AttendancePausesCompanion pauseToRow(
  AttendancePause pause, {
  required String attendanceId,
  required int position,
  String? id,
}) => AttendancePausesCompanion.insert(
  id: id ?? '$attendanceId-pause-$position',
  attendanceId: attendanceId,
  position: position,
  startAt: pause.startAt,
  endAt: Value(pause.endAt),
);
