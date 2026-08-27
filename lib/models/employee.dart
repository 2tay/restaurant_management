/// What a person is allowed to do in the app.
///
/// Deliberately only three, same reasoning the old `TeamRole` carried: a
/// restaurant is not an enterprise, and a permissions matrix nobody
/// understands is worse than none. Enforcement lands in Phase 6 — until then
/// the role is stored and displayed but gates nothing.
enum EmployeeRole {
  /// Propriétaire — full access to every store on the account, including
  /// payroll and staff management.
  owner,

  /// Gérant — runs the store day to day: the pointage board, attendance
  /// history, marking absences. No payroll, no staff management.
  manager,

  /// Employé — has no active access to the app. Their pointage is done for
  /// them at the shared kiosk by an owner or a manager.
  staff,
}

/// How a person is engaged, which decides how [Employee.pay] is read.
enum ContractType {
  /// Salarié fixe — a monthly [Employee.pay]. An unjustified absence is a
  /// deduction against it.
  fixed,

  /// Extra — an hourly [Employee.pay]. Paid only for hours actually worked;
  /// absence does not apply.
  extra,
}

/// A member of staff at one store.
///
/// This is the single "person" model for the app: it carries both the
/// employment facts (contract, pay, CIN) and the application access
/// ([role]) that the removed `TeamMember` used to hold separately. One store
/// per person — see `.claude/phase_gestion_employee.md` decision 2; an owner
/// spans stores by navigating between them, not by a list on this record.
///
/// Immutable, no logic — same contract as every other model. Soft-removed
/// only: [archivedAt] is the single source of truth for whether this person
/// is still active, the same reasoning as `PurchaseOrderLine.closedShort`
/// being the only signal of a shortfall. See
/// `core/utils/employee_status.dart` for the derivations.
class Employee {
  const Employee({
    required this.id,
    required this.storeId,
    required this.firstName,
    required this.lastName,
    required this.cin,
    required this.phone,
    required this.email,
    required this.hireDate,
    required this.role,
    required this.contractType,
    required this.pay,
    required this.createdAt,
    this.photoAsset,
    this.scheduledStartMinutes,
    this.scheduledEndMinutes,
    this.archivedAt,
  });

  final String id;
  final String storeId;

  final String firstName;
  final String lastName;

  /// Carte d'identité nationale — the identity document number kept on file.
  /// Unique account-wide, and the future login identifier (Phase 6).
  final String cin;

  final String phone;

  /// Unique account-wide.
  final String email;

  /// Optional photo. Mocked, same as `Store.imageAsset`: a nullable
  /// asset-path string with no picker plumbing behind it. Null renders an
  /// initials tile.
  final String? photoAsset;

  final DateTime hireDate;

  final EmployeeRole role;
  final ContractType contractType;

  /// Read per [contractType] — a monthly amount in euros when `fixed`, an
  /// hourly rate in euros per hour when `extra`.
  final double pay;

  /// Minutes since midnight for this person's own start / end of day. Null
  /// means "use the store's opening hours" — the resolved schedule is what
  /// lateness and overtime are measured against (Phase 3). Stored as an int
  /// rather than a `TimeOfDay` so the model stays pure Dart.
  final int? scheduledStartMinutes;
  final int? scheduledEndMinutes;

  final DateTime createdAt;

  /// Null while active. Set by `EmployeeMutations.archive`, cleared by
  /// `.restore`. There is no hard delete.
  final DateTime? archivedAt;
}
