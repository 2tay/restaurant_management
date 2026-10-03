import 'package:drift/drift.dart';

import '../../../models/employee.dart';
import 'stores.dart';
import 'sync_columns.dart';

/// A member of staff at one establishment.
///
/// The single "person" model: the employment facts (hourly rate, PIN) and the
/// application access ([role]) on one record. One establishment per person — see
/// `.claude/phase_gestion_employee.md` decision 2; an owner spans stores by
/// navigating, not by a list on this row. Soft-removed only: [archivedAt] is the
/// whole truth about whether they are still active.
@DataClassName('EmployeeRow')
@TableIndex(name: 'employees_store', columns: {#storeId})
@TableIndex(name: 'employees_pin', columns: {#pin}, unique: true)
@TableIndex(name: 'employees_email', columns: {#email}, unique: true)
class Employees extends Table with Touched, Deletable {
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
  TextColumn get pin => text()();

  TextColumn get phone => text()();

  /// Unique across the whole account.
  TextColumn get email => text()();

  /// The photo file `EmployeePhotoStore` copied in; null renders initials.
  TextColumn get photoAsset => text().nullable()();

  DateTimeColumn get hireDate => dateTime()();

  TextColumn get role => textEnum<EmployeeRole>()();

  /// EUR per hour — every hour actually worked is paid at this rate.
  RealColumn get pay => real()();

  DateTimeColumn get createdAt => dateTime()();

  /// Null while active. The only form of removal — there is no hard delete.
  DateTimeColumn get archivedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One employee's login secret and lockout state.
///
/// A pay change and a failed-login counter have nothing to do with each other,
/// which is why this is its own table and not columns on [Employees]. The
/// password is stored as a salted PBKDF2 hash (`core/utils/password_hash.dart`),
/// never in the clear.
@DataClassName('EmployeeCredentialRow')
// One live credential per employee: `employee_credentials_employee`, a
// partial unique index in `sync_indexes.drift`.
class EmployeeCredentials extends Table with Touched, Deletable {
  TextColumn get id => text().withLength(min: 1, max: 64)();

  /// The establishment, copied from the parent row. Redundant locally, but it
  /// lets the server check who may see this row without a join to its parent.
  TextColumn get storeId =>
      text().references(Stores, #id, onDelete: KeyAction.cascade)();

  /// `ON DELETE CASCADE` and unique — one credential per employee, and it goes
  /// when they do.
  TextColumn get employeeId =>
      text().references(Employees, #id, onDelete: KeyAction.cascade)();

  /// The only thing shared about a login. The attempts, the lockout and the
  /// last login are this tablet's own: `login_states` (step 5, rule C1).
  TextColumn get passwordHash => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
