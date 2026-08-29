import 'package:drift/drift.dart';

import '../../core/utils/name_matching.dart';
import '../../models/notification_item.dart';
import '../../models/team_member.dart';
import '../database/app_database.dart';
import '../database/meta_keys.dart';
import '../mappers/mappers.dart';

/// The team, and the notifications an establishment has raised.
///
/// Team members belong to the account rather than to an establishment; which
/// establishments they can see is the `team_member_stores` join table. Every
/// read here therefore has to put a member back together from two tables, which
/// it does with one left join and a group-by in Dart — one query, and it watches
/// both tables, so granting somebody a new establishment updates the team screen
/// even though only the join table changed.
class AccountRepository {
  const AccountRepository(this._db);

  final AppDatabase _db;

  // ---------------------------------------------------------------------------
  // Team
  // ---------------------------------------------------------------------------

  /// Every member of the account, in the order they were invited.
  Stream<List<TeamMember>> watchTeam() => _teamQuery().watch().map(_assemble);

  Future<List<TeamMember>> team() => _teamQuery().get().then(_assemble);

  Stream<List<TeamMember>> watchTeamForStore(String storeId) =>
      watchTeam().map((members) => _forStore(members, storeId));

  Future<List<TeamMember>> teamForStore(String storeId) async =>
      _forStore(await team(), storeId);

  Future<TeamMember?> teamMember(String id) async {
    final members = await team();
    for (final member in members) {
      if (member.id == id) return member;
    }
    return null;
  }

  /// The member already using this address, if any.
  ///
  /// Email is the one team field worth guarding: it is how a real invitation
  /// will be addressed in Phase 3, and two members sharing one makes that
  /// ambiguous. [excludingId] lets an edit ignore itself. Compared in Dart, for
  /// the reason in `core/utils/name_matching.dart`.
  Future<TeamMember?> teamMemberByEmail(
    String email, {
    String? excludingId,
  }) async {
    final needle = normaliseName(email);
    if (needle.isEmpty) return null;

    for (final member in await team()) {
      if (member.id == excludingId) continue;
      if (normaliseName(member.email) == needle) return member;
    }
    return null;
  }

  /// Who the app is acting as.
  ///
  /// A placeholder for real authentication, and deliberately an explicit one:
  /// every movement and every price change is stamped with this person's name,
  /// so "there is no current user" is not a state the app can be in. Phase 1
  /// resolved it as `mockTeam.first` when the library loaded, which was the same
  /// placeholder with nowhere to write it down.
  ///
  /// Read from `meta`, falling back to the first owner and then to the first
  /// member, so a database whose meta row went missing still writes a name
  /// somebody can recognise rather than an empty string.
  Future<TeamMember?> currentUser() async {
    final members = await team();
    if (members.isEmpty) return null;

    final stored = await (_db.select(
      _db.meta,
    )..where((m) => m.key.equals(MetaKeys.currentUserId))).getSingleOrNull();

    if (stored != null) {
      for (final member in members) {
        if (member.id == stored.value) return member;
      }
    }
    return members.firstWhere(
      (m) => m.role == TeamRole.owner,
      orElse: () => members.first,
    );
  }

  /// The name stamped on a movement or a price change when the caller does not
  /// supply one.
  Future<String> currentUserName() async =>
      (await currentUser())?.fullName ?? '';

  /// How many owners the account has left.
  ///
  /// Guards the removal of the last one: an account nobody can administer is not
  /// a state worth being able to reach by accident.
  Future<int> ownerCount() async {
    final count = _db.teamMembers.id.count();
    final query = _db.selectOnly(_db.teamMembers)
      ..addColumns([count])
      ..where(_db.teamMembers.role.equalsValue(TeamRole.owner));
    return (await query.getSingle()).read(count) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  /// Newest first.
  Stream<List<NotificationItem>> watchNotifications(String storeId) =>
      _notifications(storeId).watch().map(_toNotifications);

  Future<List<NotificationItem>> notifications(String storeId) =>
      _notifications(storeId).get().then(_toNotifications);

  Stream<int> watchUnreadCount(String storeId) {
    final (query, read) = _unreadQuery(storeId);
    return query.watchSingle().map(read);
  }

  Future<int> unreadNotificationCount(String storeId) async {
    final (query, read) = _unreadQuery(storeId);
    return read(await query.getSingle());
  }

  // ---------------------------------------------------------------------------

  JoinedSelectStatement<HasResultSet, dynamic> _teamQuery() =>
      _db.select(_db.teamMembers).join([
        leftOuterJoin(
          _db.teamMemberStores,
          _db.teamMemberStores.memberId.equalsExp(_db.teamMembers.id),
        ),
      ])..orderBy([
        OrderingTerm(expression: _db.teamMembers.invitedAt),
        OrderingTerm(expression: _db.teamMembers.id),
      ]);

  /// One row per member–establishment pair; folds them back into one member
  /// each, keeping the order the query returned them in.
  List<TeamMember> _assemble(List<TypedResult> rows) {
    final order = <String>[];
    final byId = <String, TeamMemberRow>{};
    final stores = <String, List<String>>{};

    for (final row in rows) {
      final member = row.readTable(_db.teamMembers);
      if (!byId.containsKey(member.id)) {
        byId[member.id] = member;
        order.add(member.id);
        stores[member.id] = <String>[];
      }
      final grant = row.readTableOrNull(_db.teamMemberStores);
      if (grant != null) stores[member.id]!.add(grant.storeId);
    }

    return order
        .map((id) => teamMemberFromRow(byId[id]!, stores[id]!))
        .toList();
  }

  List<TeamMember> _forStore(List<TeamMember> members, String storeId) =>
      members.where((m) => m.storeIds.contains(storeId)).toList();

  (JoinedSelectStatement<HasResultSet, dynamic>, int Function(TypedResult))
  _unreadQuery(String storeId) {
    final count = _db.notifications.id.count();
    final query = _db.selectOnly(_db.notifications)
      ..addColumns([count])
      ..where(
        _db.notifications.storeId.equals(storeId) &
            _db.notifications.isRead.equals(false),
      );
    return (query, (TypedResult row) => row.read(count) ?? 0);
  }

  SimpleSelectStatement<$NotificationsTable, NotificationRow> _notifications(
    String storeId,
  ) => _db.select(_db.notifications)
    ..where((n) => n.storeId.equals(storeId))
    ..orderBy([
      (n) => OrderingTerm(expression: n.createdAt, mode: OrderingMode.desc),
      (n) => OrderingTerm(expression: n.id, mode: OrderingMode.desc),
    ]);

  List<NotificationItem> _toNotifications(List<NotificationRow> rows) =>
      rows.map(notificationFromRow).toList();
}
