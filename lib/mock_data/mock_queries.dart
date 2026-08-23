import '../core/utils/stock_status.dart';
import '../models/models.dart';
import 'mock_categories.dart';
import 'mock_items.dart';
import 'mock_notifications.dart';
import 'mock_price_history.dart';
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
}
