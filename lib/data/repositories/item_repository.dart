import 'package:drift/drift.dart';

import '../../models/item.dart';
import '../database/app_database.dart';
import '../mappers/mappers.dart';

/// What the inventory list is filtered by.
///
/// The screen's own `InventoryFilter` also carries the search text and the
/// selected row; neither belongs in SQL. The text is matched by
/// `core/utils/item_search.dart` over the rows this returns, for the reasons
/// written down there.
class ItemFilter {
  const ItemFilter({this.categoryId, this.supplierId, this.lowStockOnly = false});

  final String? categoryId;

  /// Restricts to articles this supplier offers a price for.
  ///
  /// This one is why the filter exists at all. Phase 1 answered it by calling
  /// `pricesForItem` inside a `.where()` over every article in the store — one
  /// lookup per row, on every rebuild, on the app's busiest screen. Here it is
  /// an `EXISTS` subquery the database answers once.
  final String? supplierId;

  /// Articles at or below their threshold.
  final bool lowStockOnly;

  static const ItemFilter none = ItemFilter();
}

/// Articles.
///
/// Reads only. The writes arrive in stage 4, and the one write that will never
/// live here is quantity: only `movement_repository.dart` may touch
/// `items.quantity` and `items.averageCost`, because every change to either has
/// to be explained by a movement in the same transaction.
class ItemRepository {
  const ItemRepository(this._db);

  final AppDatabase _db;

  /// The inventory list, and with `lowStockOnly` the alerts screen.
  ///
  /// **Worst status first, then alphabetical.** What needs attention floats up;
  /// that was a Dart sort in the page and is now an `ORDER BY`, expressed as two
  /// boolean keys rather than a `CASE`: `quantity > 0` puts ruptures first, then
  /// `quantity > lowStockThreshold` puts low stock ahead of healthy stock.
  Stream<List<Item>> watchItems(
    String storeId, {
    ItemFilter filter = ItemFilter.none,
  }) => _attentionFirst(storeId, filter).watch().map(_toItems);

  Future<List<Item>> itemsByAttention(
    String storeId, {
    ItemFilter filter = ItemFilter.none,
  }) => _attentionFirst(storeId, filter).get().then(_toItems);

  /// Every article in the establishment, alphabetically.
  ///
  /// For the callers that do their own ordering — the reports, the valuation,
  /// the order line picker — where "worst first" would be noise.
  Stream<List<Item>> watchItemsByName(String storeId) =>
      _byName(storeId).watch().map(_toItems);

  Future<List<Item>> items(String storeId) => _byName(storeId).get().then(_toItems);

  Stream<Item?> watchItem(String id) =>
      (_db.select(_db.items)..where((i) => i.id.equals(id)))
          .watchSingleOrNull()
          .map(_toItemOrNull);

  Future<Item?> item(String id) =>
      (_db.select(_db.items)..where((i) => i.id.equals(id)))
          .getSingleOrNull()
          .then(_toItemOrNull);

  /// Every article in the establishment carrying this exact barcode.
  ///
  /// **A collection on purpose**, even though the app enforces one barcode per
  /// article. Several barcodes for one article — a case and a single bottle of
  /// the same beer — is the likeliest next requirement, and a lookup already
  /// shaped as "give me the matches" absorbs that as a model change rather than
  /// a rewrite of every call site.
  ///
  /// Exact match on the trimmed string. No normalisation, no check digits, no
  /// format rules: a barcode is an opaque identifier, and an app with opinions
  /// about its shape starts rejecting real ones.
  Future<List<Item>> itemsWithBarcode(String storeId, String barcode) async {
    final needle = barcode.trim();
    if (needle.isEmpty) return const <Item>[];

    final rows = await (_db.select(_db.items)
          ..where((i) => i.storeId.equals(storeId) & i.barcode.equals(needle)))
        .get();
    return _toItems(rows);
  }

  /// The article already using this barcode, ignoring [excludingItemId].
  ///
  /// What the item form calls to validate. The exclusion is what lets somebody
  /// edit an article and save it with its own barcode unchanged — without it
  /// every edit would fail against itself.
  Future<Item?> barcodeConflict(
    String storeId,
    String barcode, {
    String? excludingItemId,
  }) async {
    for (final item in await itemsWithBarcode(storeId, barcode)) {
      if (item.id != excludingItemId) return item;
    }
    return null;
  }

  /// Every article this supplier offers, for the order line picker.
  Stream<List<Item>> watchItemsSuppliedBy(String storeId, String supplierId) =>
      (_byName(storeId)..where((i) => _suppliedBy(i, supplierId)))
          .watch()
          .map(_toItems);

  Future<List<Item>> itemsSuppliedBy(String storeId, String supplierId) =>
      (_byName(storeId)..where((i) => _suppliedBy(i, supplierId)))
          .get()
          .then(_toItems);

  /// This supplier's articles that are at or below their threshold.
  ///
  /// The suggestion list on the create-commande screen, which is what turns low
  /// stock from a list you read into a list you act on.
  Stream<List<Item>> watchSuggestedItems(String storeId, String supplierId) =>
      watchItems(
        storeId,
        filter: ItemFilter(supplierId: supplierId, lowStockOnly: true),
      );

  // ---------------------------------------------------------------------------

  SimpleSelectStatement<$ItemsTable, ItemRow> _attentionFirst(
    String storeId,
    ItemFilter filter,
  ) {
    final query = _db.select(_db.items)
      ..where((i) => i.storeId.equals(storeId))
      ..orderBy([
        // false sorts before true, so "not a rupture" and "not low" both sink.
        (i) => OrderingTerm(expression: i.quantity.isBiggerThanValue(0)),
        (i) => OrderingTerm(expression: i.quantity.isBiggerThan(i.lowStockThreshold)),
        (i) => OrderingTerm(expression: i.name),
      ]);
    _applyFilter(query, filter);
    return query;
  }

  SimpleSelectStatement<$ItemsTable, ItemRow> _byName(String storeId) =>
      _db.select(_db.items)
        ..where((i) => i.storeId.equals(storeId))
        ..orderBy([(i) => OrderingTerm(expression: i.name)]);

  void _applyFilter(
    SimpleSelectStatement<$ItemsTable, ItemRow> query,
    ItemFilter filter,
  ) {
    final String? categoryId = filter.categoryId;
    if (categoryId != null) {
      query.where((i) => i.categoryId.equals(categoryId));
    }
    final String? supplierId = filter.supplierId;
    if (supplierId != null) {
      query.where((i) => _suppliedBy(i, supplierId));
    }
    if (filter.lowStockOnly) {
      // `needsAttention` is "at or below threshold", which also covers a
      // rupture: a quantity of zero or less is at or below any threshold.
      query.where((i) => i.quantity.isSmallerOrEqual(i.lowStockThreshold));
    }
  }

  /// `EXISTS (SELECT 1 FROM supplier_prices WHERE item_id = items.id AND ...)`.
  Expression<bool> _suppliedBy($ItemsTable items, String supplierId) {
    final subquery = _db.selectOnly(_db.supplierPrices)
      ..addColumns([_db.supplierPrices.id])
      ..where(
        _db.supplierPrices.itemId.equalsExp(items.id) &
            _db.supplierPrices.supplierId.equals(supplierId),
      );
    return existsQuery(subquery);
  }

  List<Item> _toItems(List<ItemRow> rows) => rows.map(itemFromRow).toList();

  Item? _toItemOrNull(ItemRow? row) => row == null ? null : itemFromRow(row);
}
