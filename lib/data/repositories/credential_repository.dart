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
  /// CIN + PIN matched, the employee has app access — the caller signs them in.
  success,

  /// No employee carries this CIN.
  unknownCin,

  /// Wrong PIN (or no PIN on file). The failed-attempt counter has been bumped.
  wrongPin,

  /// The credential is locked — refused even though the PIN may be right.
  locked,

  /// PIN was correct, but the role is `staff`: no active app access
  /// (their pointage is done at the kiosk). Counters untouched.
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

/// How a [CredentialRepository.verifyPin] check turned out — the re-auth the
/// pointage board asks for on every action, and the payroll screen asks for
/// before settling days. Unlike [LoginOutcome] there is no CIN and no role
/// gate: the caller already knows which employee it is asking about.
enum PinCheckResult {
  /// The PIN matched. Counters were reset.
  ok,

  /// Wrong PIN. The failed-attempt counter has been bumped —
  /// [PinVerification.attemptsRemaining] says how many are left.
  wrongPin,

  /// Locked out — refused even with the right PIN until
  /// [PinVerification.lockedUntil] passes.
  locked,

  /// No PIN on file for this employee. Nothing was counted.
  noPin,
}

/// The outcome of one [CredentialRepository.verifyPin] call, with the extra
/// figures the PIN dialog shows ("2 tentatives restantes", a lockout
/// countdown).
class PinVerification {
  const PinVerification(
    this.result, {
    this.lockedUntil,
    this.attemptsRemaining = 0,
  });

  final PinCheckResult result;

  /// Set when [result] is [PinCheckResult.locked].
  final DateTime? lockedUntil;

  /// Set when [result] is [PinCheckResult.wrongPin] — how many attempts are
  /// left before the lockout.
  final int attemptsRemaining;
}

/// The login secret and lockout state behind an employee's CIN.
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

  /// This employee's credential, or null when no PIN has been set.
  Future<EmployeeCredential?> forEmployee(String employeeId) =>
      _rowFor(employeeId).then(
        (row) => row == null ? null : credentialFromRow(row),
      );

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Sets (or replaces) this employee's PIN, clearing any failed attempts and
  /// lockout. Returns null if the PIN is not [AuthRules.pinLength] digits or
  /// the employee does not exist.
  Future<EmployeeCredential?> setPin(String employeeId, String pin) async {
    if (!isValidPin(pin)) return null;

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
        pinHash: fakePinHash(pin),
      );

      if (current == null) {
        await _db
            .into(_db.employeeCredentials)
            .insert(credentialToRow(replacement));
      } else {
        // A full write, so `failedAttempts` / `lockedUntil` / `lastLoginAt` all
        // return to their defaults — a fresh PIN wipes the lockout state.
        await (_db.update(_db.employeeCredentials)
              ..where((c) => c.employeeId.equals(employeeId)))
            .write(credentialToRow(replacement));
      }
      return replacement;
    });
  }

  /// Records one wrong PIN. Locks the credential for
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
    String cin,
    String pin, {
    DateTime? now,
  }) async {
    final employee = await EmployeeRepository(_db).employeeByCin(cin.trim());
    if (employee == null) return const LoginAttempt(LoginOutcome.unknownCin);

    final credential = await forEmployee(employee.id);
    if (credential == null) {
      return LoginAttempt(LoginOutcome.wrongPin, employee);
    }

    if (isLocked(credential, now: now)) {
      return LoginAttempt(LoginOutcome.locked, employee);
    }

    if (!pinMatches(credential, pin)) {
      final locked = await recordFailedAttempt(employee.id, now: now);
      return LoginAttempt(
        locked ? LoginOutcome.locked : LoginOutcome.wrongPin,
        employee,
      );
    }

    if (employee.role == EmployeeRole.staff) {
      return LoginAttempt(LoginOutcome.noAppAccess, employee);
    }

    await recordSuccessfulLogin(employee.id, now: now);
    return LoginAttempt(LoginOutcome.success, employee);
  }

  /// Re-authenticates one known employee by PIN — the check the pointage board
  /// runs before every action and the payroll screen runs before "Payer".
  ///
  /// Same lockout state machine as [authenticate] (three wrong PINs → locked
  /// for [AuthRules.lockoutDuration]), with one difference the kiosk needs: once
  /// a lockout has **elapsed**, the counter is wiped so the next try starts a
  /// fresh set of three, rather than the stale count re-locking on the first
  /// mistake. A success does not stamp `lastLoginAt` — this is not a login.
  Future<PinVerification> verifyPin(
    String employeeId,
    String pin, {
    DateTime? now,
  }) {
    return _db.transaction(() async {
      final at = now ?? DateTime.now();
      var row = await _rowFor(employeeId);
      if (row == null) return const PinVerification(PinCheckResult.noPin);

      // A lockout whose moment has passed: clear it so the employee gets the
      // full three attempts again.
      final until = row.lockedUntil;
      if (until != null && !at.isBefore(until)) {
        await _resetCounters(employeeId);
        row = await _rowFor(employeeId);
        if (row == null) return const PinVerification(PinCheckResult.noPin);
      }

      final credential = credentialFromRow(row);
      if (isLocked(credential, now: at)) {
        return PinVerification(
          PinCheckResult.locked,
          lockedUntil: credential.lockedUntil,
        );
      }

      if (!pinMatches(credential, pin)) {
        final locked = await recordFailedAttempt(employeeId, now: at);
        if (locked) {
          final after = await _rowFor(employeeId);
          return PinVerification(
            PinCheckResult.locked,
            lockedUntil: after?.lockedUntil,
          );
        }
        return PinVerification(
          PinCheckResult.wrongPin,
          attemptsRemaining:
              AuthRules.maxFailedAttempts - (credential.failedAttempts + 1),
        );
      }

      await _resetCounters(employeeId);
      return const PinVerification(PinCheckResult.ok);
    });
  }

  /// Clears the failed-attempt counter and lockout without touching
  /// `lastLoginAt` — the difference from [recordSuccessfulLogin].
  Future<void> _resetCounters(String employeeId) async {
    await (_db.update(_db.employeeCredentials)
          ..where((c) => c.employeeId.equals(employeeId)))
        .write(
          const EmployeeCredentialsCompanion(
            failedAttempts: Value(0),
            lockedUntil: Value(null),
          ),
        );
  }

  // ---------------------------------------------------------------------------

  Future<EmployeeCredentialRow?> _rowFor(String employeeId) =>
      (_db.select(_db.employeeCredentials)
            ..where((c) => c.employeeId.equals(employeeId)))
          .getSingleOrNull();
}
