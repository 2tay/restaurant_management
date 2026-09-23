import '../../models/models.dart';

/// The login rules, and the derivations over [EmployeeCredential].
///
/// Same role `attendance_status.dart` plays for a day and `payroll_math.dart`
/// for a payslip: the arithmetic the auth flow is written against, kept off the
/// model so it stays plain data, and out of the screens so the login form and
/// the mutation agree.
abstract final class AuthRules {
  /// Every password is exactly this many digits.
  static const int passwordLength = 4;

  /// Consecutive wrong passwords that trip the lockout.
  static const int maxFailedAttempts = 3;

  /// How long a locked credential stays locked.
  static const Duration lockoutDuration = Duration(minutes: 5);
}

/// **Not a real hash.** Phase 6 stays offline and fake
/// (`.claude/phase_gestion_employee.md` decision 3) — this exists only so the
/// password is never stored or compared in the clear, matching the shape a real
/// backend would keep.
String fakePasswordHash(String password) => 'password:${password.trim()}';

/// Whether [password] is the one behind this credential.
bool passwordMatches(EmployeeCredential credential, String password) =>
    credential.passwordHash == fakePasswordHash(password);

/// Whether [password] is a syntactically valid password — [AuthRules.passwordLength] digits.
bool isValidPassword(String password) {
  final trimmed = password.trim();
  return trimmed.length == AuthRules.passwordLength &&
      RegExp(r'^\d+$').hasMatch(trimmed);
}

/// Whether the credential is locked right now — login is refused until
/// [EmployeeCredential.lockedUntil] passes, even with the correct password.
bool isLocked(EmployeeCredential credential, {DateTime? now}) {
  final until = credential.lockedUntil;
  if (until == null) return false;
  return (now ?? DateTime.now()).isBefore(until);
}
