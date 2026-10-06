import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../../models/employee.dart';
import '../../models/notification_item.dart';
import '../database/app_database.dart';
import '../database/meta_keys.dart';
import '../mappers/mappers.dart';

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

  // [viewer] is whoever is looking. It decides whether a signalement
  // (`NotificationKind.personnel`) is read: each person reads it for
  // themselves ([NotificationReads]). Every other kind is read for all.

  /// Newest first.
  Stream<List<NotificationItem>> watchNotifications(
    String storeId, {
    NotificationViewer? viewer,
  }) => _notifications(
    storeId,
    viewer,
  ).watch().map((rows) => _toNotifications(rows, viewer));

  Future<List<NotificationItem>> notifications(
    String storeId, {
    NotificationViewer? viewer,
  }) => _notifications(
    storeId,
    viewer,
  ).get().then((rows) => _toNotifications(rows, viewer));

  Stream<int> watchUnreadCount(String storeId, {NotificationViewer? viewer}) {
    final (query, read) = _unreadQuery(storeId, viewer);
    return query.watchSingle().map(read);
  }

  Future<int> unreadNotificationCount(
    String storeId, {
    NotificationViewer? viewer,
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
  ///
  /// [key] names the situation the same way on every tablet — e.g.
  /// `low_stock:<store>:<item>:2026-10-06` — and the row's id is derived from
  /// it, as for a signalement ([signal]). The window above only sees this
  /// tablet's rows; two tablets that each file the same situation before
  /// syncing file **one** row, because they file the same id.
  Future<NotificationItem?> emit({
    required String storeId,
    required NotificationKind kind,
    required String key,
    required String title,
    required String body,
    String? relatedItemId,
    String? relatedSupplierId,
    DateTime? createdAt,
    Duration window = const Duration(hours: 12),
  }) async {
    final now = createdAt ?? clock.now();
    final id = noteId(key);

    // Already filed here, or by another tablet and received.
    final filed = await (_db.select(
      _db.notifications,
    )..where((n) => n.id.equals(id))).getSingleOrNull();
    if (filed != null) return null;

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
      id: id,
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
    String? target,
    DateTime? at,
    bool replace = false,
  }) async {
    final id = signalId(key);
    final existing = await (_db.select(
      _db.notifications,
    )..where((n) => n.id.equals(id))).getSingleOrNull();
    if (existing != null) {
      // [replace]: the same situation, grown (a trop-versé adding up) —
      // its words change, whether it was read does not.
      if (!replace) return false;
      await (_db.update(_db.notifications)..where((n) => n.id.equals(id)))
          .write(NotificationsCompanion(title: Value(title), body: Value(body)));
      return true;
    }

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
            relatedTarget: Value(target),
          ),
        );
    return true;
  }

  /// The id of the signalement for [key]: the same on every tablet.
  static String signalId(String key) =>
      'flag-${sha1.convert(utf8.encode(key))}';

  /// The id of the notification for [key] ([emit]): the same on every tablet.
  static String noteId(String key) => 'note-${sha1.convert(utf8.encode(key))}';

  /// The id of [employeeId]'s read of [notificationId]: the same on every
  /// tablet, so reading it twice, or on two tablets, writes one row.
  static String readId(String notificationId, String employeeId) =>
      'read-${sha1.convert(utf8.encode('$notificationId:$employeeId'))}';

  /// Marks one notification read for [viewer]. False if it is missing or
  /// already was.
  Future<bool> markRead(String id, {NotificationViewer? viewer}) async =>
      await _markRead(_db.notifications.id.equals(id), viewer) > 0;

  /// Marks everything in an establishment read for [viewer]. Returns how many
  /// changed.
  ///
  /// The count lets the screen say "7 notifications marquées comme lues" rather
  /// than a bare acknowledgement, and lets it stay quiet when there was nothing
  /// to do.
  Future<int> markAllRead(String storeId, {NotificationViewer? viewer}) =>
      _markRead(
        _db.notifications.storeId.equals(storeId) &
            _db.notifications.deletedAt.isNull(),
        viewer,
      );

  // ---------------------------------------------------------------------------

  /// A signalement is marked read by adding [viewer]'s row to
  /// [NotificationReads] — never by touching the notification, which every
  /// other reader shares. Anything else, or anything without a [viewer],
  /// sets `is_read`, in a `WHERE` that skips what already was: the number
  /// of rows touched is the answer.
  Future<int> _markRead(
    Expression<bool> scope,
    NotificationViewer? viewer,
  ) async {
    final n = _db.notifications;
    final signalement = n.kind.equalsValue(NotificationKind.personnel);
    if (viewer == null) {
      return (_db.update(n)..where((_) => scope & n.isRead.equals(false)))
          .write(const NotificationsCompanion(isRead: Value(true)));
    }

    return _db.transaction(() async {
      final r = _db.notificationReads;
      final unread =
          await (_db.select(n).join([_readBy(viewer)])..where(
                scope &
                    signalement &
                    r.id.isNull() &
                    _legacyStamp(viewer).isNull(),
              ))
              .map((row) => row.readTable(n))
              .get();
      final now = clock.now();
      for (final row in unread) {
        await _db
            .into(r)
            .insertOnConflictUpdate(
              NotificationReadsCompanion.insert(
                id: readId(row.id, viewer.id),
                storeId: row.storeId,
                notificationId: row.id,
                employeeId: viewer.id,
                readAt: now,
              ),
            );
      }
      final others =
          await (_db.update(n)..where(
                (_) => scope & signalement.not() & n.isRead.equals(false),
              ))
              .write(const NotificationsCompanion(isRead: Value(true)));
      return unread.length + others;
    });
  }

  /// [viewer]'s own read of each notification, when there is one.
  Join<HasResultSet, dynamic> _readBy(NotificationViewer viewer) {
    final r = _db.notificationReads;
    return leftOuterJoin(
      r,
      r.notificationId.equalsExp(_db.notifications.id) &
          r.employeeId.equals(viewer.id) &
          r.deletedAt.isNull(),
    );
  }

  /// How [viewer]'s role read a signalement before schema v23. Still
  /// counted, never written.
  GeneratedColumn<DateTime> _legacyStamp(NotificationViewer viewer) =>
      viewer.role == EmployeeRole.owner
      ? _db.notifications.readByOwnerAt
      : _db.notifications.readByManagerAt;

  (JoinedSelectStatement<HasResultSet, dynamic>, int Function(TypedResult))
  _unreadQuery(String storeId, NotificationViewer? viewer) {
    final n = _db.notifications;
    final count = n.id.count();
    final signalement = n.kind.equalsValue(NotificationKind.personnel);
    final query = _db.selectOnly(n);
    Expression<bool> unread = n.isRead.equals(false);
    if (viewer != null) {
      query.join([_readBy(viewer)]);
      unread =
          (signalement &
              _db.notificationReads.id.isNull() &
              _legacyStamp(viewer).isNull()) |
          (signalement.not() & n.isRead.equals(false));
    }
    query
      ..addColumns([count])
      ..where(n.storeId.equals(storeId) & n.deletedAt.isNull() & unread);
    return (query, (TypedResult row) => row.read(count) ?? 0);
  }

  JoinedSelectStatement<HasResultSet, dynamic> _notifications(
    String storeId,
    NotificationViewer? viewer,
  ) {
    final n = _db.notifications;
    return _db.select(n).join([if (viewer != null) _readBy(viewer)])
      ..where(n.storeId.equals(storeId) & n.deletedAt.isNull())
      ..orderBy([
        OrderingTerm(expression: n.createdAt, mode: OrderingMode.desc),
        OrderingTerm(expression: n.id, mode: OrderingMode.desc),
      ]);
  }

  List<NotificationItem> _toNotifications(
    List<TypedResult> rows,
    NotificationViewer? viewer,
  ) => [
    for (final row in rows)
      notificationFromRow(
        row.readTable(_db.notifications),
        viewer: viewer,
        readByViewer:
            viewer != null &&
            row.readTableOrNull(_db.notificationReads) != null,
      ),
  ];
}
