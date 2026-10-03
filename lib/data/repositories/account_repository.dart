import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../../models/employee.dart';
import '../../models/notification_item.dart';
import '../database/app_database.dart';
import '../database/meta_keys.dart';
import '../mappers/mappers.dart';
import 'new_id.dart';

/// The notification feed, and the name every write is attributed to.
///
/// The team / employees module is **not** in the database — it still runs on
/// `lib/mock_data/` (with its pointage, paie and PIN+password auth). So "who is
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

  // [viewer] is the role of whoever is looking. It decides whether a
  // signalement (`NotificationKind.personnel`) is read: a manager and the
  // owner each read it for themselves. Every other kind is read for all.

  /// Newest first.
  Stream<List<NotificationItem>> watchNotifications(
    String storeId, {
    EmployeeRole? viewer,
  }) => _notifications(
    storeId,
  ).watch().map((rows) => _toNotifications(rows, viewer));

  Future<List<NotificationItem>> notifications(
    String storeId, {
    EmployeeRole? viewer,
  }) => _notifications(
    storeId,
  ).get().then((rows) => _toNotifications(rows, viewer));

  Stream<int> watchUnreadCount(String storeId, {EmployeeRole? viewer}) {
    final (query, read) = _unreadQuery(storeId, viewer);
    return query.watchSingle().map(read);
  }

  Future<int> unreadNotificationCount(
    String storeId, {
    EmployeeRole? viewer,
  }) async {
    final (query, read) = _unreadQuery(storeId, viewer);
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
    final now = createdAt ?? clock.now();

    final since = now.subtract(window);
    final existing =
        await (_db.select(_db.notifications)
              ..where(
                (n) =>
                    n.storeId.equals(storeId) &
                    n.deletedAt.isNull() &
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

  /// Files a signalement for the managers and the owner
  /// (SYNC_PERSONNEL_PLAN.md: « signalé au gérant et au propriétaire »).
  ///
  /// The one way to raise one. It is a notification of kind
  /// [NotificationKind.personnel]: synced like every notification, so every
  /// tablet shows it; never switched off by a preference.
  ///
  /// [key] names the situation, the same on every tablet — e.g.
  /// `double_clock_in:<kept day id>`. The row's id is derived from it, so two
  /// tablets settling the same conflict file **one** signalement, not two,
  /// and filing it again does nothing. Returns whether a row was written.
  ///
  /// Inside a quiet write (`SyncQuiet`), the caller wraps this in
  /// `SyncQuiet.loud`: a signalement must reach the other tablets.
  Future<bool> signal({
    required String storeId,
    required String key,
    required String title,
    required String body,
    String? employeeId,
    DateTime? at,
  }) async {
    final id = signalId(key);
    final existing = await (_db.select(
      _db.notifications,
    )..where((n) => n.id.equals(id))).getSingleOrNull();
    if (existing != null) return false;

    await _db
        .into(_db.notifications)
        .insert(
          NotificationsCompanion.insert(
            id: id,
            storeId: storeId,
            kind: NotificationKind.personnel,
            title: title,
            body: body,
            createdAt: at ?? clock.now(),
            relatedEmployeeId: Value(employeeId),
          ),
        );
    return true;
  }

  /// The id of the signalement for [key]: the same on every tablet.
  static String signalId(String key) =>
      'flag-${sha1.convert(utf8.encode(key))}';

  /// Marks one notification read for [viewer]. False if it is missing or
  /// already was.
  Future<bool> markRead(String id, {EmployeeRole? viewer}) async =>
      await _markRead(_db.notifications.id.equals(id), viewer) > 0;

  /// Marks everything in an establishment read for [viewer]. Returns how many
  /// changed.
  ///
  /// The count lets the screen say "7 notifications marquées comme lues" rather
  /// than a bare acknowledgement, and lets it stay quiet when there was nothing
  /// to do.
  Future<int> markAllRead(String storeId, {EmployeeRole? viewer}) => _markRead(
    _db.notifications.storeId.equals(storeId) &
        _db.notifications.deletedAt.isNull(),
    viewer,
  );

  // ---------------------------------------------------------------------------

  /// The "already read" case is in each `WHERE` rather than in a
  /// read-then-write: the number of rows the statements touched is the
  /// answer, and a statement cannot report a change it did not make.
  Future<int> _markRead(Expression<bool> scope, EmployeeRole? viewer) async {
    final n = _db.notifications;
    final stamp = _readStamp(viewer);
    final signalement = n.kind.equalsValue(NotificationKind.personnel);
    var changed = 0;
    if (stamp != null) {
      changed +=
          await (_db.update(n)
                ..where((_) => scope & signalement & stamp.isNull()))
              .write(
                RawValuesInsertable<NotificationRow>({
                  stamp.name: Variable<DateTime>(clock.now()),
                }),
              );
    }
    changed +=
        await (_db.update(n)..where(
              (_) =>
                  scope &
                  n.isRead.equals(false) &
                  (stamp == null ? const Constant(true) : signalement.not()),
            ))
            .write(const NotificationsCompanion(isRead: Value(true)));
    return changed;
  }

  /// The column that says whether [viewer] read a signalement, or null when
  /// their role reads `is_read` like every other kind.
  GeneratedColumn<DateTime>? _readStamp(EmployeeRole? viewer) =>
      switch (viewer) {
        EmployeeRole.owner => _db.notifications.readByOwnerAt,
        EmployeeRole.manager => _db.notifications.readByManagerAt,
        _ => null,
      };

  (JoinedSelectStatement<HasResultSet, dynamic>, int Function(TypedResult))
  _unreadQuery(String storeId, EmployeeRole? viewer) {
    final n = _db.notifications;
    final count = n.id.count();
    final stamp = _readStamp(viewer);
    final signalement = n.kind.equalsValue(NotificationKind.personnel);
    final unread = stamp == null
        ? n.isRead.equals(false)
        : (signalement & stamp.isNull()) |
              (signalement.not() & n.isRead.equals(false));
    final query = _db.selectOnly(n)
      ..addColumns([count])
      ..where(n.storeId.equals(storeId) & n.deletedAt.isNull() & unread);
    return (query, (TypedResult row) => row.read(count) ?? 0);
  }

  SimpleSelectStatement<$NotificationsTable, NotificationRow> _notifications(
    String storeId,
  ) => _db.select(_db.notifications)
    ..where((n) => n.storeId.equals(storeId) & n.deletedAt.isNull())
    ..orderBy([
      (n) => OrderingTerm(expression: n.createdAt, mode: OrderingMode.desc),
      (n) => OrderingTerm(expression: n.id, mode: OrderingMode.desc),
    ]);

  List<NotificationItem> _toNotifications(
    List<NotificationRow> rows,
    EmployeeRole? viewer,
  ) => [for (final row in rows) notificationFromRow(row, viewer: viewer)];
}
