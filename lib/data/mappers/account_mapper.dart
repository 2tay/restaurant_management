import 'package:drift/drift.dart';

import '../../models/notification_item.dart';
import '../database/app_database.dart';

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
