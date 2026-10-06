import 'package:drift/drift.dart';

import '../../models/employee.dart';
import '../../models/notification_item.dart';
import '../database/app_database.dart';

/// [viewer] is whoever is looking: a signalement is read or not for each
/// person ([readByViewer], their row in `notification_reads`) — or for their
/// role, when it was read before schema v23 (`readByManagerAt`,
/// `readByOwnerAt`). Anything else, or no viewer, reads `is_read`.
NotificationItem notificationFromRow(
  NotificationRow row, {
  NotificationViewer? viewer,
  bool readByViewer = false,
}) => NotificationItem(
  id: row.id,
  storeId: row.storeId,
  kind: row.kind,
  title: row.title,
  body: row.body,
  createdAt: row.createdAt,
  isRead: switch ((row.kind, viewer?.role)) {
    (NotificationKind.personnel, EmployeeRole.owner) =>
      readByViewer || row.readByOwnerAt != null,
    (NotificationKind.personnel, EmployeeRole _) =>
      readByViewer || row.readByManagerAt != null,
    _ => row.isRead,
  },
  relatedItemId: row.relatedItemId,
  relatedSupplierId: row.relatedSupplierId,
  relatedEmployeeId: row.relatedEmployeeId,
  relatedTarget: row.relatedTarget,
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
      relatedEmployeeId: Value(notification.relatedEmployeeId),
      relatedTarget: Value(notification.relatedTarget),
    );
