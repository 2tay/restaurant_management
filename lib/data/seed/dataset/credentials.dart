import '../../../core/utils/credential_status.dart';
import '../../../models/employee_credential.dart';
import 'employees.dart';

/// Login secrets — one per employee, so any PIN a demo types resolves to
/// something rather than a dead end.
///
/// **Every password is `1234`.** This is a prototype (see the login screen's own
/// notice); a per-person password would only be a list of numbers to remember during
/// a walkthrough. The login form pre-fills Marc's PIN and `1234` for the same
/// reason the Phase 1 form pre-filled an email and password.
///
/// Nobody starts locked or with failed attempts — those states are produced by
/// `CredentialMutations` during the walkthrough, not seeded.
final List<EmployeeCredential> mockCredentials = [
  for (final employee in mockEmployees)
    EmployeeCredential(
      id: 'cred-${employee.id}',
      employeeId: employee.id,
      passwordHash: fakePasswordHash('1234'),
    ),
];
