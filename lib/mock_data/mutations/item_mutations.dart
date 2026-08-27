import '../../models/models.dart';
import '../mock_items.dart';
import '../mock_price_history.dart';
import '../mock_queries.dart';
import '../mock_stock_movements.dart';
import '../mock_supplier_prices.dart';
import 'mock_write.dart';
import 'movement_mutations.dart';

/// What is standing between an item and deletion.
enum ItemDeleteBlock {
  /// The item is on a commande that has been sent and is not finished.
  ///
  /// Deleting it would leave an outstanding document referring to an article
  /// that no longer exists — and that document is in a supplier's inbox.
  onOpenOrder,
}

/// Writes against the articles themselves.
///
/// Note what is **not** here: nothing changes an item's quantity. That belongs
/// to [MovementMutations] and nowhere else, so every quantity change leaves a
/// movement behind. Creating an item with a starting quantity therefore records
/// an opening balance rather than setting the number.
abstract final class ItemMutations {
  /// Creates an article, and its opening balance if it starts with stock.
  ///
  /// Returns null when the barcode is already used by another item in this
  /// store — the one validation that can fail here. The form checks first so it
  /// can put the error under the field; this refuses as a backstop.
  ///
  /// [openingUnitCost] is what the starting stock was bought at, and the only
  /// way an article can begin life with a known cost.
  ///
  /// There is deliberately **no fallback to a supplier price** here, because at
  /// this moment there is none to fall back to: [defaultSupplierId] records a
  /// preference, not a `SupplierPrice` link, and the link cannot exist for an
  /// article that did not exist a line ago. Left empty, the cost stays unknown
  /// and the article contributes nothing to the valuation until a real delivery
  /// tells it what stock costs — which is the honest answer, and the same rule
  /// the valuation already followed for items with no supplier on file.
  static Item? create({
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
  }) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return null;

    final cleanBarcode = _cleanBarcode(barcode);
    if (cleanBarcode != null &&
        MockQueries.barcodeConflict(storeId, cleanBarcode) != null) {
      return null;
    }

    final now = DateTime.now();
    final item = Item(
      id: MockWrite.id('item'),
      storeId: storeId,
      name: trimmedName,
      categoryId: categoryId,
      unitId: unitId,
      // Starts empty whatever was typed. The opening balance below is what
      // puts stock on it, so that the quantity and the movement log agree from
      // the article's first day.
      quantity: 0,
      lowStockThreshold: lowStockThreshold,
      updatedAt: now,
      defaultSupplierId: defaultSupplierId,
      barcode: cleanBarcode,
      note: _clean(note),
    );

    mockItems.add(item);
    MockWrite.changed();

    MovementMutations.recordOpeningBalance(
      storeId: storeId,
      itemId: item.id,
      quantity: quantity,
      // Routed through the movement rather than written onto the item, so the
      // cost is set by the article's first movement exactly like every change
      // after it. One writer, no exceptions.
      unitCost: openingUnitCost,
      userName: userName,
    );

    return MockQueries.itemById(item.id);
  }

  /// Edits an article's details.
  ///
  /// **Quantity is absent on purpose.** Changing stock from an edit form would
  /// be an untraceable stock change hidden inside a routine screen — the most
  /// consequential thing in the app, done by accident. The edit form shows the
  /// quantity as a fact and links to the adjustment screen, which exists for
  /// exactly this and leaves a movement behind.
  static Item? update(
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
  }) {
    final index = mockItems.indexWhere((item) => item.id == id);
    if (index == -1) return null;

    final existing = mockItems[index];
    final trimmedName = name?.trim();
    if (trimmedName != null && trimmedName.isEmpty) return null;

    final cleanBarcode = clearBarcode ? null : _cleanBarcode(barcode);
    if (!clearBarcode &&
        cleanBarcode != null &&
        MockQueries.barcodeConflict(
              existing.storeId,
              cleanBarcode,
              // Without this, saving an item with its own barcode unchanged
              // would fail against itself.
              excludingItemId: id,
            ) !=
            null) {
      return null;
    }

    final updated = Item(
      id: existing.id,
      storeId: existing.storeId,
      name: trimmedName ?? existing.name,
      categoryId: categoryId ?? existing.categoryId,
      unitId: unitId ?? existing.unitId,
      quantity: existing.quantity,
      lowStockThreshold: lowStockThreshold ?? existing.lowStockThreshold,
      updatedAt: DateTime.now(),
      defaultSupplierId: defaultSupplierId ?? existing.defaultSupplierId,
      barcode: clearBarcode ? null : cleanBarcode ?? existing.barcode,
      note: clearNote ? null : _clean(note) ?? existing.note,
    );

    mockItems[index] = updated;
    MockWrite.changed();
    return updated;
  }

  /// What would stop this item being deleted, or null if nothing would.
  ///
  /// Exposed so the screen can explain before it asks, rather than offering a
  /// confirmation that then quietly fails.
  static ItemDeleteBlock? deleteBlockedBy(String id) {
    final item = MockQueries.itemById(id);
    if (item == null) return null;

    if (MockQueries.openOrdersForItem(item.storeId, id).isNotEmpty) {
      return ItemDeleteBlock.onOpenOrder;
    }
    return null;
  }

  /// Deletes an article and everything that only made sense alongside it.
  ///
  /// Cascades to its supplier links, their price history, and its movements.
  /// That does destroy history, which sits uneasily beside "a confirmed receipt
  /// is permanent" — the difference is that this is the explicit, confirmed,
  /// named act, and the alternative is worse: leaving movements and prices
  /// pointing at an article that no longer exists renders them as "—" with no
  /// way to work out what they used to say.
  ///
  /// The confirmation dialog states the counts, which is what makes it honest.
  /// Soft deletion is a Phase 2 concern.
  static bool delete(String id) {
    if (deleteBlockedBy(id) != null) return false;
    if (!mockItems.any((item) => item.id == id)) return false;

    mockSupplierPrices.removeWhere((price) => price.itemId == id);
    mockPriceHistory.removeWhere((entry) => entry.itemId == id);
    mockStockMovements.removeWhere((movement) => movement.itemId == id);
    mockItems.removeWhere((item) => item.id == id);

    MockWrite.changed();
    return true;
  }

  /// Empty input stores as null rather than as an empty string, so "no
  /// barcode" is one value rather than two.
  static String? _cleanBarcode(String? value) => _clean(value);

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
