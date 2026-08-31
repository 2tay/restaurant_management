import '../../models/employee_credential.dart';
import '../database/app_database.dart';
import '../mappers/mappers.dart';

/// The login secret and lockout state behind an employee's CIN.
///
/// Reads only in this stage. The write path — `setPin`,
/// `recordFailedAttempt`, `recordSuccessfulLogin`, `unlock`, `authenticate` —
/// lands in stage 4, and the `ux_audit.py` guard that only this file may write
/// `employee_credentials` goes in with it.
class CredentialRepository {
  const CredentialRepository(this._db);

  final AppDatabase _db;

  /// This employee's credential, or null when no PIN has been set.
  Future<EmployeeCredential?> forEmployee(String employeeId) =>
      (_db.select(_db.employeeCredentials)
            ..where((c) => c.employeeId.equals(employeeId)))
          .getSingleOrNull()
          .then((row) => row == null ? null : credentialFromRow(row));
}
