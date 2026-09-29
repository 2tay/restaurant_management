import 'package:clock/clock.dart';

import '../../models/models.dart';
import 'password_hash.dart';

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

/// What gets stored for [password]: a salted PBKDF2 hash (see [PasswordHash]).
///
/// It replaced a fake `password:1234` marker in schema version 15, before
/// credentials start leaving the device with sync. The upgrade converts the
/// old values, so nobody has to choose a new password.
String passwordHashOf(String password) => PasswordHash.hash(password.trim());

/// Whether [password] is the one behind this credential.
bool passwordMatches(EmployeeCredential credential, String password) =>
    PasswordHash.verify(password.trim(), credential.passwordHash);

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
  return (now ?? clock.now()).isBefore(until);
}
