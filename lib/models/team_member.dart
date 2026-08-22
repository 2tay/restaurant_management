/// What a team member is allowed to do.
///
/// Deliberately only three. A restaurant is not an enterprise, and a
/// permissions matrix nobody understands is worse than none.
enum TeamRole {
  /// Full access to every store on the account, including billing and team.
  owner,

  /// Full access to the stores they are assigned to, except account settings.
  manager,

  /// Can record deliveries and usage, and read inventory. Cannot delete items,
  /// manage suppliers, or see reports.
  staff,
}

/// Somebody with access to one or more stores.
class TeamMember {
  const TeamMember({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.storeIds,
    required this.isActive,
    required this.invitedAt,
    this.lastActiveAt,
  });

  final String id;
  final String fullName;
  final String email;
  final TeamRole role;

  /// Which stores this person can see. An owner holds all of them.
  final List<String> storeIds;

  /// False while an invitation is still outstanding.
  final bool isActive;

  final DateTime invitedAt;
  final DateTime? lastActiveAt;
}
