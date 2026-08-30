import '../../core/utils/credential_status.dart';
import '../../models/models.dart';
import '../mock_credentials.dart';
import '../mock_queries.dart';
import 'mock_write.dart';

/// How an [CredentialMutations.authenticate] call turned out.
enum LoginOutcome {
  /// CIN + PIN matched, the employee has app access — the caller signs them in.
  success,

  /// No employee carries this CIN.
  unknownCin,

  /// Wrong PIN (or no PIN on file). The failed-attempt counter has been bumped.
  wrongPin,

  /// The credential is locked — refused even though the PIN may be right.
  locked,

  /// PIN was correct, but the role is `staff`: no active app access
  /// (`.claude/phase_gestion_employee.md` — their pointage is done at the
  /// kiosk). Counters untouched.
  noAppAccess,
}

/// The result of an authentication attempt. [employee] is set whenever the CIN
/// resolved, whatever the [outcome] — the login screen uses it to name the
/// person in an error ("compte de Marc Delvaux verrouillé").
class LoginAttempt {
  const LoginAttempt(this.outcome, [this.employee]);

  final LoginOutcome outcome;
  final Employee? employee;
}

/// Writes against the login secrets — **the only file that writes
/// `mockCredentials`**, same single-writer discipline as every other aggregate.
///
/// Every method that changes the wall-clock-sensitive state takes an optional
/// [now] so tests can pin a moment instead of waiting for the lockout to
/// expire, the same posture `AttendanceMutations` takes.
abstract final class CredentialMutations {
  /// Sets (or replaces) this employee's PIN, clearing any failed attempts and
  /// lockout. Returns null if the PIN is not [AuthRules.pinLength] digits or
  /// the employee does not exist.
  static EmployeeCredential? setPin(String employeeId, String pin) {
    if (!isValidPin(pin)) return null;
    if (MockQueries.employeeById(employeeId) == null) return null;

    final replacement = EmployeeCredential(
      id: _idFor(employeeId),
      employeeId: employeeId,
      pinHash: fakePinHash(pin),
    );

    final index = mockCredentials.indexWhere((c) => c.employeeId == employeeId);
    if (index == -1) {
      mockCredentials.add(replacement);
    } else {
      mockCredentials[index] = replacement;
    }
    MockWrite.changed();
    return replacement;
  }

  /// Records one wrong PIN. Locks the credential for
  /// [AuthRules.lockoutDuration] once [AuthRules.maxFailedAttempts] is reached.
  /// Returns whether this attempt was the one that locked it.
  static bool recordFailedAttempt(String employeeId, {DateTime? now}) {
    final index = mockCredentials.indexWhere((c) => c.employeeId == employeeId);
    if (index == -1) return false;

    final at = now ?? DateTime.now();
    final current = mockCredentials[index];
    final attempts = current.failedAttempts + 1;
    final locks = attempts >= AuthRules.maxFailedAttempts;

    mockCredentials[index] = EmployeeCredential(
      id: current.id,
      employeeId: current.employeeId,
      pinHash: current.pinHash,
      failedAttempts: attempts,
      lockedUntil: locks
          ? at.add(AuthRules.lockoutDuration)
          : current.lockedUntil,
      lastLoginAt: current.lastLoginAt,
    );
    MockWrite.changed();
    return locks;
  }

  /// Clears the failed-attempt counter and lockout, and stamps [lastLoginAt].
  static void recordSuccessfulLogin(String employeeId, {DateTime? now}) {
    final index = mockCredentials.indexWhere((c) => c.employeeId == employeeId);
    if (index == -1) return;

    final current = mockCredentials[index];
    mockCredentials[index] = EmployeeCredential(
      id: current.id,
      employeeId: current.employeeId,
      pinHash: current.pinHash,
      lastLoginAt: now ?? DateTime.now(),
    );
    MockWrite.changed();
  }

  /// Lifts a lockout early — the "Débloquer" action a manager or owner would
  /// use. Returns false when there was nothing locked or counted.
  static bool unlock(String employeeId) {
    final index = mockCredentials.indexWhere((c) => c.employeeId == employeeId);
    if (index == -1) return false;

    final current = mockCredentials[index];
    if (current.failedAttempts == 0 && current.lockedUntil == null) return false;

    mockCredentials[index] = EmployeeCredential(
      id: current.id,
      employeeId: current.employeeId,
      pinHash: current.pinHash,
      lastLoginAt: current.lastLoginAt,
    );
    MockWrite.changed();
    return true;
  }

  /// The whole login check, composed from the primitives above. Does **not**
  /// touch [MockSession] — the login screen signs the user in on
  /// [LoginOutcome.success].
  static LoginAttempt authenticate(String cin, String pin, {DateTime? now}) {
    final employee = MockQueries.employeeByCin(cin.trim());
    if (employee == null) return const LoginAttempt(LoginOutcome.unknownCin);

    final credential = MockQueries.credentialForEmployee(employee.id);
    if (credential == null) return LoginAttempt(LoginOutcome.wrongPin, employee);

    if (isLocked(credential, now: now)) {
      return LoginAttempt(LoginOutcome.locked, employee);
    }

    if (!pinMatches(credential, pin)) {
      final locked = recordFailedAttempt(employee.id, now: now);
      return LoginAttempt(
        locked ? LoginOutcome.locked : LoginOutcome.wrongPin,
        employee,
      );
    }

    if (employee.role == EmployeeRole.staff) {
      return LoginAttempt(LoginOutcome.noAppAccess, employee);
    }

    recordSuccessfulLogin(employee.id, now: now);
    return LoginAttempt(LoginOutcome.success, employee);
  }

  /// Reuses the existing credential id for this employee, or mints a new one.
  static String _idFor(String employeeId) {
    for (final credential in mockCredentials) {
      if (credential.employeeId == employeeId) return credential.id;
    }
    return MockWrite.id('cred');
  }
}
