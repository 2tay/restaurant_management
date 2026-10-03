import 'package:drift/drift.dart';

import 'employees.dart';

/// How signing in is going for one employee **on this tablet**: the wrong
/// passwords in a row, the lockout they caused, the last success.
///
/// Local, never synced (SYNC_PERSONNEL_PLAN.md, step 5, rules C1 and C3). It
/// used to sit on `employee_credentials`, which is shared: a login on one
/// tablet then sent the whole credential, and could put back an old password
/// another tablet had just changed. Now only the password travels, and each
/// tablet counts its own attempts — a lockout here does not lock the others.
///
/// No row until the first attempt on this tablet; a missing row reads as "no
/// attempt, no lockout".
@DataClassName('LoginStateRow')
class LoginStates extends Table {
  TextColumn get employeeId =>
      text().references(Employees, #id, onDelete: KeyAction.cascade)();

  /// Consecutive wrong passwords since the last success or the last new
  /// password.
  IntColumn get failedAttempts => integer().withDefault(const Constant(0))();

  /// Set once [failedAttempts] reaches the threshold.
  DateTimeColumn get lockedUntil => dateTime().nullable()();

  DateTimeColumn get lastLoginAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {employeeId};
}
