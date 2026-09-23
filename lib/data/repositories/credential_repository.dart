import 'package:drift/drift.dart';

import '../../core/utils/credential_status.dart';
import '../../models/employee.dart';
import '../../models/employee_credential.dart';
import '../database/app_database.dart';
import '../mappers/mappers.dart';
import 'employee_repository.dart';
import 'new_id.dart';

/// How a [CredentialRepository.authenticate] call turned out.
enum LoginOutcome {
  /// PIN + password matched, the employee has app access — the caller signs them in.
  success,

  /// No employee carries this PIN.
  unknownPin,

  /// Wrong password (or no password on file). The failed-attempt counter has been bumped.
  wrongPassword,

  /// The credential is locked — refused even though the password may be right.
  locked,

  /// The role is `staff`: no active app access (their pointage is done at the
  /// kiosk), whatever password was typed — an Employé holds none. Counters
  /// untouched.
  noAppAccess,
}

/// The result of an authentication attempt. [employee] is set whenever the PIN
/// resolved, whatever the [outcome] — the login screen uses it to name the
/// person in an error ("compte de Marc Delvaux verrouillé").
class LoginAttempt {
  const LoginAttempt(this.outcome, [this.employee]);

  final LoginOutcome outcome;
  final Employee? employee;
}

/// The login secret and lockout state behind an employee's PIN.
///
/// **The only file that writes `employee_credentials`** — same single-writer
/// discipline as every other aggregate, and the `ux_audit.py` guard enforces
/// it.
///
/// Every method that changes wall-clock-sensitive state takes an optional [now]
/// so a test can pin a moment instead of waiting for a lockout to expire — the
/// same posture `AttendanceRepository` takes for the pointage.
class CredentialRepository {
  const CredentialRepository(this._db);

  final AppDatabase _db;

  /// This employee's credential, or null when no password has been set.
  Future<EmployeeCredential?> forEmployee(String employeeId) =>
      _rowFor(employeeId).then(
        (row) => row == null ? null : credentialFromRow(row),
      );

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Sets (or replaces) this employee's password, clearing any failed attempts and
  /// lockout. Returns null if the password is not [AuthRules.passwordLength] digits or
  /// the employee does not exist.
  Future<EmployeeCredential?> setPassword(String employeeId, String password) async {
    if (!isValidPassword(password)) return null;

    return _db.transaction(() async {
      final employeeExists =
          await (_db.select(_db.employees)
                ..where((e) => e.id.equals(employeeId)))
              .getSingleOrNull() !=
          null;
      if (!employeeExists) return null;

      final current = await _rowFor(employeeId);
      final replacement = EmployeeCredential(
        id: current?.id ?? newId(),
        employeeId: employeeId,
        passwordHash: fakePasswordHash(password),
      );

      if (current == null) {
        await _db
            .into(_db.employeeCredentials)
            .insert(credentialToRow(replacement));
      } else {
        // A full write, so `failedAttempts` / `lockedUntil` / `lastLoginAt` all
        // return to their defaults — a fresh password wipes the lockout state.
        await (_db.update(_db.employeeCredentials)
              ..where((c) => c.employeeId.equals(employeeId)))
            .write(credentialToRow(replacement));
      }
      return replacement;
    });
  }

  /// Records one wrong password. Locks the credential for
  /// [AuthRules.lockoutDuration] once [AuthRules.maxFailedAttempts] is reached.
  /// Returns whether this attempt was the one that locked it.
  Future<bool> recordFailedAttempt(String employeeId, {DateTime? now}) {
    return _db.transaction(() async {
      final current = await _rowFor(employeeId);
      if (current == null) return false;

      final at = now ?? DateTime.now();
      final attempts = current.failedAttempts + 1;
      final locks = attempts >= AuthRules.maxFailedAttempts;

      await (_db.update(_db.employeeCredentials)
            ..where((c) => c.employeeId.equals(employeeId)))
          .write(
            EmployeeCredentialsCompanion(
              failedAttempts: Value(attempts),
              lockedUntil: locks
                  ? Value(at.add(AuthRules.lockoutDuration))
                  : const Value.absent(),
            ),
          );
      return locks;
    });
  }

  /// Clears the failed-attempt counter and lockout, and stamps `lastLoginAt`.
  /// Does nothing when there is no credential.
  Future<void> recordSuccessfulLogin(String employeeId, {DateTime? now}) async {
    await (_db.update(_db.employeeCredentials)
          ..where((c) => c.employeeId.equals(employeeId)))
        .write(
          EmployeeCredentialsCompanion(
            failedAttempts: const Value(0),
            lockedUntil: const Value(null),
            lastLoginAt: Value(now ?? DateTime.now()),
          ),
        );
  }

  /// Removes this employee's login credential altogether — they can no longer
  /// sign in. What a change to the Employé role does: an Employé never signs
  /// in, so nothing is kept for them. Returns whether there was one to remove.
  Future<bool> clear(String employeeId) async {
    final removed = await (_db.delete(
      _db.employeeCredentials,
    )..where((c) => c.employeeId.equals(employeeId))).go();
    return removed > 0;
  }

  /// Lifts a lockout early — the "Débloquer" action a manager or owner takes.
  /// Returns false when there was nothing locked or counted.
  Future<bool> unlock(String employeeId) {
    return _db.transaction(() async {
      final current = await _rowFor(employeeId);
      if (current == null) return false;
      if (current.failedAttempts == 0 && current.lockedUntil == null) {
        return false;
      }

      await (_db.update(_db.employeeCredentials)
            ..where((c) => c.employeeId.equals(employeeId)))
          .write(
            const EmployeeCredentialsCompanion(
              failedAttempts: Value(0),
              lockedUntil: Value(null),
            ),
          );
      return true;
    });
  }

  /// The whole login check, composed from the primitives above.
  ///
  /// **Does not touch the session** — the login screen (stage 9) signs the user
  /// in on [LoginOutcome.success].
  Future<LoginAttempt> authenticate(
    String pin,
    String password, {
    DateTime? now,
  }) async {
    final employee = await EmployeeRepository(_db).employeeByPin(pin.trim());
    if (employee == null) return const LoginAttempt(LoginOutcome.unknownPin);

    // An Employé never has app access — and, since the role holds no password
    // at all, the answer must not depend on what was typed. Nothing counted.
    if (employee.role == EmployeeRole.staff) {
      return LoginAttempt(LoginOutcome.noAppAccess, employee);
    }

    final credential = await forEmployee(employee.id);
    if (credential == null) {
      return LoginAttempt(LoginOutcome.wrongPassword, employee);
    }

    if (isLocked(credential, now: now)) {
      return LoginAttempt(LoginOutcome.locked, employee);
    }

    if (!passwordMatches(credential, password)) {
      final locked = await recordFailedAttempt(employee.id, now: now);
      return LoginAttempt(
        locked ? LoginOutcome.locked : LoginOutcome.wrongPassword,
        employee,
      );
    }

    await recordSuccessfulLogin(employee.id, now: now);
    return LoginAttempt(LoginOutcome.success, employee);
  }

  /// Confirms that whoever is at the screen is [expectedEmployeeId], by asking
  /// for that person's PIN — the check the pointage board runs before every
  /// action and the payroll screen runs before "Payer". Strict: the PIN must
  /// resolve to exactly [expectedEmployeeId] (the card, or the signed-in user);
  /// any other PIN, valid or not, counts as wrong.
  ///
  /// Unlimited attempts, no lockout, and no credential row needed: this is a
  /// "who is at the screen" check, not a login, so it reads and writes none of
  /// the login lockout state [authenticate] keeps — a miss here never locks
  /// anybody out of signing in, and a hit never clears a login lockout.
  Future<bool> verifyPin(String pin, String expectedEmployeeId) async {
    final match = await EmployeeRepository(_db).employeeByPin(pin.trim());
    return match != null && match.id == expectedEmployeeId;
  }

  // ---------------------------------------------------------------------------

  Future<EmployeeCredentialRow?> _rowFor(String employeeId) =>
      (_db.select(_db.employeeCredentials)
            ..where((c) => c.employeeId.equals(employeeId)))
          .getSingleOrNull();
}
