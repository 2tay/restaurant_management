import '../../models/models.dart';
import '../mock_notifications.dart';
import '../mock_queries.dart';
import '../mock_stores.dart';
import '../mock_team.dart';
import 'mock_write.dart';

/// Writes against the things that are about the account rather than the stock:
/// team members, the stores themselves, and the notification feed.
///
/// Grouped into one file because none of them is big enough to justify three,
/// and they share a shape — small records with no dependants to cascade to. If
/// any of them grows a real relationship, it should move out.
///
/// They are here at all for coherence. Once creating an article sticks, a team
/// member that silently does not is more confusing than either behaviour would
/// be on its own.
abstract final class AccountMutations {
  // ---------------------------------------------------------------------------
  // Team
  // ---------------------------------------------------------------------------

  /// Adds a member. Returns null if the email is already on the team.
  ///
  /// Email is the one field worth guarding: it is how a real invitation would
  /// be addressed in Phase 2, and two members sharing one would make that
  /// ambiguous.
  static TeamMember? invite({
    required String fullName,
    required String email,
    required TeamRole role,
    required List<String> storeIds,
  }) {
    final trimmedName = fullName.trim();
    final trimmedEmail = email.trim();
    if (trimmedName.isEmpty || trimmedEmail.isEmpty) return null;
    if (MockQueries.teamMemberByEmail(trimmedEmail) != null) return null;

    final member = TeamMember(
      id: MockWrite.id('user'),
      fullName: trimmedName,
      email: trimmedEmail,
      role: role,
      storeIds: List.of(storeIds),
      isActive: true,
      invitedAt: DateTime.now(),
      lastActiveAt: null,
    );

    mockTeam.add(member);
    MockWrite.changed();
    return member;
  }

  static TeamMember? updateMember(
    String id, {
    String? fullName,
    String? email,
    TeamRole? role,
    List<String>? storeIds,
    bool? isActive,
  }) {
    final index = mockTeam.indexWhere((member) => member.id == id);
    if (index == -1) return null;

    final existing = mockTeam[index];
    final trimmedEmail = email?.trim();
    if (trimmedEmail != null &&
        MockQueries.teamMemberByEmail(trimmedEmail, excludingId: id) != null) {
      return null;
    }

    final updated = TeamMember(
      id: existing.id,
      fullName: fullName?.trim() ?? existing.fullName,
      email: trimmedEmail ?? existing.email,
      role: role ?? existing.role,
      storeIds: storeIds == null ? existing.storeIds : List.of(storeIds),
      isActive: isActive ?? existing.isActive,
      invitedAt: existing.invitedAt,
      lastActiveAt: existing.lastActiveAt,
    );

    mockTeam[index] = updated;
    MockWrite.changed();
    return updated;
  }

  /// Removes a member.
  ///
  /// Refuses to remove the last owner. An account nobody can administer is not
  /// a state worth being able to reach by accident, and there is no recovery
  /// path from inside the app.
  static bool removeMember(String id) {
    final member = MockQueries.teamMemberById(id);
    if (member == null) return false;

    if (member.role == TeamRole.owner && MockQueries.ownerCount() <= 1) {
      return false;
    }

    mockTeam.removeWhere((candidate) => candidate.id == id);
    MockWrite.changed();
    return true;
  }

  /// True when this member is the only owner left, so the screen can explain
  /// before it offers to remove them.
  static bool isLastOwner(String id) {
    final member = MockQueries.teamMemberById(id);
    return member != null &&
        member.role == TeamRole.owner &&
        MockQueries.ownerCount() <= 1;
  }

  // ---------------------------------------------------------------------------
  // Stores
  // ---------------------------------------------------------------------------

  /// Opens a new location.
  ///
  /// It starts with no categories, units, items or suppliers, which is correct
  /// rather than lazy: those are per-store by design, and a new shop's
  /// catalogue is not the old shop's. Every empty state in the app is what the
  /// user sees next.
  static Store createStore({
    required String name,
    required String addressLine,
    required String postalCode,
    required String city,
    required String phone,
  }) {
    final store = Store(
      id: MockWrite.id('store'),
      name: name.trim(),
      addressLine: addressLine.trim(),
      postalCode: postalCode.trim(),
      city: city.trim(),
      phone: phone.trim(),
      createdAt: DateTime.now(),
    );

    mockStores.add(store);
    MockWrite.changed();
    return store;
  }

  static Store? updateStore(
    String id, {
    String? name,
    String? addressLine,
    String? postalCode,
    String? city,
    String? phone,
  }) {
    final index = mockStores.indexWhere((store) => store.id == id);
    if (index == -1) return null;

    final existing = mockStores[index];
    final updated = Store(
      id: existing.id,
      name: name?.trim() ?? existing.name,
      addressLine: addressLine?.trim() ?? existing.addressLine,
      postalCode: postalCode?.trim() ?? existing.postalCode,
      city: city?.trim() ?? existing.city,
      phone: phone?.trim() ?? existing.phone,
      createdAt: existing.createdAt,
      imageAsset: existing.imageAsset,
    );

    mockStores[index] = updated;
    MockWrite.changed();
    return updated;
  }

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  /// Marks one notification read. No-op if it already was.
  static bool markRead(String id) {
    final index = mockNotifications.indexWhere((n) => n.id == id);
    if (index == -1) return false;

    final existing = mockNotifications[index];
    if (existing.isRead) return false;

    mockNotifications[index] = _asRead(existing);
    MockWrite.changed();
    return true;
  }

  /// Marks everything in a store read. Returns how many changed.
  ///
  /// Returning the count lets the screen say "7 notifications marquées comme
  /// lues" rather than a bare acknowledgement, and lets it stay quiet when
  /// there was nothing to do.
  static int markAllRead(String storeId) {
    var changed = 0;

    for (var i = 0; i < mockNotifications.length; i++) {
      final notification = mockNotifications[i];
      if (notification.storeId != storeId || notification.isRead) continue;
      mockNotifications[i] = _asRead(notification);
      changed++;
    }

    if (changed > 0) MockWrite.changed();
    return changed;
  }

  static NotificationItem _asRead(NotificationItem notification) {
    return NotificationItem(
      id: notification.id,
      storeId: notification.storeId,
      kind: notification.kind,
      title: notification.title,
      body: notification.body,
      createdAt: notification.createdAt,
      isRead: true,
      relatedItemId: notification.relatedItemId,
      relatedSupplierId: notification.relatedSupplierId,
    );
  }
}
