import '../../models/models.dart';
import '../mock_price_history.dart';
import '../mock_queries.dart';
import '../mock_supplier_prices.dart';
import '../mock_suppliers.dart';
import '../mock_team.dart';
import 'mock_write.dart';

/// What is standing between a supplier and deletion.
enum SupplierDeleteBlock {
  /// They have a commande that has been sent and is not finished.
  ///
  /// Deleting them would orphan an outstanding document — and, if anything on
  /// it has already arrived, the stock movements that document produced.
  hasOpenOrder,
}

/// Writes against suppliers and the item–supplier links that carry prices.
///
/// The link is where this app's central idea lives: **price is an attribute of
/// the item–supplier pair, not of the item.** One product comes from three
/// wholesalers at three prices, and the comparison between them is the feature
/// the client is buying. So the operations here are mostly about keeping that
/// relationship coherent — exactly one default per item, a history entry
/// whenever a price moves, and a promotion when the default disappears.
abstract final class SupplierMutations {
  // ---------------------------------------------------------------------------
  // Suppliers
  // ---------------------------------------------------------------------------

  static Supplier create({
    required String storeId,
    required String name,
    required String contactName,
    required String email,
    required String phone,
    required String addressLine,
    required String postalCode,
    required String city,
    String? note,
  }) {
    final supplier = Supplier(
      id: MockWrite.id('sup'),
      storeId: storeId,
      name: name.trim(),
      contactName: contactName.trim(),
      email: email.trim(),
      phone: phone.trim(),
      addressLine: addressLine.trim(),
      postalCode: postalCode.trim(),
      city: city.trim(),
      note: _clean(note),
    );

    mockSuppliers.add(supplier);
    MockWrite.changed();
    return supplier;
  }

  /// Edits a supplier's details.
  ///
  /// Names are deliberately **not** checked for uniqueness. Two branches of the
  /// same butcher is a real situation, and blocking it would be the app
  /// inventing a rule the business does not have.
  static Supplier? update(
    String id, {
    String? name,
    String? contactName,
    String? email,
    String? phone,
    String? addressLine,
    String? postalCode,
    String? city,
    String? note,
    bool clearNote = false,
  }) {
    final index = mockSuppliers.indexWhere((s) => s.id == id);
    if (index == -1) return null;

    final existing = mockSuppliers[index];
    final trimmedName = name?.trim();
    if (trimmedName != null && trimmedName.isEmpty) return null;

    final updated = Supplier(
      id: existing.id,
      storeId: existing.storeId,
      name: trimmedName ?? existing.name,
      contactName: contactName?.trim() ?? existing.contactName,
      email: email?.trim() ?? existing.email,
      phone: phone?.trim() ?? existing.phone,
      addressLine: addressLine?.trim() ?? existing.addressLine,
      postalCode: postalCode?.trim() ?? existing.postalCode,
      city: city?.trim() ?? existing.city,
      note: clearNote ? null : _clean(note) ?? existing.note,
    );

    mockSuppliers[index] = updated;
    MockWrite.changed();
    return updated;
  }

  /// What would stop this supplier being deleted, or null if nothing would.
  static SupplierDeleteBlock? deleteBlockedBy(String id) {
    final hasOpen = MockQueries.ordersForSupplier(
      id,
    ).any((order) => order.status == PurchaseOrderStatus.sent ||
        order.status == PurchaseOrderStatus.partial);

    return hasOpen ? SupplierDeleteBlock.hasOpenOrder : null;
  }

  /// Deletes a supplier and the prices they offered.
  ///
  /// **Stock movements naming them are kept.** A movement is the record of
  /// goods that really moved; the supplier going away does not unmake that. The
  /// movement keeps their id and renders as "Fournisseur supprimé", which is
  /// true, rather than being erased, which would not be.
  ///
  /// Their closed orders are kept for the same reason — the order history is
  /// how an owner sees who they used to buy from.
  static bool delete(String id) {
    if (deleteBlockedBy(id) != null) return false;
    if (!mockSuppliers.any((s) => s.id == id)) return false;

    // Every item this supplier was the default for needs a new default, or the
    // item silently loses its auto-fill on every stock-in and order line.
    final orphanedItems = MockQueries.pricesForSupplier(id)
        .where((price) => price.isDefault)
        .map((price) => price.itemId)
        .toList();

    mockSupplierPrices.removeWhere((price) => price.supplierId == id);
    mockPriceHistory.removeWhere((entry) => entry.supplierId == id);
    mockSuppliers.removeWhere((s) => s.id == id);

    for (final itemId in orphanedItems) {
      _promoteCheapestToDefault(itemId);
    }

    MockWrite.changed();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Item–supplier links
  // ---------------------------------------------------------------------------

  /// Links an item to a supplier at a price.
  ///
  /// Returns null if the link already exists — that is an edit, not a new link,
  /// and silently overwriting the price would lose the history entry the edit
  /// path writes.
  static SupplierPrice? linkItem({
    required String itemId,
    required String supplierId,
    required double pricePerUnit,
    bool makeDefault = false,
  }) {
    if (pricePerUnit <= 0) return null;
    if (MockQueries.priceFor(itemId, supplierId) != null) return null;

    // The first supplier for an item becomes its default whether or not the
    // caller asked: an item with prices but no default has no auto-fill
    // anywhere, which reads as the feature being broken.
    final isFirst = MockQueries.pricesForItem(itemId).isEmpty;
    final shouldDefault = makeDefault || isFirst;

    if (shouldDefault) _clearDefaultFor(itemId);

    final price = SupplierPrice(
      id: MockWrite.id('sp'),
      itemId: itemId,
      supplierId: supplierId,
      pricePerUnit: pricePerUnit,
      effectiveDate: DateTime.now(),
      isDefault: shouldDefault,
    );

    mockSupplierPrices.add(price);
    MockWrite.changed();
    return price;
  }

  /// Changes what a supplier charges, and records why the number moved.
  ///
  /// Every change writes a history entry scoped to the item–supplier *pair*,
  /// which is what makes "what has this supplier charged us for chicken over
  /// six months" answerable. Setting the same price again writes nothing.
  static SupplierPrice? updatePrice(
    String priceId,
    double newPrice, {
    String? changedByName,
    DateTime? changedAt,
  }) {
    if (newPrice <= 0) return null;

    final index = mockSupplierPrices.indexWhere((p) => p.id == priceId);
    if (index == -1) return null;

    final existing = mockSupplierPrices[index];
    if ((existing.pricePerUnit - newPrice).abs() < 0.001) return existing;

    final at = changedAt ?? DateTime.now();

    mockPriceHistory.add(
      PriceHistoryEntry(
        id: MockWrite.id('ph'),
        itemId: existing.itemId,
        supplierId: existing.supplierId,
        oldPrice: existing.pricePerUnit,
        newPrice: newPrice,
        changedAt: at,
        changedByName: changedByName ?? mockCurrentUser.fullName,
      ),
    );

    final updated = SupplierPrice(
      id: existing.id,
      itemId: existing.itemId,
      supplierId: existing.supplierId,
      pricePerUnit: newPrice,
      effectiveDate: at,
      isDefault: existing.isDefault,
    );

    mockSupplierPrices[index] = updated;
    MockWrite.changed();
    return updated;
  }

  /// Marks one supplier as the one normally used for an item.
  static bool setDefault(String priceId) {
    final index = mockSupplierPrices.indexWhere((p) => p.id == priceId);
    if (index == -1) return false;

    final target = mockSupplierPrices[index];
    _clearDefaultFor(target.itemId);

    final refreshed = mockSupplierPrices.indexWhere((p) => p.id == priceId);
    mockSupplierPrices[refreshed] = _withDefault(
      mockSupplierPrices[refreshed],
      true,
    );

    MockWrite.changed();
    return true;
  }

  /// Removes an item–supplier link.
  ///
  /// If it was the default, the cheapest remaining supplier is promoted.
  /// Without that the item keeps its other suppliers but loses its auto-fill
  /// everywhere, and nothing on screen explains why.
  ///
  /// The price history for the pair is kept: it records what that supplier
  /// charged while the link existed, which stays true afterwards.
  static bool unlinkItem(String priceId) {
    final index = mockSupplierPrices.indexWhere((p) => p.id == priceId);
    if (index == -1) return false;

    final removed = mockSupplierPrices.removeAt(index);
    if (removed.isDefault) _promoteCheapestToDefault(removed.itemId);

    MockWrite.changed();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Default bookkeeping
  // ---------------------------------------------------------------------------

  static void _clearDefaultFor(String itemId) {
    for (var i = 0; i < mockSupplierPrices.length; i++) {
      final price = mockSupplierPrices[i];
      if (price.itemId == itemId && price.isDefault) {
        mockSupplierPrices[i] = _withDefault(price, false);
      }
    }
  }

  static void _promoteCheapestToDefault(String itemId) {
    // `pricesForItem` is already cheapest first.
    final remaining = MockQueries.pricesForItem(itemId);
    if (remaining.isEmpty) return;

    final index = mockSupplierPrices.indexWhere(
      (price) => price.id == remaining.first.id,
    );
    if (index == -1) return;

    mockSupplierPrices[index] = _withDefault(mockSupplierPrices[index], true);
  }

  static SupplierPrice _withDefault(SupplierPrice price, bool isDefault) {
    return SupplierPrice(
      id: price.id,
      itemId: price.itemId,
      supplierId: price.supplierId,
      pricePerUnit: price.pricePerUnit,
      effectiveDate: price.effectiveDate,
      isDefault: isDefault,
    );
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
