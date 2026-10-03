import 'package:drift/drift.dart';

import 'employees.dart';
import 'stores.dart';

/// One journée de service — the span the pointage board works in, from its
/// opening to its closing, **however far past midnight** that runs.
///
/// A service that ends at 00:30 still belongs to the day it opened on: the
/// board reads the open journée rather than the wall clock, and every
/// attendance row clocked while it is open carries its [date]. That is what
/// fixes a shift crossing midnight (audit L1) and a board frozen on the date it
/// was opened (L2).
///
/// No FK from `attendances`: the link is the date. `(storeId, date)` is unique
/// here, `(employeeId, date)` is unique there, so a journée's attendance rows
/// are exactly the store's rows on its date.
///
/// At most **one open journée per store** — enforced by
/// `BusinessDayRepository.open` inside its transaction, since a partial unique
/// index (`WHERE closed_at IS NULL`) is not something `@TableIndex` expresses.
@DataClassName('BusinessDayRow')
@TableIndex(
  name: 'business_days_store_date',
  columns: {#storeId, #date},
  unique: true,
)
class BusinessDays extends Table {
  TextColumn get id => text().withLength(min: 1, max: 64)();
  TextColumn get storeId =>
      text().references(Stores, #id, onDelete: KeyAction.cascade)();

  /// Midnight-normalised — the calendar day the journée opened on, and the
  /// `date` every attendance row clocked during it carries.
  DateTimeColumn get date => dateTime()();

  DateTimeColumn get openedAt => dateTime()();

  /// Who opened it — the manager at the board, or whoever clocked in first
  /// when the journée opened itself. `SET NULL`: removing an employee does not
  /// take the store's history with them.
  TextColumn get openedByEmployeeId => text()
      .references(Employees, #id, onDelete: KeyAction.setNull)
      .nullable()();

  /// Null while the journée is open. Only ever set by a manual close — nothing
  /// closes a journée on its own, so no exit time is ever invented.
  DateTimeColumn get closedAt => dateTime().nullable()();

  TextColumn get closedByEmployeeId => text()
      .references(Employees, #id, onDelete: KeyAction.setNull)
      .nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
