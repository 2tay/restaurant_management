import 'package:drift/drift.dart';

/// An establishment. Everything else in the schema hangs off one.
///
/// Ids are `TEXT`, not autoincrementing integers, and stay that way: they are
/// route segments (`/store/store-sablon/inventaire`), they are what every
/// `xById` lookup takes, and the seed's readable slugs are what makes a debug
/// dump legible. An integer key would rewrite the router for no gain.
@DataClassName('StoreRow')
class Stores extends Table {
  TextColumn get id => text().withLength(min: 1, max: 64)();
  TextColumn get name => text()();
  TextColumn get addressLine => text()();
  TextColumn get postalCode => text()();
  TextColumn get city => text()();
  TextColumn get phone => text()();
  DateTimeColumn get createdAt => dateTime()();

  /// Belgian business documents need it in the header. Absent renders nothing
  /// rather than an empty label, so null and '' must not both be reachable —
  /// the store form stores empty input as null.
  TextColumn get vatNumber => text().nullable()();

  TextColumn get imageAsset => text().nullable()();

  /// How many days a `partial` commande may sit before the dashboard flags it.
  ///
  /// This is where `MockSettings.stalePartialOrderDays` lands. It was a mutable
  /// global in Phase 1 with a comment promising it would become a column, and
  /// this is that column. Per store, because two establishments can reasonably
  /// disagree about how long is too long.
  IntColumn get stalePartialOrderDays =>
      integer().withDefault(const Constant(7))();

  // --- Pointage settings ----------------------------------------------------
  //
  // The rest of `StoreSettings` (Phase 2 employé). Default is the constant in
  // `core/utils/` — named in the comment so a schema change and a constant
  // change cannot silently disagree.

  /// A single break segment longer than this is flagged "pause dépassée".
  /// `AttendanceRules.defaultMaxBreakMinutes`.
  IntColumn get maxBreakMinutes =>
      integer().withDefault(const Constant(30))();

  // --- Notification preferences --------------------------------------------
  //
  // Which events are allowed to write a row into `notifications`. Per store,
  // like the rest of the settings, and read by the notification engine *before*
  // it composes anything — a preference that only hid a notification after the
  // fact would still leave it in the feed and on the bell.
  //
  // The defaults are the ones the preferences screen has always displayed:
  // everything on except deliveries, which are expected rather than surprising.

  BoolColumn get notifyLowStock => boolean().withDefault(const Constant(true))();
  BoolColumn get notifyPriceChange =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get notifyLargeAdjustment =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get notifyDeliveries =>
      boolean().withDefault(const Constant(false))();

  /// The "jours chargés" reminder: on unless switched off, like the stock ones.
  BoolColumn get notifyBusyDays => boolean().withDefault(const Constant(true))();

  // --- Busy-day calendar -----------------------------------------------------
  //
  // The weekly half of the calendar. The one-off dates live in [BusyDates].

  /// The weekdays that are busy every week, as ISO numbers joined by commas
  /// (`DateTime.monday` = 1 … `DateTime.sunday` = 7). Friday, Saturday and
  /// Sunday by default — `BusyCalendarRules.defaultWeekdays`.
  ///
  /// Text rather than a child table: seven booleans that are always read and
  /// written together are one value, and an empty string is a real answer
  /// ("no weekday is busy").
  TextColumn get busyWeekdays =>
      text().withDefault(const Constant('5,6,7'))();

  /// How many days before a busy period the reminder starts.
  /// `BusyCalendarRules.defaultReminderDays`.
  IntColumn get busyReminderDays =>
      integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Single-row-per-key storage for the handful of facts that belong to the
/// database rather than to any establishment.
///
/// Two keys so far: `seededAt`, the instant the demo dataset was written, which
/// is what makes its relative dates reproducible on a re-seed; and
/// `currentUserName`, the name stamped on every movement and price change (the
/// employee module lives in `lib/mock_data/`, so this is a plain string).
///
/// A key/value table rather than a one-row settings table because these are
/// unrelated to each other and arrive one at a time. A column each would mean a
/// migration per fact.
@DataClassName('MetaRow')
class Meta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
