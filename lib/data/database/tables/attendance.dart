import 'package:drift/drift.dart';

import '../../../models/attendance.dart';
import 'employees.dart';
import 'payroll.dart';
import 'stores.dart';

/// One employee's attendance for one calendar day.
///
/// Created lazily on the first `Pointer` of the day — a day with no row simply
/// means "not clocked in". `(employeeId, date)` is unique — but the day itself
/// can hold several [AttendanceSessions], since an employee may clock out for
/// a few hours and clock back in the same day.
///
/// **`Attendance.paymentStatus` is derived, not stored.** There is no
/// `payment_status` column; `mappers/attendance_mapper.dart` reads
/// `payrollPeriodId == null ? unpaid : paid`. One nullable FK is the source of
/// truth.
@DataClassName('AttendanceRow')
@TableIndex(
  name: 'attendances_employee_date',
  columns: {#employeeId, #date},
  unique: true,
)
@TableIndex(name: 'attendances_store_date', columns: {#storeId, #date})
class Attendances extends Table {
  TextColumn get id => text().withLength(min: 1, max: 64)();
  TextColumn get storeId =>
      text().references(Stores, #id, onDelete: KeyAction.cascade)();
  TextColumn get employeeId =>
      text().references(Employees, #id, onDelete: KeyAction.cascade)();

  /// Midnight-normalised — the work day this row is for, not when it was
  /// created.
  DateTimeColumn get date => dateTime()();

  TextColumn get status => textEnum<AttendanceStatus>()();

  /// The break allowance this day was worked under, frozen when the row is
  /// created (schema v4) so a later change to the store's setting cannot
  /// rewrite a past day's "pause dépassée".
  ///
  /// Null on rows created before v4 (the migration backfills them with what
  /// they resolved to at upgrade time) and, defensively, whenever the reader
  /// cannot resolve one — callers fall back to the store's live
  /// `maxBreakMinutes` in that case.
  IntColumn get maxBreakMinutes => integer().nullable()();

  /// Set when a [PayrollPeriods] row locks this day. While set the row is
  /// immutable — every attendance write refuses it — and the model's
  /// `paymentStatus` reads `paid`. `RESTRICT`: a paid period cannot be deleted
  /// out from under the days it covers.
  TextColumn get payrollPeriodId => text()
      .references(PayrollPeriods, #id, onDelete: KeyAction.restrict)
      .nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One Pointer → Fin de journée cycle inside a day. There can be several — an
/// employee may clock out for a few hours and clock back in the same day.
///
/// `Attendance.sessions` is an ordered list on the model and a child table has
/// no order of its own, so [position] is a column (the lesson `phase2.md`
/// learned for the order and receipt lines).
@DataClassName('AttendanceSessionRow')
@TableIndex(
  name: 'attendance_sessions_attendance',
  columns: {#attendanceId, #position},
  unique: true,
)
class AttendanceSessions extends Table {
  TextColumn get id => text().withLength(min: 1, max: 64)();
  TextColumn get attendanceId =>
      text().references(Attendances, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  DateTimeColumn get clockInAt => dateTime()();
  DateTimeColumn get clockOutAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One break segment inside a session. There can be several — the button
/// offers `Pause` again after every `Reprendre`.
///
/// `AttendanceSession.pauses` is an ordered list on the model and a child
/// table has no order of its own, so [position] is a column, scoped to the
/// session rather than the whole day: a pause belongs to exactly one cycle.
/// A running break has a null [endAt] and is last.
@DataClassName('AttendancePauseRow')
@TableIndex(
  name: 'attendance_pauses_session',
  columns: {#sessionId, #position},
  unique: true,
)
class AttendancePauses extends Table {
  TextColumn get id => text().withLength(min: 1, max: 64)();
  TextColumn get sessionId =>
      text().references(AttendanceSessions, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  DateTimeColumn get startAt => dateTime()();
  DateTimeColumn get endAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
