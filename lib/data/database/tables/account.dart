import 'package:drift/drift.dart';

import '../../../models/notification_item.dart';
import '../../../models/team_member.dart';
import 'stores.dart';

/// Somebody with access to the account.
///
/// Not per store: a member belongs to the account and is granted one or more
/// establishments through [TeamMemberStores]. An owner typically has all of
/// them, a chef de cuisine one.
@DataClassName('TeamMemberRow')
class TeamMembers extends Table {
  TextColumn get id => text().withLength(min: 1, max: 64)();
  TextColumn get fullName => text()();

  /// Unique across the team, checked by the account repository with the member
  /// being edited excluded. Not a unique index: the app's comparison is on the
  /// trimmed, case-folded address, which SQLite cannot express for non-ASCII.
  TextColumn get email => text()();

  TextColumn get role => textEnum<TeamRole>()();
  BoolColumn get isActive => boolean()();
  DateTimeColumn get invitedAt => dateTime()();
  DateTimeColumn get lastActiveAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Which establishments a member can see.
///
/// `TeamMember.storeIds` is a `List<String>` on the model; this is that list.
/// The composite primary key is the whole row, so the same grant cannot be
/// recorded twice.
@DataClassName('TeamMemberStoreRow')
class TeamMemberStores extends Table {
  TextColumn get memberId =>
      text().references(TeamMembers, #id, onDelete: KeyAction.cascade)();
  TextColumn get storeId =>
      text().references(Stores, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {memberId, storeId};
}

/// Something the app wants to tell the user about this establishment.
@DataClassName('NotificationRow')
@TableIndex(
  name: 'notifications_store_time',
  columns: {#storeId, IndexedColumn(#createdAt, orderBy: OrderingMode.desc)},
)
class Notifications extends Table {
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

  @override
  Set<Column<Object>> get primaryKey => {id};
}
