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

  // --- Pointage and paie settings ------------------------------------------
  //
  // The rest of `StoreSettings` (Phase 2 employé). It was `mock_store_settings.dart`,
  // one row per store; the model's `storeId` plus these six fields is the whole
  // record. Defaults are the constants in `core/utils/` — named in the comments
  // so a schema change and a constant change cannot silently disagree.

  /// Opening / closing time, minutes since midnight — the baseline lateness and
  /// overtime are measured against for an employee with no personal schedule.
  /// `AttendanceRules.defaultOpenMinutes` / `defaultCloseMinutes` = 08:00, 17:00.
  IntColumn get openMinutes => integer().withDefault(const Constant(8 * 60))();
  IntColumn get closeMinutes =>
      integer().withDefault(const Constant(17 * 60))();

  /// A single break segment longer than this is flagged "pause dépassée".
  /// `AttendanceRules.defaultMaxBreakMinutes`.
  IntColumn get maxBreakMinutes =>
      integer().withDefault(const Constant(30))();

  /// Overtime hours are paid at the normal rate times this coefficient.
  /// `PayrollRules.defaultOvertimeMultiplier`.
  RealColumn get overtimeMultiplier =>
      real().withDefault(const Constant(1.25))();

  /// Divisor that turns a fixed-salary employee's monthly pay into a daily
  /// rate. `PayrollRules.defaultWorkingDaysPerMonth`.
  IntColumn get workingDaysPerMonth =>
      integer().withDefault(const Constant(26))();

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
