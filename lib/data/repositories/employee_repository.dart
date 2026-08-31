import 'package:drift/drift.dart';

import '../../models/employee.dart';
import '../database/app_database.dart';
import '../mappers/mappers.dart';

/// The staff roster.
///
/// Reads only in this stage; the writes (`create`, `update`, `archive`,
/// `restore`) land in stage 4. Nothing here changes an employee's
/// `archivedAt` — archiving is its own transition, the same way a quantity
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

  /// The employee already using this CIN, ignoring [excludingId].
  ///
  /// Account-wide — the CIN is unique across every establishment and is the
  /// login identifier (Phase 6). The schema enforces uniqueness; this exists for
  /// the message the add / edit form shows before it submits. The exclusion is
  /// what lets an edit keep its own CIN unchanged.
  Future<Employee?> employeeByCin(String cin, {String? excludingId}) async {
    final needle = _normalise(cin);
    if (needle.isEmpty) return null;
    for (final employee in await _all()) {
      if (employee.id == excludingId) continue;
      if (_normalise(employee.cin) == needle) return employee;
    }
    return null;
  }

  /// The employee already using this email, ignoring [excludingId].
  /// Account-wide, like [employeeByCin].
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
