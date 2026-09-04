import '../../core/utils/employee_status.dart';
import '../../models/employee.dart';
import '../database/app_database.dart';
import '../database/meta_keys.dart';
import 'employee_repository.dart';

/// The signed-in employee, as a `meta` row.
///
/// This is `mock_session.dart` moved onto the database. The session is
/// [MetaKeys.currentEmployeeId] — a plain id, not a token, because Phase 3 owns
/// real auth. Absent means signed out.
///
/// [signIn] / [signOut] are the *only* writers of that key;
/// `currentEmployeeProvider` (the `Notifier` the guard and the shell read)
/// calls them and mirrors the result into its own state in one step, so a
/// screen reacts and the next synchronous `ref.read` is already correct.
///
/// [signIn] also refreshes [MetaKeys.currentUserName] — the display name every
/// stock movement and price change is stamped with — so "who is acting" tracks
/// the session rather than staying whatever the seed wrote.
class SessionRepository {
  const SessionRepository(this._db);

  final AppDatabase _db;

  /// The signed-in employee's id, or null when nobody is.
  Future<String?> currentEmployeeId() async {
    final row = await (_db.select(_db.meta)
          ..where((m) => m.key.equals(MetaKeys.currentEmployeeId)))
        .getSingleOrNull();
    return row?.value;
  }

  /// The signed-in employee, resolved. Null when signed out, and also null
  /// when the stored id no longer resolves (a deleted row — archiving does
  /// not delete, so in practice only a corrupt `meta` value).
  Future<Employee?> currentEmployee() async {
    final id = await currentEmployeeId();
    if (id == null) return null;
    return EmployeeRepository(_db).employee(id);
  }

  /// Signs [employeeId] in — writes the session row and refreshes the acting
  /// name. Returns the resolved employee, or null when the id does not exist
  /// (nothing is written in that case).
  Future<Employee?> signIn(String employeeId) async {
    return _db.transaction(() async {
      final employee = await EmployeeRepository(_db).employee(employeeId);
      if (employee == null) return null;

      await _put(MetaKeys.currentEmployeeId, employeeId);
      await _put(MetaKeys.currentUserName, employeeDisplayName(employee));
      return employee;
    });
  }

  /// Signs out — drops the session row. The acting name is left as it was:
  /// a background job that stamps a movement after sign-out is rare, and the
  /// last known name is a better attribution than an empty string.
  Future<void> signOut() async {
    await (_db.delete(_db.meta)
          ..where((m) => m.key.equals(MetaKeys.currentEmployeeId)))
        .go();
  }

  Future<void> _put(String key, String value) => _db
      .into(_db.meta)
      .insertOnConflictUpdate(MetaCompanion.insert(key: key, value: value));
}
