// Referential integrity checks over the mock dataset.
//
// The data is hand-written across a dozen files and relates items to
// categories, units, suppliers and prices by string id. A typo in any of those
// produces a dash, a blank row, or a crash on some screen nobody opened during
// the demo. These tests find it now instead.
//
// Dates are anchored to DateTime.now() via mock_reference.dart, so nothing here
// asserts on them.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/core/utils/stock_status.dart';
import 'package:stock_inventory/mock_data/mock_data.dart';
import 'package:stock_inventory/models/models.dart';

void main() {
  group('referential integrity', () {
    test('every item points at a real store, category and unit', () {
      final storeIds = mockStores.map((s) => s.id).toSet();
      final categoryIds = mockCategories.map((c) => c.id).toSet();
      final unitIds = mockUnits.map((u) => u.id).toSet();

      for (final item in mockItems) {
        expect(storeIds, contains(item.storeId), reason: '${item.name} store');
        expect(
          categoryIds,
          contains(item.categoryId),
          reason: '${item.name} category',
        );
        expect(unitIds, contains(item.unitId), reason: '${item.name} unit');
      }
    });

    test('item categories and units belong to the same store as the item', () {
      for (final item in mockItems) {
        expect(
          MockQueries.categoryById(item.categoryId)!.storeId,
          item.storeId,
          reason: '${item.name} uses another store\'s category',
        );
        expect(
          MockQueries.unitById(item.unitId)!.storeId,
          item.storeId,
          reason: '${item.name} uses another store\'s unit',
        );
      }
    });

    test('every supplier price points at a real item and supplier', () {
      final itemIds = mockItems.map((i) => i.id).toSet();
      final supplierIds = mockSuppliers.map((s) => s.id).toSet();

      for (final price in mockSupplierPrices) {
        expect(itemIds, contains(price.itemId), reason: price.id);
        expect(supplierIds, contains(price.supplierId), reason: price.id);
      }
    });

    test(
      'every price history entry matches an existing item-supplier link',
      () {
        for (final entry in mockPriceHistory) {
          expect(
            MockQueries.priceFor(entry.itemId, entry.supplierId),
            isNotNull,
            reason: '${entry.id} has history but no current price',
          );
        }
      },
    );

    test(
      'every movement points at a real item, and deliveries at a supplier',
      () {
        final itemIds = mockItems.map((i) => i.id).toSet();
        final supplierIds = mockSuppliers.map((s) => s.id).toSet();

        for (final movement in mockStockMovements) {
          expect(itemIds, contains(movement.itemId), reason: movement.id);

          if (movement.type == StockMovementType.stockIn) {
            expect(
              supplierIds,
              contains(movement.supplierId),
              reason: '${movement.id} is a delivery with no valid supplier',
            );
          }
        }
      },
    );

    test('notifications point at real stores', () {
      final storeIds = mockStores.map((s) => s.id).toSet();

      for (final notification in mockNotifications) {
        expect(storeIds, contains(notification.storeId));
      }
    });

    test('every item is priced by at least one supplier', () {
      for (final item in mockItems) {
        expect(
          MockQueries.pricesForItem(item.id),
          isNotEmpty,
          reason: '${item.name} has no supplier price, so it cannot be valued',
        );
      }
    });

    test('an item has at most one default supplier', () {
      for (final item in mockItems) {
        final defaults = MockQueries.pricesForItem(
          item.id,
        ).where((p) => p.isDefault).length;
        expect(defaults, lessThanOrEqualTo(1), reason: item.name);
      }
    });
  });

  group('movement field usage matches its type', () {
    test('deliveries carry a price, usage carries a reason', () {
      for (final movement in mockStockMovements) {
        switch (movement.type) {
          case StockMovementType.stockIn:
            expect(movement.unitPrice, isNotNull, reason: movement.id);
            expect(movement.quantity, greaterThan(0), reason: movement.id);
          case StockMovementType.stockOut:
            expect(movement.reason, isNotNull, reason: movement.id);
            expect(movement.quantity, lessThan(0), reason: movement.id);
          case StockMovementType.adjustment:
            expect(movement.systemQuantity, isNotNull, reason: movement.id);
            expect(movement.countedQuantity, isNotNull, reason: movement.id);
        }
      }
    });
  });

  group('the dataset demos what it needs to', () {
    test('all three stock statuses appear in the flagship store', () {
      final statuses = MockQueries.itemsForStore(
        StoreIds.sablon,
      ).map(stockStatusOf).toSet();

      expect(statuses, containsAll(StockStatus.values));
    });

    test('the new store is empty, so empty states can be demoed', () {
      expect(MockQueries.itemsForStore(StoreIds.saintGilles), isEmpty);
    });

    test('at least one item has three competing suppliers', () {
      final multiSupplier = mockItems.where(
        (item) => MockQueries.pricesForItem(item.id).length >= 3,
      );

      expect(multiSupplier, isNotEmpty);
    });

    test('at least one item is on a default supplier that is not cheapest', () {
      // Without this the price comparison report opens on nothing to say, and
      // it is the feature the app is sold on.
      final overpaying = mockItems.where(
        (item) => MockQueries.overpayPerUnit(item.id) > 0,
      );

      expect(overpaying, isNotEmpty);
    });

    test('stores hold different inventories, proving scoping is visible', () {
      final sablon = MockQueries.itemsForStore(StoreIds.sablon);
      final liege = MockQueries.itemsForStore(StoreIds.liege);

      expect(sablon, isNotEmpty);
      expect(liege, isNotEmpty);
      expect(sablon.length, isNot(liege.length));
    });
  });
}
