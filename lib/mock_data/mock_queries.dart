import '../core/utils/order_status.dart';
import '../core/utils/stock_cost.dart';
import '../core/utils/stock_status.dart';
import '../models/models.dart';
import 'mock_categories.dart';
import 'mock_goods_receipts.dart';
import 'mock_items.dart';
import 'mock_notifications.dart';
import 'mock_price_history.dart';
import 'mock_purchase_orders.dart';
import 'mock_settings.dart';
import 'mock_stock_movements.dart';
import 'mock_stores.dart';
import 'mock_supplier_prices.dart';
import 'mock_suppliers.dart';
import 'mock_team.dart';
import 'mock_units.dart';

/// Lookups over the mock lists.
///
/// These are list filters, not business logic — "give me the items for this
/// store" rather than "decide what the reorder quantity should be". They live
/// here so that forty screens don't each re-implement `firstWhere` over a
/// global list.
///
/// **Phase 2 replaces this file with repositories.** Screens calling
/// `itemsForStore(storeId)` swap to a provider returning the same shape, which
/// is the point: the call sites barely move.
abstract final class MockQueries {
  // ---------------------------------------------------------------------------
  // Stores
  // ---------------------------------------------------------------------------

  static Store? storeById(String id) {
    for (final store in mockStores) {
      if (store.id == id) return store;
    }
    return null;
  }

  /// Falls back to the first store rather than returning null, so a bad or
  /// stale route parameter shows the app instead of a crash.
  static Store storeByIdOrFirst(String? id) =>
      (id == null ? null : storeById(id)) ?? mockStores.first;

  // ---------------------------------------------------------------------------
  // Items
  // ---------------------------------------------------------------------------

  static List<Item> itemsForStore(String storeId) =>
      mockItems.where((item) => item.storeId == storeId).toList();

  static Item? itemById(String id) {
    for (final item in mockItems) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// Items at or below their threshold, worst first — the alerts screen order.
  static List<Item> lowStockItems(String storeId) {
    final items = itemsForStore(storeId).where(needsAttention).toList()
      ..sort((a, b) {
        final statusOrder = _statusRank(a).compareTo(_statusRank(b));
        if (statusOrder != 0) return statusOrder;
        return a.name.compareTo(b.name);
      });
    return items;
  }

  static int _statusRank(Item item) => switch (stockStatusOf(item)) {
    StockStatus.outOfStock => 0,
    StockStatus.lowStock => 1,
    StockStatus.inStock => 2,
  };

  // ---------------------------------------------------------------------------
  // Barcodes
  // ---------------------------------------------------------------------------

  /// Every item in the store carrying this exact barcode.
  ///
  /// **Returns a collection on purpose, even though the app currently enforces
  /// one barcode per item.** Multiple barcodes per item — a case and a single
  /// bottle of the same beer — is the likeliest next requirement here, and a
  /// lookup already shaped as "give me the matches" absorbs that as a model
  /// change instead of a rewrite of every call site. Callers take `.first`.
  ///
  /// Exact match on the trimmed string. No normalisation, no check digits, no
  /// format rules: a barcode is an opaque identifier, and the moment the app
  /// starts having opinions about its shape it starts rejecting real ones.
  static List<Item> itemsWithBarcode(String storeId, String barcode) {
    final needle = barcode.trim();
    if (needle.isEmpty) return const [];
    return mockItems
        .where((item) => item.storeId == storeId && item.barcode == needle)
        .toList();
  }

  /// The item already using this barcode, ignoring [excludingItemId].
  ///
  /// What the item form calls to validate. The exclusion is what lets someone
  /// edit an item and save it with its own barcode unchanged — without it,
  /// every edit would fail against itself.
  static Item? barcodeConflict(
    String storeId,
    String barcode, {
    String? excludingItemId,
  }) {
    for (final item in itemsWithBarcode(storeId, barcode)) {
      if (item.id != excludingItemId) return item;
    }
    return null;
  }

  /// Whether an item matches a search box.
  ///
  /// Written once and shared by the inventory list and global search, so
  /// "pasting a barcode finds the item" cannot be true on one screen and false
  /// on the other. [query] must already be trimmed and lower-cased.
  ///
  /// Name matching is a substring; barcode matching is exact, because a partial
  /// barcode is not a barcode and offering fuzzy matches for one would be worse
  /// than offering nothing.
  static bool itemMatchesSearch(Item item, String query) {
    if (query.isEmpty) return true;
    if (item.name.toLowerCase().contains(query)) return true;
    return item.barcode != null && item.barcode!.toLowerCase() == query;
  }

  // ---------------------------------------------------------------------------
  // Catalog
  // ---------------------------------------------------------------------------

  static List<Category> categoriesForStore(String storeId) =>
      mockCategories.where((c) => c.storeId == storeId).toList();

  static Category? categoryById(String id) {
    for (final category in mockCategories) {
      if (category.id == id) return category;
    }
    return null;
  }

  static String categoryNameOf(String id) => categoryById(id)?.name ?? '—';

  /// The category of this store already using this name, if any.
  ///
  /// Case- and space-insensitive: "Boissons" and "boissons " are the same
  /// category with a typo, and letting both exist means half the drinks end up
  /// filed under the wrong one. [excludingId] lets a rename ignore itself.
  static Category? categoryNamed(
    String storeId,
    String name, {
    String? excludingId,
  }) {
    final needle = _normalise(name);
    if (needle.isEmpty) return null;

    for (final category in mockCategories) {
      if (category.storeId != storeId) continue;
      if (category.id == excludingId) continue;
      if (_normalise(category.name) == needle) return category;
    }
    return null;
  }

  static List<UnitOfMeasure> unitsForStore(String storeId) =>
      mockUnits.where((u) => u.storeId == storeId).toList();

  static UnitOfMeasure? unitById(String id) {
    for (final unit in mockUnits) {
      if (unit.id == id) return unit;
    }
    return null;
  }

  /// The short form shown next to every quantity — "kg", "bac".
  static String unitAbbreviationOf(String id) =>
      unitById(id)?.abbreviation ?? '';

  /// The unit of this store already using this name, if any.
  static UnitOfMeasure? unitNamed(
    String storeId,
    String name, {
    String? excludingId,
  }) => _findUnit(
    storeId,
    name,
    excludingId,
    (unit) => unit.name,
  );

  /// The unit of this store already using this abbreviation, if any.
  ///
  /// Checked as well as the name because the abbreviation is what appears next
  /// to every quantity in the app: two units abbreviated "cs" would make the
  /// inventory list unreadable however different their full names were.
  static UnitOfMeasure? unitAbbreviated(
    String storeId,
    String abbreviation, {
    String? excludingId,
  }) => _findUnit(
    storeId,
    abbreviation,
    excludingId,
    (unit) => unit.abbreviation,
  );

  static UnitOfMeasure? _findUnit(
    String storeId,
    String value,
    String? excludingId,
    String Function(UnitOfMeasure unit) field,
  ) {
    final needle = _normalise(value);
    if (needle.isEmpty) return null;

    for (final unit in mockUnits) {
      if (unit.storeId != storeId) continue;
      if (unit.id == excludingId) continue;
      if (_normalise(field(unit)) == needle) return unit;
    }
    return null;
  }

  /// How catalogue names are compared: trimmed and case-folded.
  ///
  /// Deliberately no accent folding — "Épicerie" and "Epicerie" are different
  /// spellings a user might legitimately want to correct, and silently treating
  /// them as the same name would block the correction.
  static String _normalise(String value) => value.trim().toLowerCase();

  static int itemCountInCategory(String categoryId) =>
      mockItems.where((item) => item.categoryId == categoryId).length;

  static int itemCountUsingUnit(String unitId) =>
      mockItems.where((item) => item.unitId == unitId).length;

  // ---------------------------------------------------------------------------
  // Suppliers
  // ---------------------------------------------------------------------------

  static List<Supplier> suppliersForStore(String storeId) =>
      mockSuppliers.where((s) => s.storeId == storeId).toList();

  static Supplier? supplierById(String id) {
    for (final supplier in mockSuppliers) {
      if (supplier.id == id) return supplier;
    }
    return null;
  }

  static String supplierNameOf(String? id) =>
      id == null ? '—' : supplierById(id)?.name ?? '—';

  // ---------------------------------------------------------------------------
  // Prices — the item–supplier link
  // ---------------------------------------------------------------------------

  /// Every supplier offering this item, cheapest first.
  static List<SupplierPrice> pricesForItem(String itemId) {
    final prices = mockSupplierPrices.where((p) => p.itemId == itemId).toList()
      ..sort((a, b) => a.pricePerUnit.compareTo(b.pricePerUnit));
    return prices;
  }

  /// Every item this supplier provides.
  static List<SupplierPrice> pricesForSupplier(String supplierId) =>
      mockSupplierPrices.where((p) => p.supplierId == supplierId).toList();

  static int itemCountForSupplier(String supplierId) =>
      pricesForSupplier(supplierId).length;

  static SupplierPrice? defaultPriceForItem(String itemId) {
    for (final price in mockSupplierPrices) {
      if (price.itemId == itemId && price.isDefault) return price;
    }
    return null;
  }

  static SupplierPrice? cheapestPriceForItem(String itemId) {
    final prices = pricesForItem(itemId);
    return prices.isEmpty ? null : prices.first;
  }

  /// How much more the default supplier costs than the cheapest one, per unit.
  /// Zero when the store is already on the best price.
  ///
  /// This is the number the price comparison report is built around.
  static double overpayPerUnit(String itemId) {
    final current = defaultPriceForItem(itemId);
    final cheapest = cheapestPriceForItem(itemId);
    if (current == null || cheapest == null) return 0;
    final difference = current.pricePerUnit - cheapest.pricePerUnit;
    return difference > 0 ? difference : 0;
  }

  static SupplierPrice? priceFor(String itemId, String supplierId) {
    for (final price in mockSupplierPrices) {
      if (price.itemId == itemId && price.supplierId == supplierId) {
        return price;
      }
    }
    return null;
  }

  /// Price changes for one item–supplier pair, newest first.
  static List<PriceHistoryEntry> priceHistoryFor(
    String itemId,
    String supplierId,
  ) {
    final entries =
        mockPriceHistory
            .where((e) => e.itemId == itemId && e.supplierId == supplierId)
            .toList()
          ..sort((a, b) => b.changedAt.compareTo(a.changedAt));
    return entries;
  }

  // ---------------------------------------------------------------------------
  // Movements
  // ---------------------------------------------------------------------------

  /// Newest first. The mock list is already ordered, but sorting makes the
  /// screens independent of that.
  static List<StockMovement> movementsForStore(String storeId) {
    final movements =
        mockStockMovements.where((m) => m.storeId == storeId).toList()
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return movements;
  }

  static List<StockMovement> movementsForItem(String itemId) {
    final movements =
        mockStockMovements.where((m) => m.itemId == itemId).toList()
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return movements;
  }

  static List<StockMovement> recentActivity(String storeId, {int limit = 8}) =>
      movementsForStore(storeId).take(limit).toList();

  // ---------------------------------------------------------------------------
  // Notifications and team
  // ---------------------------------------------------------------------------

  static List<NotificationItem> notificationsForStore(String storeId) {
    final notifications =
        mockNotifications.where((n) => n.storeId == storeId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notifications;
  }

  static int unreadNotificationCount(String storeId) =>
      notificationsForStore(storeId).where((n) => !n.isRead).length;

  static List<TeamMember> teamForStore(String storeId) =>
      mockTeam.where((m) => m.storeIds.contains(storeId)).toList();

  static TeamMember? teamMemberById(String id) {
    for (final member in mockTeam) {
      if (member.id == id) return member;
    }
    return null;
  }

  /// The member already using this email, if any.
  ///
  /// Email is the one team field worth guarding: it is how a real invitation
  /// would be addressed in Phase 2, and two members sharing one makes that
  /// ambiguous.
  static TeamMember? teamMemberByEmail(String email, {String? excludingId}) {
    final needle = _normalise(email);
    if (needle.isEmpty) return null;

    for (final member in mockTeam) {
      if (member.id == excludingId) continue;
      if (_normalise(member.email) == needle) return member;
    }
    return null;
  }

  /// How many owners the account has left.
  ///
  /// Guards the removal of the last one: an account nobody can administer is
  /// not a state worth being able to reach by accident.
  static int ownerCount() =>
      mockTeam.where((member) => member.role == TeamRole.owner).length;

  // ---------------------------------------------------------------------------
  // Valuation
  // ---------------------------------------------------------------------------

  /// What the stock on hand is worth, at what it actually cost.
  ///
  /// **Derived rather than stored.** It used to be a constant in
  /// `mock_reports.dart`, which was fine while nothing moved — but once
  /// receiving a delivery raises a quantity, a headline figure that does not
  /// follow makes the dashboard contradict the inventory two taps away.
  ///
  /// It used to value stock at each item's **default supplier price**, and that
  /// was wrong in a way that got worse the more the app was used. A supplier
  /// price is what the *next* unit will cost; multiplying it by everything on
  /// hand revalued stock bought weeks ago at this morning's delivery price. A
  /// delivery of 50 kg at 10 € landing on 100 kg bought at 8 € reported 1 500 €
  /// of stock when 1 300 € had been spent — 200 € of value that never existed,
  /// appearing on the one screen an owner reads to find out what they are
  /// holding. A price drop invented the loss in the other direction.
  ///
  /// It now reads `Item.averageCost`, which is maintained delivery by delivery
  /// in `MovementMutations` and only ever revalues the units a delivery
  /// actually delivered. See `core/utils/stock_cost.dart`.
  ///
  /// Items with no cost on file contribute nothing rather than an invented
  /// figure. Understating is the safer direction: a valuation built partly on
  /// guesses is worse than one that is visibly incomplete.
  static double stockValuation(String storeId) {
    var total = 0.0;
    for (final item in itemsForStore(storeId)) {
      total += _valueOf(item);
    }
    return total;
  }

  /// Stock value per category, largest first — the valuation report's breakdown.
  static List<ValuationRow> valuationByCategory(String storeId) {
    final values = <String, double>{};
    final counts = <String, int>{};

    for (final item in itemsForStore(storeId)) {
      values[item.categoryId] =
          (values[item.categoryId] ?? 0) + _valueOf(item);
      counts[item.categoryId] = (counts[item.categoryId] ?? 0) + 1;
    }

    final total = stockValuation(storeId);
    final rows =
        values.entries
            .map(
              (entry) => ValuationRow(
                label: categoryNameOf(entry.key),
                itemCount: counts[entry.key] ?? 0,
                totalValue: entry.value,
                shareOfTotal: total == 0 ? 0 : entry.value / total,
              ),
            )
            .toList()
          ..sort((a, b) => b.totalValue.compareTo(a.totalValue));
    return rows;
  }

  /// The most valuable individual items, largest first.
  ///
  /// [itemCount] carries the quantity on hand here rather than a count of
  /// items, matching the column the report renders it in.
  static List<ValuationRow> valuationByItem(String storeId, {int limit = 10}) {
    final total = stockValuation(storeId);

    final rows =
        itemsForStore(storeId)
            .map(
              (item) => ValuationRow(
                label: item.name,
                itemCount: item.quantity.round(),
                totalValue: _valueOf(item),
                shareOfTotal: total == 0 ? 0 : _valueOf(item) / total,
              ),
            )
            .where((row) => row.totalValue > 0)
            .toList()
          ..sort((a, b) => b.totalValue.compareTo(a.totalValue));

    return rows.take(limit).toList();
  }

  /// What one item's stock on hand is worth. Zero when no cost is on file:
  /// understating beats inventing a price.
  ///
  /// Deliberately **not** a supplier price. See [stockValuation].
  static double _valueOf(Item item) => valueOf(item.quantity, item.averageCost);

  // ---------------------------------------------------------------------------
  // What stock cost on the way out
  // ---------------------------------------------------------------------------
  //
  // These exist because every movement now records the cost it applied. Before
  // that, the app could say six kilos of chicken were thrown away but not what
  // those six kilos cost — which is the half of the sentence an owner acts on.

  /// The cost of everything that left stock in the window.
  ///
  /// Cost of goods sold, in the loose sense that includes waste: it is what the
  /// stock that is no longer there was paid for.
  static double consumptionValue(String storeId, {DateTime? from, DateTime? to}) =>
      _outboundValue(storeId, from: from, to: to);

  /// The cost of what was thrown away or spoiled in the window.
  ///
  /// **The number this whole change was worth making for.** The usage report
  /// could already say how many kilos went in the bin; this says how many euros
  /// did, valued at what they actually cost rather than at a supplier's current
  /// asking price.
  static double wasteValue(String storeId, {DateTime? from, DateTime? to}) =>
      _outboundValue(
        storeId,
        from: from,
        to: to,
        reasons: const {StockOutReason.waste, StockOutReason.spoilage},
      );

  /// The cost of stock that went missing between counts, in the window.
  ///
  /// Adjustments downwards only. An adjustment upwards is stock that was there
  /// all along and had simply not been recorded, which is not a loss.
  static double shrinkageValue(String storeId, {DateTime? from, DateTime? to}) {
    var total = 0.0;
    for (final movement in movementsForStore(storeId)) {
      if (movement.type != StockMovementType.adjustment) continue;
      if (movement.quantity >= 0) continue;
      if (!_within(movement.occurredAt, from, to)) continue;
      total += movement.quantity.abs() * (movement.unitCost ?? 0);
    }
    return total;
  }

  /// Shared by [consumptionValue] and [wasteValue].
  ///
  /// Movements with no cost recorded contribute nothing rather than a guess —
  /// the same rule the valuation follows. Seeded history predates the cost
  /// fields, so this is the normal case in a demo rather than an edge one.
  static double _outboundValue(
    String storeId, {
    DateTime? from,
    DateTime? to,
    Set<StockOutReason>? reasons,
  }) {
    var total = 0.0;
    for (final movement in movementsForStore(storeId)) {
      if (movement.type != StockMovementType.stockOut) continue;
      if (reasons != null && !reasons.contains(movement.reason)) continue;
      if (!_within(movement.occurredAt, from, to)) continue;
      total += movement.quantity.abs() * (movement.unitCost ?? 0);
    }
    return total;
  }

  static bool _within(DateTime at, DateTime? from, DateTime? to) {
    if (from != null && at.isBefore(from)) return false;
    if (to != null && at.isAfter(to)) return false;
    return true;
  }

  // ---------------------------------------------------------------------------
  // Commandes
  // ---------------------------------------------------------------------------

  /// Newest first — the orders list order.
  static List<PurchaseOrder> ordersForStore(String storeId) {
    final orders =
        mockPurchaseOrders.where((order) => order.storeId == storeId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }

  static PurchaseOrder? orderById(String id) {
    for (final order in mockPurchaseOrders) {
      if (order.id == id) return order;
    }
    return null;
  }

  /// Sent or partial: the supplier has the document and goods may still come.
  static List<PurchaseOrder> openOrders(String storeId) =>
      ordersForStore(storeId).where(orderIsOpen).toList();

  static List<PurchaseOrder> ordersForSupplier(String supplierId) {
    final orders =
        mockPurchaseOrders
            .where((order) => order.supplierId == supplierId)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }

  /// Open orders that still have something outstanding for this item.
  ///
  /// Powers both the "already on order" flag on the create screen and the list
  /// of open orders on the item detail. A manager who ordered on Monday and is
  /// looking at a low stock level on Wednesday needs to see that the goods are
  /// in transit rather than missing.
  static List<PurchaseOrder> openOrdersForItem(String storeId, String itemId) {
    return openOrders(storeId)
        .where(
          (order) => order.lines.any(
            (line) => line.itemId == itemId && lineOutstanding(line) > 0,
          ),
        )
        .toList();
  }

  /// Total quantity of an item still expected across every open order.
  ///
  /// The counterpart to "on hand". Low-stock alerts still fire on what is
  /// physically in the store — goods in a van do not cook dinner — but an item
  /// that is low *and already ordered* has to look different from one that is
  /// low and nobody has acted.
  static double onOrderQuantity(String storeId, String itemId) {
    var total = 0.0;
    for (final order in openOrders(storeId)) {
      for (final line in order.lines) {
        if (line.itemId == itemId) total += lineOutstanding(line);
      }
    }
    return total;
  }

  /// Orders sitting in `partial` past the store's threshold.
  static List<PurchaseOrder> staleOrders(String storeId) => ordersForStore(
    storeId,
  ).where((o) => orderIsStale(o, MockSettings.stalePartialOrderDays)).toList();

  /// This supplier's items that are at or below their threshold.
  ///
  /// The suggestion list on the create screen, which is what turns low stock
  /// from a list you read into a list you act on.
  static List<Item> suggestedItemsForSupplier(
    String storeId,
    String supplierId,
  ) {
    final supplied = pricesForSupplier(
      supplierId,
    ).map((price) => price.itemId).toSet();

    return lowStockItems(
      storeId,
    ).where((item) => supplied.contains(item.id)).toList();
  }

  /// Every item this supplier offers, for the order line picker.
  static List<Item> itemsSuppliedBy(String storeId, String supplierId) {
    final supplied = pricesForSupplier(
      supplierId,
    ).map((price) => price.itemId).toSet();

    final items =
        itemsForStore(
          storeId,
        ).where((item) => supplied.contains(item.id)).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return items;
  }

  // ---------------------------------------------------------------------------
  // Receipts
  // ---------------------------------------------------------------------------

  /// Deliveries against one order, oldest first — the order they happened in,
  /// which is how the receipts tab should read.
  static List<GoodsReceipt> receiptsForOrder(String orderId) {
    final receipts =
        mockGoodsReceipts
            .where((receipt) => receipt.orderId == orderId)
            .toList()
          ..sort((a, b) => a.receivedAt.compareTo(b.receivedAt));
    return receipts;
  }

  static GoodsReceipt? receiptById(String id) {
    for (final receipt in mockGoodsReceipts) {
      if (receipt.id == id) return receipt;
    }
    return null;
  }

  /// The quotable number for one delivery — `BR-2026-014/2`.
  ///
  /// Resolves the receipt's position in its order's deliveries and hands both
  /// to [receiptReference]. The arithmetic lives there so it can be tested
  /// without the mock lists; this is only the lookup.
  ///
  /// Falls back to a bare `BR-<id>` for a receipt whose order has gone missing,
  /// which cannot happen through the app but keeps the document renderable
  /// rather than throwing at the moment somebody needs to send it.
  static String receiptReferenceOf(GoodsReceipt receipt) {
    final order = orderById(receipt.orderId);
    if (order == null) return 'BR-${receipt.id}';

    final siblings = receiptsForOrder(receipt.orderId);
    final index = siblings.indexWhere((s) => s.id == receipt.id);
    return receiptReference(order.reference, index == -1 ? 1 : index + 1);
  }
}
