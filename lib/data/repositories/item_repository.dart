import 'package:drift/drift.dart';

import '../../models/item.dart';
import '../database/app_database.dart';
import '../mappers/mappers.dart';
import 'movement_repository.dart';
import 'new_id.dart';
import 'order_repository.dart';

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

  // Value equality because a filter is a provider family's key. Riverpod keys
  // on `==`, so without this a screen that rebuilds — which the inventory list
  // does on every keystroke in its search field — would construct an
  // equal-but-not-identical filter, be handed a different provider, and tear
  // down a live query only to open the same one again.
  @override
  bool operator ==(Object other) =>
      other is ItemFilter &&
      other.categoryId == categoryId &&
      other.supplierId == supplierId &&
      other.lowStockOnly == lowStockOnly;

  @override
  int get hashCode => Object.hash(categoryId, supplierId, lowStockOnly);
}

/// What is standing between an article and deletion.
enum ItemDeleteBlock {
  /// It is on a commande that has been sent and is not finished.
  ///
  /// Deleting it would leave an outstanding document referring to an article
  /// that no longer exists — and that document is in a supplier's inbox.
  onOpenOrder,
}

/// Articles.
///
/// Note what is **not** here: nothing changes an article's quantity. That
/// belongs to `movement_repository.dart` and nowhere else, so every quantity
/// change leaves a movement behind. Creating an article with a starting quantity
/// therefore records an opening balance rather than setting the number.
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
  // Writes
  // ---------------------------------------------------------------------------

  /// Creates an article, and its opening balance if it starts with stock.
  ///
  /// Returns null when the barcode is already used by another article in this
  /// establishment — the one validation that can fail here. The form checks
  /// first so it can put the error under the field; this refuses as a backstop.
  ///
  /// The article is inserted with **quantity zero** whatever was typed, and the
  /// opening balance is handed to `MovementRepository.recordOpeningBalance`, in
  /// the same transaction. Two consequences, both wanted: the quantity and the
  /// movement log agree from the article's first day, and an article can never
  /// exist without the movement that explains its stock — the transaction is
  /// what turns "should not" into "cannot".
  ///
  /// [openingUnitCost] is what the starting stock was bought at, and the only
  /// way an article can begin life with a known cost. There is deliberately no
  /// fallback to a supplier price, because at this moment there is none to fall
  /// back to: [defaultSupplierId] records a preference, not a `SupplierPrice`
  /// link, and the link cannot exist for an article that did not exist a line
  /// ago. Left empty, the cost stays unknown and the article contributes nothing
  /// to the valuation until a real delivery says what stock costs.
  Future<Item?> create({
    required String storeId,
    required String name,
    required String categoryId,
    required String unitId,
    required double quantity,
    required double lowStockThreshold,
    double? openingUnitCost,
    String? barcode,
    String? note,
    String? defaultSupplierId,
    String? userName,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return null;

    final cleanBarcode = _clean(barcode);

    return _db.transaction(() async {
      if (cleanBarcode != null &&
          await barcodeConflict(storeId, cleanBarcode) != null) {
        return null;
      }

      final draft = Item(
        id: newId(),
        storeId: storeId,
        name: trimmedName,
        categoryId: categoryId,
        unitId: unitId,
        quantity: 0,
        lowStockThreshold: lowStockThreshold,
        updatedAt: DateTime.now(),
        defaultSupplierId: defaultSupplierId,
        barcode: cleanBarcode,
        note: _clean(note),
      );

      await _db.into(_db.items).insert(itemToRow(draft));

      await MovementRepository(_db).recordOpeningBalance(
        storeId: storeId,
        itemId: draft.id,
        quantity: quantity,
        // Routed through the movement rather than written onto the article, so
        // the cost is set by its first movement exactly like every change after
        // it. One writer, no exceptions.
        unitCost: openingUnitCost,
        userName: userName,
      );

      // Re-read: the opening balance has just moved the quantity and may have
      // set the cost, and returning the draft would hand the caller a row that
      // is already out of date.
      return item(draft.id);
    });
  }

  /// Edits an article's details.
  ///
  /// **Quantity is absent on purpose.** Changing stock from an edit form would
  /// be an untraceable stock change hidden inside a routine screen — the most
  /// consequential thing in the app, done by accident. The edit form shows the
  /// quantity as a fact and links to the adjustment screen, which exists for
  /// exactly this and leaves a movement behind.
  Future<Item?> update(
    String id, {
    String? name,
    String? categoryId,
    String? unitId,
    double? lowStockThreshold,
    String? barcode,
    String? note,
    String? defaultSupplierId,
    bool clearBarcode = false,
    bool clearNote = false,
  }) async {
    final trimmedName = name?.trim();
    if (trimmedName != null && trimmedName.isEmpty) return null;

    return _db.transaction(() async {
      final existing = await item(id);
      if (existing == null) return null;

      final cleanBarcode = clearBarcode ? null : _clean(barcode);
      if (!clearBarcode && cleanBarcode != null) {
        final clash = await barcodeConflict(
          existing.storeId,
          cleanBarcode,
          // Without this, saving an article with its own barcode unchanged
          // would fail against itself.
          excludingItemId: id,
        );
        if (clash != null) return null;
      }

      await (_db.update(_db.items)..where((i) => i.id.equals(id))).write(
        ItemsCompanion(
          name: Value(trimmedName ?? existing.name),
          categoryId: Value(categoryId ?? existing.categoryId),
          unitId: Value(unitId ?? existing.unitId),
          lowStockThreshold: Value(
            lowStockThreshold ?? existing.lowStockThreshold,
          ),
          updatedAt: Value(DateTime.now()),
          defaultSupplierId: Value(
            defaultSupplierId ?? existing.defaultSupplierId,
          ),
          barcode: Value(
            clearBarcode ? null : cleanBarcode ?? existing.barcode,
          ),
          note: Value(clearNote ? null : _clean(note) ?? existing.note),
        ),
      );

      return item(id);
    });
  }

  /// What would stop this article being deleted, or null if nothing would.
  ///
  /// Exposed so the screen can explain before it asks, rather than offering a
  /// confirmation that then quietly fails.
  Future<ItemDeleteBlock?> deleteBlockedBy(String id) async {
    final existing = await item(id);
    if (existing == null) return null;

    final open = await OrderRepository(
      _db,
    ).openOrdersForItem(existing.storeId, id);
    return open.isEmpty ? null : ItemDeleteBlock.onOpenOrder;
  }

  /// Deletes an article and everything that only made sense alongside it.
  ///
  /// Its supplier links, their price history and its movements go with it. That
  /// does destroy history, which sits uneasily beside "a confirmed receipt is
  /// permanent" — the difference is that this is the explicit, confirmed, named
  /// act, and the alternative is worse: leaving movements and prices pointing at
  /// an article that no longer exists renders them as "—" with no way to work
  /// out what they used to say. The confirmation dialog states the counts, which
  /// is what makes it honest.
  ///
  /// The cascade is the schema's now rather than four `removeWhere` calls, so it
  /// cannot go half-done and cannot be forgotten by a future caller. What it
  /// deliberately does **not** reach is the lines of closed commandes and
  /// receipts, which keep naming the article — see the note on those columns.
  Future<bool> delete(String id) {
    return _db.transaction(() async {
      if (await deleteBlockedBy(id) != null) return false;

      final removed = await (_db.delete(
        _db.items,
      )..where((i) => i.id.equals(id))).go();
      return removed > 0;
    });
  }

  /// Empty input stores as null rather than as an empty string, so "no barcode"
  /// is one value rather than two.
  String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
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
