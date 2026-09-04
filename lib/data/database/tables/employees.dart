import 'package:drift/drift.dart';

import '../../../models/employee.dart';
import 'stores.dart';

/// A member of staff at one establishment.
///
/// The single "person" model: the employment facts (contract, pay, CIN) and the
/// application access ([role]) on one record. One establishment per person — see
/// `.claude/phase_gestion_employee.md` decision 2; an owner spans stores by
/// navigating, not by a list on this row. Soft-removed only: [archivedAt] is the
/// whole truth about whether they are still active.
@DataClassName('EmployeeRow')
@TableIndex(name: 'employees_store', columns: {#storeId})
@TableIndex(name: 'employees_cin', columns: {#cin}, unique: true)
@TableIndex(name: 'employees_email', columns: {#email}, unique: true)
class Employees extends Table {
  TextColumn get id => text().withLength(min: 1, max: 64)();

  /// `RESTRICT` — an establishment with staff on file cannot be deleted. The
  /// domain has no flow that would need to; the constraint makes the absence a
  /// fact rather than a gap.
  TextColumn get storeId =>
      text().references(Stores, #id, onDelete: KeyAction.restrict)();

  TextColumn get firstName => text()();
  TextColumn get lastName => text()();

  /// Carte d'identité nationale — the identity document, and the login
  /// identifier (Phase 6). Unique across the whole account, not per store; the
  /// index above makes that a constraint, and the repository keeps its own
  /// check for the message the form shows.
  TextColumn get cin => text()();

  TextColumn get phone => text()();

  /// Unique across the whole account.
  TextColumn get email => text()();

  /// Mocked, like `stores.imageAsset`: a nullable path with no picker behind it.
  TextColumn get photoAsset => text().nullable()();

  DateTimeColumn get hireDate => dateTime()();

  TextColumn get role => textEnum<EmployeeRole>()();
  TextColumn get contractType => textEnum<ContractType>()();

  /// Monthly EUR when `fixed`, EUR per hour when `extra` — read per
  /// [contractType].
  RealColumn get pay => real()();

  /// Minutes since midnight for this person's own start / end of day. Null means
  /// "use the establishment's opening hours" — the resolved schedule is what
  /// lateness and overtime are measured against. Stored as an int, not a
  /// `DateTime`: these are times of day, not instants.
  IntColumn get scheduledStartMinutes => integer().nullable()();
  IntColumn get scheduledEndMinutes => integer().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  /// Null while active. The only form of removal — there is no hard delete.
  DateTimeColumn get archivedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One employee's login secret and lockout state.
///
/// A pay change and a failed-login counter have nothing to do with each other,
/// which is why this is its own table and not columns on [Employees]. The hash
/// is fake (`core/utils/credential_status.dart`) — Phase 6 stays offline; this
/// just never holds the PIN in the clear.
@DataClassName('EmployeeCredentialRow')
@TableIndex(name: 'employee_credentials_employee', columns: {#employeeId}, unique: true)
class EmployeeCredentials extends Table {
  TextColumn get id => text().withLength(min: 1, max: 64)();

  /// `ON DELETE CASCADE` and unique — one credential per employee, and it goes
  /// when they do.
  TextColumn get employeeId =>
      text().references(Employees, #id, onDelete: KeyAction.cascade)();

  TextColumn get pinHash => text()();
  IntColumn get failedAttempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get lockedUntil => dateTime().nullable()();
  DateTimeColumn get lastLoginAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
