import 'package:drift/drift.dart';

import '../../core/utils/credential_status.dart';
import '../../models/employee.dart';
import '../database/app_database.dart';
import '../mappers/mappers.dart';
import 'credential_repository.dart';
import 'new_id.dart';

/// The staff roster.
///
/// Nothing here changes an employee's `archivedAt` through [update] — archiving
/// is its own transition ([archive] / [restore]), the same way a quantity
/// change is a movement rather than an item edit.
///
/// **Ordering is alphabetical by display name**, then id. The mock list was in
/// the order the demo was authored; a database has no such habit, and the
/// roster screen reads top-to-bottom as a list of people, so name order is what
/// that expectation becomes.
class EmployeeRepository {
  const EmployeeRepository(this._db);

  final AppDatabase _db;

  /// Every employee of the establishment, any status — the roster with the
  /// "afficher les archivés" pill on.
  Stream<List<Employee>> watchEmployees(String storeId) =>
      _byName(storeId).watch().map(_toEmployees);

  Future<List<Employee>> employees(String storeId) =>
      _byName(storeId).get().then(_toEmployees);

  /// Active only — archived people drop off the roster but stay resolvable by
  /// [employee] so a retired record still opens.
  Stream<List<Employee>> watchActiveEmployees(String storeId) =>
      (_byName(storeId)..where((e) => e.archivedAt.isNull()))
          .watch()
          .map(_toEmployees);

  Future<List<Employee>> activeEmployees(String storeId) =>
      (_byName(storeId)..where((e) => e.archivedAt.isNull()))
          .get()
          .then(_toEmployees);

  Stream<Employee?> watchEmployee(String id) =>
      (_db.select(_db.employees)..where((e) => e.id.equals(id)))
          .watchSingleOrNull()
          .map(_toEmployeeOrNull);

  Future<Employee?> employee(String id) =>
      (_db.select(_db.employees)..where((e) => e.id.equals(id)))
          .getSingleOrNull()
          .then(_toEmployeeOrNull);

  /// The employee already using this PIN, ignoring [excludingId].
  ///
  /// Account-wide — the PIN is unique across every establishment and is the
  /// login identifier (Phase 6). The schema enforces uniqueness; this exists for
  /// the message the add / edit form shows before it submits. The exclusion is
  /// what lets an edit keep its own PIN unchanged.
  Future<Employee?> employeeByPin(String pin, {String? excludingId}) async {
    final needle = _normalise(pin);
    if (needle.isEmpty) return null;
    for (final employee in await _all()) {
      if (employee.id == excludingId) continue;
      if (_normalise(employee.pin) == needle) return employee;
    }
    return null;
  }

  /// The employee already using this email, ignoring [excludingId].
  /// Account-wide, like [employeeByPin].
  Future<Employee?> employeeByEmail(String email, {String? excludingId}) async {
    final needle = _normalise(email);
    if (needle.isEmpty) return null;
    for (final employee in await _all()) {
      if (employee.id == excludingId) continue;
      if (_normalise(employee.email) == needle) return employee;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Creates an employee, and — when [password] is given — their login credential in
  /// the same transaction.
  ///
  /// Returns null, writing nothing, when a required text field is empty, when
  /// the PIN or the email is already used by another employee anywhere on the
  /// account (both are unique account-wide, and the PIN is the login
  /// identifier), or when [password] is set but is not [AuthRules.passwordLength] digits.
  ///
  /// The add-employee form creates the person and their password in one submit: an
  /// employee row with no credential is somebody who cannot sign in, which
  /// reads as a bug. Doing both here, in one transaction, makes that state
  /// unreachable rather than merely unlikely.
  Future<Employee?> create({
    required String storeId,
    required String firstName,
    required String lastName,
    required String pin,
    required String phone,
    required String email,
    required EmployeeRole role,
    required double pay,
    DateTime? hireDate,
    String? photoAsset,
    String? password,
  }) async {
    final first = firstName.trim();
    final last = lastName.trim();
    final trimmedPin = pin.trim();
    final trimmedPhone = phone.trim();
    final trimmedEmail = email.trim();
    if (first.isEmpty ||
        last.isEmpty ||
        trimmedPin.isEmpty ||
        trimmedPhone.isEmpty ||
        trimmedEmail.isEmpty) {
      return null;
    }
    if (password != null && !isValidPassword(password)) return null;

    final now = DateTime.now();

    return _db.transaction(() async {
      if (await employeeByPin(trimmedPin) != null) return null;
      if (await employeeByEmail(trimmedEmail) != null) return null;

      final employee = Employee(
        id: newId(),
        storeId: storeId,
        firstName: first,
        lastName: last,
        pin: trimmedPin,
        phone: trimmedPhone,
        email: trimmedEmail,
        photoAsset: photoAsset,
        hireDate: hireDate ?? now,
        role: role,
        pay: pay,
        createdAt: now,
      );

      await _db.into(_db.employees).insert(employeeToRow(employee));

      if (password != null) {
        // The password was checked above and the employee row now exists in this
        // transaction, so this cannot fail — but if that ever stops holding,
        // rolling the whole create back is the right answer to a credential
        // that did not take.
        final credential = await CredentialRepository(
          _db,
        ).setPassword(employee.id, password);
        if (credential == null) {
          throw StateError('setPassword refused a validated password for ${employee.id}');
        }
      }

      return employee;
    });
  }

  /// Edits an employee's details.
  ///
  /// **`archivedAt` is not a parameter** — archiving is [archive] / [restore],
  /// the same reasoning that keeps quantity off the item edit form: an
  /// audit-relevant transition should not be reachable by a field on a routine
  /// form. [clearPhoto] removes the photo.
  ///
  /// Returns null, writing nothing, when the id is unknown, a supplied text
  /// field is blank, or the PIN / email would now collide with another
  /// employee.
  Future<Employee?> update(
    String id, {
    String? firstName,
    String? lastName,
    String? pin,
    String? phone,
    String? email,
    EmployeeRole? role,
    double? pay,
    String? photoAsset,
    bool clearPhoto = false,
  }) async {
    final first = firstName?.trim();
    if (first != null && first.isEmpty) return null;
    final last = lastName?.trim();
    if (last != null && last.isEmpty) return null;
    final trimmedPin = pin?.trim();
    if (trimmedPin != null && trimmedPin.isEmpty) return null;
    final trimmedPhone = phone?.trim();
    if (trimmedPhone != null && trimmedPhone.isEmpty) return null;
    final trimmedEmail = email?.trim();
    if (trimmedEmail != null && trimmedEmail.isEmpty) return null;

    return _db.transaction(() async {
      final existing = await employee(id);
      if (existing == null) return null;

      if (trimmedPin != null &&
          await employeeByPin(trimmedPin, excludingId: id) != null) {
        return null;
      }
      if (trimmedEmail != null &&
          await employeeByEmail(trimmedEmail, excludingId: id) != null) {
        return null;
      }

      final updated = Employee(
        id: existing.id,
        storeId: existing.storeId,
        firstName: first ?? existing.firstName,
        lastName: last ?? existing.lastName,
        pin: trimmedPin ?? existing.pin,
        phone: trimmedPhone ?? existing.phone,
        email: trimmedEmail ?? existing.email,
        photoAsset: clearPhoto ? null : photoAsset ?? existing.photoAsset,
        hireDate: existing.hireDate,
        role: role ?? existing.role,
        pay: pay ?? existing.pay,
        createdAt: existing.createdAt,
        archivedAt: existing.archivedAt,
      );

      await (_db.update(
        _db.employees,
      )..where((e) => e.id.equals(id))).write(employeeToRow(updated));
      return updated;
    });
  }

  /// Soft-removes an employee: stamps `archivedAt`, nothing else. Returns
  /// `false` if already archived. History — attendance, payroll — is left
  /// exactly as it was, the same as a removed supplier keeping its movements.
  /// There is no hard delete.
  Future<bool> archive(String id, {DateTime? at}) =>
      _setArchivedAt(id, at ?? DateTime.now());

  /// Brings a retired employee back. Returns `false` if not archived.
  Future<bool> restore(String id) => _setArchivedAt(id, null);

  Future<bool> _setArchivedAt(String id, DateTime? value) {
    return _db.transaction(() async {
      final existing = await employee(id);
      if (existing == null) return false;
      // Refuse the no-op transition — archiving an archived record, restoring
      // an active one — exactly as `EmployeeMutations` did.
      if ((existing.archivedAt == null) == (value == null)) return false;

      await (_db.update(_db.employees)..where((e) => e.id.equals(id))).write(
        EmployeesCompanion(archivedAt: Value(value)),
      );
      return true;
    });
  }

  // ---------------------------------------------------------------------------

  /// Trimmed and case-folded, no accent folding — the same comparison
  /// `MockQueries._normalise` used, so "  78.02.14-153.24 " still resolves.
  static String _normalise(String value) => value.trim().toLowerCase();

  Future<List<Employee>> _all() =>
      _db.select(_db.employees).get().then(_toEmployees);

  SimpleSelectStatement<$EmployeesTable, EmployeeRow> _byName(String storeId) =>
      _db.select(_db.employees)
        ..where((e) => e.storeId.equals(storeId))
        ..orderBy([
          (e) => OrderingTerm(expression: e.firstName),
          (e) => OrderingTerm(expression: e.lastName),
          (e) => OrderingTerm(expression: e.id),
        ]);

  List<Employee> _toEmployees(List<EmployeeRow> rows) =>
      rows.map(employeeFromRow).toList();

  Employee? _toEmployeeOrNull(EmployeeRow? row) =>
      row == null ? null : employeeFromRow(row);
}
