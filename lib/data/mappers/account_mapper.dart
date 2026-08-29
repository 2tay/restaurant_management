import 'package:drift/drift.dart';

import '../../models/notification_item.dart';
import '../../models/team_member.dart';
import '../database/app_database.dart';

/// Takes the member's establishments separately: `TeamMember.storeIds` is a
/// `List<String>` on the model and a join table in the schema.
TeamMember teamMemberFromRow(TeamMemberRow row, List<String> storeIds) =>
    TeamMember(
      id: row.id,
      fullName: row.fullName,
      email: row.email,
      role: row.role,
      storeIds: storeIds,
      isActive: row.isActive,
      invitedAt: row.invitedAt,
      lastActiveAt: row.lastActiveAt,
    );

TeamMembersCompanion teamMemberToRow(TeamMember member) =>
    TeamMembersCompanion.insert(
      id: member.id,
      fullName: member.fullName,
      email: member.email,
      role: member.role,
      isActive: member.isActive,
      invitedAt: member.invitedAt,
      lastActiveAt: Value(member.lastActiveAt),
    );

/// One grant. The account repository rewrites the whole set for a member rather
/// than diffing it — the list is never longer than the number of establishments.
TeamMemberStoresCompanion teamMemberStoreToRow({
  required String memberId,
  required String storeId,
}) => TeamMemberStoresCompanion.insert(memberId: memberId, storeId: storeId);

NotificationItem notificationFromRow(NotificationRow row) => NotificationItem(
  id: row.id,
  storeId: row.storeId,
  kind: row.kind,
  title: row.title,
  body: row.body,
  createdAt: row.createdAt,
  isRead: row.isRead,
  relatedItemId: row.relatedItemId,
  relatedSupplierId: row.relatedSupplierId,
);

NotificationsCompanion notificationToRow(NotificationItem notification) =>
    NotificationsCompanion.insert(
      id: notification.id,
      storeId: notification.storeId,
      kind: notification.kind,
      title: notification.title,
      body: notification.body,
      createdAt: notification.createdAt,
      isRead: Value(notification.isRead),
      relatedItemId: Value(notification.relatedItemId),
      relatedSupplierId: Value(notification.relatedSupplierId),
    );
