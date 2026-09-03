import 'package:drift/drift.dart';

import '../../../models/attendance.dart';
import 'employees.dart';
import 'payroll.dart';
import 'stores.dart';

/// One employee's attendance for one calendar day.
///
/// Created lazily on the first `Pointer` of the day — a day with no row simply
/// means "not clocked in". `(employeeId, date)` is unique.
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
  DateTimeColumn get clockInAt => dateTime().nullable()();
  DateTimeColumn get clockOutAt => dateTime().nullable()();

  /// The evaluation context this day was worked in, frozen when the row is
  /// created (schema v4): the resolved start / end of day and the break
  /// allowance that `en retard`, `heures supp.` and `pause dépassée` are
  /// measured against. Without it, changing the store hours or an employee's
  /// schedule silently rewrote every past day's figures — a day that was on
  /// time became late, real overtime vanished.
  ///
  /// Null on rows created before v4 (the migration backfills them with what
  /// they resolved to at upgrade time) and, defensively, whenever the reader
  /// cannot resolve one — [attendance_status.dart]'s `evaluationContext` falls
  /// back to the live resolved schedule in that case.
  IntColumn get scheduledStartMinutes => integer().nullable()();
  IntColumn get scheduledEndMinutes => integer().nullable()();
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

/// One break segment inside a day. There can be several — the button offers
/// `Pause` again after every `Reprendre`.
///
/// `Attendance.pauses` is an ordered list on the model and a child table has no
/// order of its own, so [position] is a column (the lesson `phase2.md` learned
/// for the order and receipt lines). A running break has a null [endAt] and is
/// last.
@DataClassName('AttendancePauseRow')
@TableIndex(
  name: 'attendance_pauses_attendance',
  columns: {#attendanceId, #position},
  unique: true,
)
class AttendancePauses extends Table {
  TextColumn get id => text().withLength(min: 1, max: 64)();
  TextColumn get attendanceId =>
      text().references(Attendances, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  DateTimeColumn get startAt => dateTime()();
  DateTimeColumn get endAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
