import 'package:drift/drift.dart';

import '../../models/notification_item.dart';
import '../database/app_database.dart';
import '../database/meta_keys.dart';
import '../mappers/mappers.dart';
import 'new_id.dart';

/// The notification feed, and the name every write is attributed to.
///
/// The team / employees module is **not** in the database — it still runs on
/// `lib/mock_data/` (with its pointage, paie and CIN+PIN auth). So "who is
/// acting" is a single string in `meta`, seeded with the current employee's
/// display name. When the employee module is ported to the database this
/// widens back into a real lookup over an `employees` table.
class AccountRepository {
  const AccountRepository(this._db);

  final AppDatabase _db;

  // ---------------------------------------------------------------------------
  // Acting user
  // ---------------------------------------------------------------------------

  /// The name stamped on a movement, a price change or a receipt when the
  /// caller does not supply one. Read from `meta`; empty only when the row is
  /// missing, which the seed makes sure it is not.
  Future<String> currentUserName() async {
    final stored =
        await (_db.select(
          _db.meta,
        )..where((m) => m.key.equals(MetaKeys.currentUserName))).getSingleOrNull();
    return stored?.value ?? '';
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
  // Writes — notifications
  // ---------------------------------------------------------------------------

  /// Files one notification, unless the same thing was just said.
  ///
  /// Returns the row that was written, or null when it was suppressed.
  ///
  /// **The deduplication is the point.** An article sitting a hair under its
  /// threshold produces a movement every service, and every one of them crosses
  /// nothing — but a naive engine would file a warning each time and bury the
  /// feed under one article. Nothing is written when a notification of the same
  /// [kind] about the same [relatedItemId] already exists inside [window]; the
  /// existing one is left alone rather than refreshed, so its timestamp keeps
  /// saying when the situation actually started.
  ///
  /// A draft with no [relatedItemId] — a delivery — dedupes on kind alone,
  /// which is why [window] is short for those callers.
  Future<NotificationItem?> emit({
    required String storeId,
    required NotificationKind kind,
    required String title,
    required String body,
    String? relatedItemId,
    String? relatedSupplierId,
    DateTime? createdAt,
    Duration window = const Duration(hours: 12),
  }) async {
    final now = createdAt ?? DateTime.now();

    final since = now.subtract(window);
    final existing =
        await (_db.select(_db.notifications)
              ..where(
                (n) =>
                    n.storeId.equals(storeId) &
                    n.kind.equalsValue(kind) &
                    n.createdAt.isBiggerThanValue(since) &
                    (relatedItemId == null
                        ? n.relatedItemId.isNull()
                        : n.relatedItemId.equals(relatedItemId)),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) return null;

    final notification = NotificationItem(
      id: newId(),
      storeId: storeId,
      kind: kind,
      title: title,
      body: body,
      createdAt: now,
      isRead: false,
      relatedItemId: relatedItemId,
      relatedSupplierId: relatedSupplierId,
    );
    await _db.into(_db.notifications).insert(notificationToRow(notification));
    return notification;
  }

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
