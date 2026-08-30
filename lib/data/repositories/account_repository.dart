import 'package:drift/drift.dart';

import '../../core/utils/name_matching.dart';
import '../../models/notification_item.dart';
import '../../models/team_member.dart';
import '../database/app_database.dart';
import '../database/meta_keys.dart';
import '../mappers/mappers.dart';
import 'new_id.dart';

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
  // Writes — team
  // ---------------------------------------------------------------------------

  /// Adds a member. Returns null if the email is already on the team.
  ///
  /// A member and their establishment grants are two tables, so this is a
  /// transaction: a member row with no grants is somebody who can sign in and
  /// see nothing, which looks like a permissions bug rather than a half-finished
  /// write.
  Future<TeamMember?> invite({
    required String fullName,
    required String email,
    required TeamRole role,
    required List<String> storeIds,
  }) async {
    final trimmedName = fullName.trim();
    final trimmedEmail = email.trim();
    if (trimmedName.isEmpty || trimmedEmail.isEmpty) return null;

    return _db.transaction(() async {
      if (await teamMemberByEmail(trimmedEmail) != null) return null;

      final member = TeamMember(
        id: newId(),
        fullName: trimmedName,
        email: trimmedEmail,
        role: role,
        storeIds: List.of(storeIds),
        // Invited, never seen. `lastActiveAt` is what the team screen renders as
        // "jamais connecté", so it has to start null rather than at now.
        isActive: true,
        invitedAt: DateTime.now(),
        lastActiveAt: null,
      );

      await _db.into(_db.teamMembers).insert(teamMemberToRow(member));
      await _writeGrants(member.id, member.storeIds);
      return member;
    });
  }

  /// Edits a member. Returns null when the member is gone or the new email is
  /// already somebody else's.
  ///
  /// Every parameter is nullable and null means "leave it": the team screen has
  /// three separate controls that each change one field, and passing the whole
  /// record back would let two of them race.
  Future<TeamMember?> updateMember(
    String id, {
    String? fullName,
    String? email,
    TeamRole? role,
    List<String>? storeIds,
    bool? isActive,
  }) async {
    final trimmedEmail = email?.trim();

    return _db.transaction(() async {
      final existing = await teamMember(id);
      if (existing == null) return null;

      // Excluding itself, or saving a member without touching their address
      // would collide with the row being saved.
      if (trimmedEmail != null &&
          await teamMemberByEmail(trimmedEmail, excludingId: id) != null) {
        return null;
      }

      await (_db.update(_db.teamMembers)..where((m) => m.id.equals(id))).write(
        TeamMembersCompanion(
          fullName: fullName == null
              ? const Value.absent()
              : Value(fullName.trim()),
          email: trimmedEmail == null ? const Value.absent() : Value(trimmedEmail),
          role: role == null ? const Value.absent() : Value(role),
          isActive: isActive == null ? const Value.absent() : Value(isActive),
        ),
      );

      if (storeIds != null) await _writeGrants(id, storeIds);

      // Rebuilt rather than copied: `TeamMember` has no `copyWith`, and adding
      // one for a single caller would put a method on a model the PDF layer and
      // Phase 3 also read.
      return TeamMember(
        id: existing.id,
        fullName: fullName?.trim() ?? existing.fullName,
        email: trimmedEmail ?? existing.email,
        role: role ?? existing.role,
        storeIds: storeIds == null ? existing.storeIds : List.of(storeIds),
        isActive: isActive ?? existing.isActive,
        invitedAt: existing.invitedAt,
        lastActiveAt: existing.lastActiveAt,
      );
    });
  }

  /// Removes a member.
  ///
  /// Refuses to remove the last owner. An account nobody can administer is not a
  /// state worth being able to reach by accident, and there is no recovery path
  /// from inside the app. The check and the removal are one transaction, so two
  /// devices each removing one of the last two owners cannot both succeed.
  ///
  /// Their establishment grants go with them: `team_member_stores.memberId` is
  /// `ON DELETE CASCADE`.
  Future<bool> removeMember(String id) {
    return _db.transaction(() async {
      final member = await teamMember(id);
      if (member == null) return false;
      if (member.role == TeamRole.owner && await ownerCount() <= 1) return false;

      final removed = await (_db.delete(
        _db.teamMembers,
      )..where((m) => m.id.equals(id))).go();
      return removed > 0;
    });
  }

  /// True when this member is the only owner left, so the screen can explain
  /// before it offers to remove them.
  Future<bool> isLastOwner(String id) async {
    final member = await teamMember(id);
    if (member == null || member.role != TeamRole.owner) return false;
    return await ownerCount() <= 1;
  }

  // ---------------------------------------------------------------------------
  // Writes — notifications
  // ---------------------------------------------------------------------------

  /// Marks one notification read. False if it is missing or already was.
  ///
  /// The "already read" case is in the `WHERE` rather than in a read-then-write:
  /// the number of rows the statement touched is the answer, and one statement
  /// cannot report a change it did not make.
  Future<bool> markRead(String id) async {
    final changed =
        await (_db.update(_db.notifications)
              ..where((n) => n.id.equals(id) & n.isRead.equals(false)))
            .write(const NotificationsCompanion(isRead: Value(true)));
    return changed > 0;
  }

  /// Marks everything in an establishment read. Returns how many changed.
  ///
  /// The count lets the screen say "7 notifications marquées comme lues" rather
  /// than a bare acknowledgement, and lets it stay quiet when there was nothing
  /// to do.
  Future<int> markAllRead(String storeId) =>
      (_db.update(_db.notifications)..where(
            (n) => n.storeId.equals(storeId) & n.isRead.equals(false),
          ))
          .write(const NotificationsCompanion(isRead: Value(true)));

  // ---------------------------------------------------------------------------

  /// Rewrites a member's establishment grants.
  ///
  /// Replaced wholesale rather than diffed: the list is never longer than the
  /// number of establishments an account has, and the form hands back the whole
  /// set of ticked boxes.
  ///
  /// Deduplicated, because the grant table's primary key is the pair and a
  /// repeated id would fail the insert. Phase 1 stored the list as given and
  /// nothing noticed a duplicate.
  ///
  /// A store id that does not resolve fails here on the foreign key rather than
  /// being filtered out. The ids come from a list of real establishments; one
  /// that does not exist is a bug worth hearing about, not a grant to drop
  /// silently.
  Future<void> _writeGrants(String memberId, List<String> storeIds) async {
    await (_db.delete(
      _db.teamMemberStores,
    )..where((g) => g.memberId.equals(memberId))).go();

    final unique = storeIds.toSet();
    if (unique.isEmpty) return;

    await _db.batch((batch) {
      batch.insertAll(_db.teamMemberStores, [
        for (final storeId in unique)
          teamMemberStoreToRow(memberId: memberId, storeId: storeId),
      ]);
    });
  }

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
