import 'package:drift/drift.dart';

import '../../../models/payroll_period.dart';
import 'employees.dart';
import 'stores.dart';

/// One payroll run for one employee — the days it covered, the figures it was
/// computed from, and the amount, frozen at the moment "Payer" was tapped.
///
/// Same permanence as a confirmed goods receipt: once `paid` it is never edited
/// or deleted, [appliedRate] freezes the pay rate, and the attendance days it
/// covers can no longer be touched (`attendances.payrollPeriodId` is `RESTRICT`
/// against this row).
@DataClassName('PayrollPeriodRow')
@TableIndex(name: 'payroll_periods_employee', columns: {#employeeId, #paidAt})
@TableIndex(name: 'payroll_periods_store', columns: {#storeId, #paidAt})
class PayrollPeriods extends Table {
  TextColumn get id => text().withLength(min: 1, max: 64)();
  TextColumn get employeeId =>
      text().references(Employees, #id, onDelete: KeyAction.cascade)();
  TextColumn get storeId =>
      text().references(Stores, #id, onDelete: KeyAction.cascade)();

  /// First and last work day this run covered (midnight-normalised).
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();

  IntColumn get workedDays => integer()();
  RealColumn get totalWorkedHours => real()();
  RealColumn get totalOvertimeHours => real()();

  /// Snapshot of the employee's pay (monthly EUR for `fixed`, EUR/h for
  /// `extra`) at pay time — a later raise cannot rewrite history.
  RealColumn get appliedRate => real()();
  RealColumn get computedAmount => real()();

  TextColumn get status => textEnum<PayrollStatus>()();

  /// The owner who validated the run. **No foreign key** — they may later be
  /// archived, and the row keeps their id to render their name, the same
  /// pattern as `stock_movements.supplierId`.
  TextColumn get paidByEmployeeId => text().nullable()();
  DateTimeColumn get paidAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
