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
// The PIN (CIN) and the email are unique per store among live rows —
// `employees_store_pin` / `employees_store_email` in `sync_indexes.drift`
// (SYNC_PERSONNEL_PLAN.md, step 8, rule E1). The repository still refuses a
// duplicate anywhere in the account when one is typed here.
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
  /// identifier (Phase 6). The repository refuses one already used anywhere
  /// in the account; the database only holds it unique per store among live
  /// rows, because two tablets can each add "the" same person — sync merges
  /// them (rule E1) — or the same CIN in two stores, which stays two people
  /// and is signalled.
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
