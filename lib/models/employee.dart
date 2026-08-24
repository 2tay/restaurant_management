/// What an employee is paid on.
enum EmployeeType {
  /// Salarié fixe — a permanent, salaried staff member.
  fixedSalary,

  /// Étudiant — a student contract.
  student,

  /// Extra — casual, shift-by-shift staff.
  extra,
}

/// How [Employee.payRate] is interpreted.
enum PayType {
  /// [Employee.payRate] is a monthly salary, in euros.
  monthlySalary,

  /// [Employee.payRate] is an hourly rate, in euros per hour.
  hourlyRate,
}

/// A member of staff at one store.
///
/// Immutable, no logic — same contract as every other model. Soft-removed
/// only: [archivedAt] is the single source of truth for whether this person is
/// still active, the same reasoning as `PurchaseOrderLine.closedShort` being
/// the only signal of a shortfall rather than a second flag that could
/// disagree with it. See `core/utils/employee_status.dart` for the derivation.
class Employee {
  const Employee({
    required this.id,
    required this.storeId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.address,
    required this.cin,
    required this.type,
    required this.payType,
    required this.payRate,
    required this.createdAt,
    this.photoAsset,
    this.archivedAt,
    this.teamMemberId,
  });

  final String id;
  final String storeId;
  final String fullName;
  final String email;
  final String phone;
  final String address;

  /// Carte d'identité nationale — the identity document number kept on file.
  final String cin;

  /// Optional photo. Mocked, same as `Store.imageAsset`: a nullable
  /// asset-path string with no picker plumbing behind it. Null renders an
  /// initials tile.
  final String? photoAsset;

  final EmployeeType type;
  final PayType payType;

  /// Interpreted per [payType] — a monthly amount in euros, or an hourly rate
  /// in euros per hour.
  final double payRate;

  final DateTime createdAt;

  /// Null while active. Set once, by `EmployeeMutations.archive`, and never
  /// cleared from inside the app — there is no hard delete.
  final DateTime? archivedAt;

  /// Links this person to their `TeamMember` — their application account —
  /// when they have one. Null for most employees: attendance and pay do not
  /// require the app, and a dishwasher clocking in has no reason to ever log
  /// in.
  ///
  /// Owned by this field rather than by a matching field on [TeamMember],
  /// the same direction `StockMovement` points at the order it came from
  /// rather than the other way round: the secondary record names the primary
  /// one, so removing the account is one place to clean up, not a list to
  /// search. See `EmployeeMutations.linkTeamMember` and `.clearTeamMemberLink`.
  final String? teamMemberId;
}
