import 'package:drift/drift.dart';

import '../../models/employee.dart';
import '../../models/notification_item.dart';
import '../database/app_database.dart';

/// [viewer] is the role of whoever is looking: a signalement is read or not
/// for a manager and for the owner separately (`readByManagerAt`,
/// `readByOwnerAt`). Anything else, or no role, reads `is_read`.
NotificationItem notificationFromRow(
  NotificationRow row, {
  EmployeeRole? viewer,
}) => NotificationItem(
  id: row.id,
  storeId: row.storeId,
  kind: row.kind,
  title: row.title,
  body: row.body,
  createdAt: row.createdAt,
  isRead: switch ((row.kind, viewer)) {
    (NotificationKind.personnel, EmployeeRole.owner) =>
      row.readByOwnerAt != null,
    (NotificationKind.personnel, EmployeeRole.manager) =>
      row.readByManagerAt != null,
    _ => row.isRead,
  },
  relatedItemId: row.relatedItemId,
  relatedSupplierId: row.relatedSupplierId,
  relatedEmployeeId: row.relatedEmployeeId,
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
    );
