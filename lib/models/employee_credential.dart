/// One employee's login secret and lockout state.
///
/// The counterpart to [Employee] that Phase 6 adds: the CIN on the employee is
/// the login identifier, this carries the PIN behind it. Split onto its own
/// record — not a field on `Employee` — for the same reason `EmployeeCredential`
/// is its own aggregate in `.claude/phase_gestion_employee.md` §3: a rate
/// change and a failed-login counter have nothing to do with each other and
/// should not force each other to be rewritten.
///
/// Immutable, no logic — same contract as every other model. [pinHash] is a
/// **fake** hash (see `core/utils/credential_status.dart`): Phase 6 stays
/// offline and unencrypted on purpose, it just never stores the PIN in the
/// clear so the shape matches what a real backend would hold.
class EmployeeCredential {
  const EmployeeCredential({
    required this.id,
    required this.employeeId,
    required this.pinHash,
    this.failedAttempts = 0,
    this.lockedUntil,
    this.lastLoginAt,
  });

  final String id;
  final String employeeId;

  /// Never the PIN itself. See `fakePinHash`.
  final String pinHash;

  /// Consecutive wrong PINs since the last success. Reset to zero on a correct
  /// PIN or a fresh [pinHash].
  final int failedAttempts;

  /// Set once [failedAttempts] reaches the threshold — login is refused, even
  /// with the right PIN, until this moment passes.
  final DateTime? lockedUntil;

  final DateTime? lastLoginAt;
}
