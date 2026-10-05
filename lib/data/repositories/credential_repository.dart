import '../../models/employee.dart';
import '../database/app_database.dart';
import 'employee_repository.dart';

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

/// Who may sign in, and who is at the screen — both answered from the
/// employees themselves: the email names the person, the PIN (their CIN) is
/// the secret. Nothing is stored for a login (schema v22 dropped the
/// password table), so nothing here writes.
class CredentialRepository {
  const CredentialRepository(this._db);

  final AppDatabase _db;

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
  /// Unlimited attempts, no lockout: this is a "who is at the screen" check,
  /// not a login.
  Future<bool> verifyPin(String pin, String expectedEmployeeId) async {
    // Against the expected person's own PIN, not a lookup: the same CIN can
    // sit on two people in two stores (rule E1), and the lookup returns one.
    final expected = await EmployeeRepository(
      _db,
    ).employee(expectedEmployeeId);
    return expected != null &&
        EmployeeRepository.sameIdentifier(expected.pin, pin);
  }
}
