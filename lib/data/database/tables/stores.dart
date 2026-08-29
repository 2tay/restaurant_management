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

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Single-row-per-key storage for the handful of facts that belong to the
/// database rather than to any establishment.
///
/// Two keys so far: `seededAt`, the instant the demo dataset was written, which
/// is what makes its relative dates reproducible on a re-seed; and
/// `currentUserId`, the team member stamped on every movement and price change
/// until Phase 3 brings real authentication.
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
