import 'package:drift/drift.dart';

import '../../models/store.dart';
import '../database/app_database.dart';
import '../mappers/mappers.dart';

/// Establishments.
///
/// Small enough that everything here reads the whole table: there are three in
/// the demo and a real account will have a handful. Filtering in Dart on top of
/// a three-row query is clearer than a second SQL path.
class StoreRepository {
  const StoreRepository(this._db);

  final AppDatabase _db;

  /// Oldest first, which is the order the store selector and the switcher show.
  ///
  /// Explicit rather than relying on insertion order. The mock list happened to
  /// be written oldest-first and every screen quietly depended on that; a
  /// database has no such habit, and `ORDER BY` is where that expectation
  /// becomes a promise.
  Stream<List<Store>> watchStores() => _query().watch().map(_toStores);

  Future<List<Store>> stores() => _query().get().then(_toStores);

  Stream<Store?> watchStore(String id) =>
      (_db.select(_db.stores)..where((s) => s.id.equals(id)))
          .watchSingleOrNull()
          .map((row) => row == null ? null : storeFromRow(row));

  Future<Store?> store(String id) =>
      (_db.select(_db.stores)..where((s) => s.id.equals(id)))
          .getSingleOrNull()
          .then((row) => row == null ? null : storeFromRow(row));

  /// The named establishment, or the first one if the name does not resolve.
  ///
  /// What the shell route reads. A stale or hand-typed store id in the URL
  /// should show the app rather than a crash — but unlike its Phase 1
  /// counterpart this can return null, because a database can genuinely hold no
  /// establishments and pretending otherwise would move the crash rather than
  /// remove it.
  Stream<Store?> watchStoreOrFirst(String? id) {
    return watchStores().map((List<Store> stores) {
      if (stores.isEmpty) return null;
      if (id == null) return stores.first;
      return stores.firstWhere(
        (store) => store.id == id,
        orElse: () => stores.first,
      );
    });
  }

  /// How many days a `partial` commande may sit before the dashboard flags it.
  ///
  /// A column on the establishment since this phase; it was a mutable global in
  /// Phase 1. Returns the default for a store that does not exist, so a caller
  /// reading it for a stale route parameter gets a usable number rather than an
  /// exception on a screen that is about to be replaced anyway.
  Future<int> stalePartialOrderDays(String storeId) async {
    final row = await (_db.select(
      _db.stores,
    )..where((s) => s.id.equals(storeId))).getSingleOrNull();
    return row?.stalePartialOrderDays ?? 7;
  }

  SimpleSelectStatement<$StoresTable, StoreRow> _query() =>
      _db.select(_db.stores)..orderBy([
        (s) => OrderingTerm(expression: s.createdAt),
        (s) => OrderingTerm(expression: s.id),
      ]);

  List<Store> _toStores(List<StoreRow> rows) => rows.map(storeFromRow).toList();
}
