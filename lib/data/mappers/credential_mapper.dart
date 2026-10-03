import '../../models/employee_credential.dart';
import '../database/app_database.dart';

/// [state] is this tablet's sign-in state for the employee (`login_states`),
/// null when nobody has tried to sign in as them here yet.
EmployeeCredential credentialFromRow(
  EmployeeCredentialRow row, [
  LoginStateRow? state,
]) => EmployeeCredential(
  id: row.id,
  employeeId: row.employeeId,
  passwordHash: row.passwordHash,
  failedAttempts: state?.failedAttempts ?? 0,
  lockedUntil: state?.lockedUntil,
  lastLoginAt: state?.lastLoginAt,
);

/// The credential model does not carry its store; it is the employee's, and
/// the caller supplies it.
EmployeeCredentialsCompanion credentialToRow(
  EmployeeCredential credential, {
  required String storeId,
}) =>
    EmployeeCredentialsCompanion.insert(
      id: credential.id,
      storeId: storeId,
      employeeId: credential.employeeId,
      passwordHash: credential.passwordHash,
    );
