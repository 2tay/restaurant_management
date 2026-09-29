import '../../../models/employee.dart';
import '../../../models/employee_credential.dart';
import 'employees.dart';

/// Login secrets — one per owner and manager, so any PIN a demo types for
/// someone who can sign in resolves to
/// something rather than a dead end.
///
/// **Every password is `1234`.** This is a prototype (see the login screen's own
/// notice); a per-person password would only be a list of numbers to remember during
/// a walkthrough. The login form pre-fills Marc's PIN and `1234` for the same
/// reason the Phase 1 form pre-filled an email and password.
///
/// Nobody starts locked or with failed attempts — those states are produced by
/// `CredentialMutations` during the walkthrough, not seeded.
/// `1234`, hashed once and written down.
///
/// The same PBKDF2 hash `passwordHashOf('1234')` would produce, but with a
/// fixed salt so it can be a constant: hashing is deliberately slow, and every
/// test that seeds the demo would otherwise pay for it once per manager. A
/// fixed salt is harmless for a password printed on the login screen; real
/// passwords get a random one.
const String demoPasswordHash =
    r'pbkdf2-sha256$60000$AwoRGB8mLTQ7QklQV15lbA==$'
    r'wz4ctIKCF7VdVco5rgxzyJGhd9mYO7pEnkTOSD2Z+2U=';

final List<EmployeeCredential> mockCredentials = [
  for (final employee in mockEmployees)
    // An Employé never signs in (their pointage is at the kiosk, with their
    // PIN), so they have no login secret — the same rule the employee form
    // applies.
    if (employee.role != EmployeeRole.staff)
      EmployeeCredential(
        id: 'cred-${employee.id}',
        employeeId: employee.id,
        passwordHash: demoPasswordHash,
      ),
];
