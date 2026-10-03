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

  /// When a manager, and when the owner, first read a signalement. Read
  /// separately: a manager reading it does not hide it from the owner. A
  /// stamp is never cleared, and sync keeps the earliest (`SyncApplier`).
  /// Other kinds keep using [isRead].
  DateTimeColumn get readByManagerAt => dateTime().nullable()();
  DateTimeColumn get readByOwnerAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
