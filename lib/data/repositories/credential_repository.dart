import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

import '../../core/utils/credential_status.dart';
import '../../models/employee.dart';
import '../../models/employee_credential.dart';
import '../database/app_database.dart';
import '../mappers/mappers.dart';
import 'employee_repository.dart';
import 'new_id.dart';
import 'soft_delete.dart';

/// How a [CredentialRepository.authenticate] call turned out.
enum LoginOutcome {
  /// Email + PIN matched, the employee has app access — the caller signs them in.
  success,

  /// No employee carries this email.
  unknownEmail,

  /// The email is known, but nobody with it carries this PIN.
  wrongPin,

  /// The role is `staff`: no active app access (their pointage is done at the
  /// kiosk).
  noAppAccess,

  /// The employee is archived (retired): their record stays on file, but it
  /// no longer opens the app.
  archived,
}

/// The result of an authentication attempt. [employee] is set once the email
/// and the PIN matched somebody, whatever the [outcome].
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
/// Every method that changes wall-clock-sensitive state takes an optional `now`
/// so a test can pin a moment instead of waiting for a lockout to expire — the
/// same posture `AttendanceRepository` takes for the pointage.
class CredentialRepository {
  const CredentialRepository(this._db);

  final AppDatabase _db;

  /// This employee's credential, or null when no password has been set. The
  /// attempts and lockout are this tablet's.
  Future<EmployeeCredential?> forEmployee(String employeeId) async {
    final row = await _rowFor(employeeId);
    if (row == null) return null;
    return credentialFromRow(row, await _stateFor(employeeId));
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Sets (or replaces) this employee's password, clearing any failed attempts and
  /// lockout on this tablet (another tablet clears its own when the password
  /// reaches it — `SyncApplier`). Returns null if the password is not
  /// [AuthRules.passwordLength] digits or the employee does not exist.
  Future<EmployeeCredential?> setPassword(String employeeId, String password) async {
    if (!isValidPassword(password)) return null;

    return _db.transaction(() async {
      final employee = await (_db.select(
        _db.employees,
      )..where((e) => e.id.equals(employeeId) & e.deletedAt.isNull())).getSingleOrNull();
      if (employee == null) return null;

      // Including a credential removed by [clear]: it is still in the table,
      // marked deleted, and there is one row per employee, so a new password
      // brings that row back rather than adding a second.
      final current = await _rowFor(employeeId, includeDeleted: true);
      final replacement = EmployeeCredential(
        id: current?.id ?? newId(),
        employeeId: employeeId,
        passwordHash: passwordHashOf(password),
      );

      if (current == null) {
        await _db
            .into(_db.employeeCredentials)
            .insert(credentialToRow(replacement, storeId: employee.storeId));
      } else {
        await (_db.update(_db.employeeCredentials)
              ..where((c) => c.employeeId.equals(employeeId)))
            .write(
              credentialToRow(
                replacement,
                storeId: employee.storeId,
              ).copyWith(deletedAt: const Value(null)),
            );
      }
      // A fresh password wipes the lockout, and keeps the last login.
      await resetAttempts(employeeId);
      return replacement;
    });
  }

  /// Records one wrong password. Locks the credential for
  /// [AuthRules.lockoutDuration] once [AuthRules.maxFailedAttempts] is reached.
  /// Returns whether this attempt was the one that locked it.
  ///
  /// A lockout that has run out starts the count afresh: the miss right after
  /// it is the first of [AuthRules.maxFailedAttempts] again, not one more on
  /// top of the attempts that caused it — otherwise every later window would
  /// allow a single try.
  Future<bool> recordFailedAttempt(String employeeId, {DateTime? now}) {
    return _db.transaction(() async {
      if (await _rowFor(employeeId) == null) return false;
      final current = await _stateFor(employeeId);

      final at = now ?? clock.now();
      final until = current?.lockedUntil;
      final expired = until != null && !at.isBefore(until);
      final attempts = (expired ? 0 : current?.failedAttempts ?? 0) + 1;
      final locks = attempts >= AuthRules.maxFailedAttempts;

      await _db
          .into(_db.loginStates)
          .insertOnConflictUpdate(
            LoginStatesCompanion.insert(
              employeeId: employeeId,
              failedAttempts: Value(attempts),
              lockedUntil: locks
                  ? Value(at.add(AuthRules.lockoutDuration))
                  : expired
                  ? const Value(null)
                  : Value(until),
              lastLoginAt: Value(current?.lastLoginAt),
            ),
          );
      return locks;
    });
  }

  /// Clears the failed-attempt counter and lockout, and stamps `lastLoginAt`.
  /// Does nothing when there is no credential.
  Future<void> recordSuccessfulLogin(String employeeId, {DateTime? now}) async {
    if (await _rowFor(employeeId) == null) return;
    await _db
        .into(_db.loginStates)
        .insertOnConflictUpdate(
          // Every column given: on an existing row, the upsert only
          // rewrites what the companion holds.
          LoginStatesCompanion.insert(
            employeeId: employeeId,
            failedAttempts: const Value(0),
            lockedUntil: const Value(null),
            lastLoginAt: Value(now ?? clock.now()),
          ),
        );
  }

  /// Clears this tablet's failed attempts and lockout for [employeeId],
  /// keeping the last login. What a new password does.
  Future<void> resetAttempts(String employeeId) =>
      (_db.update(_db.loginStates)
            ..where((s) => s.employeeId.equals(employeeId)))
          .write(
            const LoginStatesCompanion(
              failedAttempts: Value(0),
              lockedUntil: Value(null),
            ),
          );

  /// Removes this employee's login credential altogether — they can no longer
  /// sign in. What a change to the Employé role does: an Employé never signs
  /// in, so nothing is kept for them. Returns whether there was one to remove.
  Future<bool> clear(String employeeId) async =>
      await SoftDelete(_db).credential(employeeId) > 0;

  /// The login check: the email names the person, their PIN (CIN) is the
  /// secret. No attempt is counted and nothing locks.
  ///
  /// The email may sit on two people in two stores (rule E1): the one whose
  /// PIN was typed is the one signing in. The archive and the role are only
  /// weighed once the PIN matched, so they reveal nothing about an email to
  /// somebody who does not know its PIN.
  ///
  /// **Does not touch the session** — the login screen signs the user in on
  /// [LoginOutcome.success].
  Future<LoginAttempt> authenticate(String email, String pin) async {
    final named = await EmployeeRepository(_db).employeesByEmail(email);
    if (named.isEmpty) return const LoginAttempt(LoginOutcome.unknownEmail);

    final employee = named
        .where((e) => EmployeeRepository.sameIdentifier(e.pin, pin))
        .firstOrNull;
    if (employee == null) return const LoginAttempt(LoginOutcome.wrongPin);

    if (employee.archivedAt != null) {
      return LoginAttempt(LoginOutcome.archived, employee);
    }
    if (employee.role == EmployeeRole.staff) {
      return LoginAttempt(LoginOutcome.noAppAccess, employee);
    }
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
    // Against the expected person's own PIN, not a lookup: the same CIN can
    // sit on two people in two stores (rule E1), and the lookup returns one.
    final expected = await EmployeeRepository(
      _db,
    ).employee(expectedEmployeeId);
    return expected != null &&
        EmployeeRepository.sameIdentifier(expected.pin, pin);
  }

  // ---------------------------------------------------------------------------

  Future<LoginStateRow?> _stateFor(String employeeId) => (_db.select(
    _db.loginStates,
  )..where((s) => s.employeeId.equals(employeeId))).getSingleOrNull();

  Future<EmployeeCredentialRow?> _rowFor(
    String employeeId, {
    bool includeDeleted = false,
  }) =>
      (_db.select(_db.employeeCredentials)..where(
            (c) => includeDeleted
                ? c.employeeId.equals(employeeId)
                : c.employeeId.equals(employeeId) & c.deletedAt.isNull(),
          ))
          .getSingleOrNull();
}
