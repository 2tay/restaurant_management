import 'package:drift/drift.dart';

import '../../../models/notification_item.dart';
import 'stores.dart';
import 'sync_columns.dart';

/// Something the app wants to tell the user about this establishment.
@DataClassName('NotificationRow')
@TableIndex(
  name: 'notifications_store_time',
  columns: {#storeId, IndexedColumn(#createdAt, orderBy: OrderingMode.desc)},
)
class Notifications extends Table with Touched, Deletable {
  TextColumn get id => text().withLength(min: 1, max: 64)();
  TextColumn get storeId =>
      text().references(Stores, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => textEnum<NotificationKind>()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();

  /// What tapping the notification opens. No foreign keys: a notification about
  /// an article outlives the article, and it still reads correctly — the tap
  /// target is what disappears, not the message.
  TextColumn get relatedItemId => text().nullable()();
  TextColumn get relatedSupplierId => text().nullable()();

  /// The employee a signalement is about (`NotificationKind.personnel`).
  TextColumn get relatedEmployeeId => text().nullable()();

  /// Which of their pages a signalement opens: `payroll` for a payment, null
  /// for the pointage history.
  TextColumn get relatedTarget => text().nullable()();

  /// When a manager, and when the owner, first read a signalement — how a
  /// signalement was read until schema v23, by role. No longer written: a
  /// signalement is now read per person ([NotificationReads]). Still read,
  /// so one already marked read by a role stays read after the upgrade.
  /// Other kinds keep using [isRead].
  DateTimeColumn get readByManagerAt => dateTime().nullable()();
  DateTimeColumn get readByOwnerAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One person who read one signalement (schema v23).
///
/// A signalement is read **per person**: one manager reading it does not hide
/// it from another, nor from the owner. Only rows are ever added — two
/// tablets marking it read for two people write two rows and cannot
/// overwrite each other — and [id] is derived from the notification and the
/// person (`AccountRepository.readId`), so the same person reading it on two
/// tablets writes one.
///
/// No foreign keys, like [Notifications.relatedItemId]: a read can reach a
/// tablet before the notification it is about (the notification changed
/// after it was read, so the server sends it later).
@DataClassName('NotificationReadRow')
@TableIndex(
  name: 'notification_reads_employee',
  columns: {#employeeId, #notificationId},
)
class NotificationReads extends Table with Touched, Deletable {
  TextColumn get id => text().withLength(min: 1, max: 64)();
  TextColumn get storeId =>
      text().references(Stores, #id, onDelete: KeyAction.cascade)();
  TextColumn get notificationId => text()();
  TextColumn get employeeId => text()();
  DateTimeColumn get readAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
