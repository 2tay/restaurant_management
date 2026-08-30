import 'package:drift/drift.dart';

import '../../models/notification_item.dart';
import '../database/app_database.dart';
import '../database/meta_keys.dart';
import '../mappers/mappers.dart';

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
