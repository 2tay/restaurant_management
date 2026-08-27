// The write foundation: change signal, id generation, and the snapshot that
// lets a demo be walked twice.
//
// Worth pinning because everything else in the mutation layer stands on it. A
// reset that silently misses a list would show up as a demo that gets stranger
// the longer it runs, which is exactly the kind of bug nobody reports.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/mock_data/mock_data.dart';
import 'package:stock_inventory/models/models.dart';

import 'support/mock_reset.dart';

void main() {
  setUp(restoreMockData);

  group('the change signal', () {
    test('climbs on every write', () {
      final before = MockWrite.revision.value;

      OrderMutations.send(OrderIds.draftMaraicher);

      expect(MockWrite.revision.value, greaterThan(before));
    });

    test('reports whether there is anything to undo', () {
      expect(MockWrite.hasChanges, isFalse);

      OrderMutations.send(OrderIds.draftMaraicher);
      expect(MockWrite.hasChanges, isTrue);

      MockWrite.reset();
      expect(MockWrite.hasChanges, isFalse);
    });

    test('keeps climbing across a reset', () {
      OrderMutations.send(OrderIds.draftMaraicher);
      final afterWrite = MockWrite.revision.value;

      MockWrite.reset();

      // The counter must move even though the data went backwards, or screens
      // listening to it would keep showing the changed data after a reset.
      expect(MockWrite.revision.value, greaterThan(afterWrite));
    });
  });

  group('generated ids', () {
    test('are unique and identifiable', () {
      final ids = {for (var i = 0; i < 50; i++) MockWrite.id('item')};

      expect(ids.length, 50);
      expect(ids.every((id) => id.startsWith('item-new-')), isTrue);
    });

    test('do not collide with the seeded ids', () {
      final seeded = mockItems.map((item) => item.id).toSet();

      for (var i = 0; i < 20; i++) {
        expect(seeded.contains(MockWrite.id('item')), isFalse);
      }
    });
  });

  group('reset', () {
    test('puts every list back', () {
      final counts = _snapshotCounts();

      // Touch as much as one action can: a receipt writes a receipt, movements,
      // item quantities, a supplier price and a price-history entry, and moves
      // the order's status.
      OrderMutations.confirmReceipt(
        orderId: OrderIds.sentGrossiste,
        lines: const [
          ReceiptDraftLine(
            itemId: ItemIds.poulet,
            quantityOrdered: 15,
            quantityReceived: 15,
            orderedUnitPrice: 12.80,
            actualUnitPrice: 15.90,
          ),
        ],
      );
      OrderMutations.deleteDraft(OrderIds.draftMaraicher);

      expect(_snapshotCounts(), isNot(counts), reason: 'the test did nothing');

      MockWrite.reset();

      expect(_snapshotCounts(), counts);
    });

    test('restores values, not just list lengths', () {
      final quantity = MockQueries.itemById(ItemIds.poulet)!.quantity;
      final price = MockQueries.priceFor(
        ItemIds.poulet,
        SupplierIds.grossisteCentral,
      )!.pricePerUnit;

      OrderMutations.confirmReceipt(
        orderId: OrderIds.sentGrossiste,
        lines: const [
          ReceiptDraftLine(
            itemId: ItemIds.poulet,
            quantityOrdered: 15,
            quantityReceived: 15,
            orderedUnitPrice: 12.80,
            actualUnitPrice: 15.90,
          ),
        ],
      );

      expect(MockQueries.itemById(ItemIds.poulet)!.quantity, quantity + 15);

      MockWrite.reset();

      expect(MockQueries.itemById(ItemIds.poulet)!.quantity, quantity);
      expect(
        MockQueries.priceFor(
          ItemIds.poulet,
          SupplierIds.grossisteCentral,
        )!.pricePerUnit,
        price,
      );
    });

    test('restores a deleted record rather than leaving a hole', () {
      OrderMutations.deleteDraft(OrderIds.draftMaraicher);
      expect(MockQueries.orderById(OrderIds.draftMaraicher), isNull);

      MockWrite.reset();

      final restored = MockQueries.orderById(OrderIds.draftMaraicher);
      expect(restored, isNotNull);
      expect(restored!.status, PurchaseOrderStatus.draft);
      expect(restored.lines.length, 3);
    });

    test('restores store settings', () {
      final before = MockQueries.storeSettings(StoreIds.sablon);
      AccountMutations.updateStoreSettings(
        StoreIds.sablon,
        stalePartialOrderDays: 42,
        maxBreakMinutes: 90,
      );
      expect(
        MockQueries.storeSettings(StoreIds.sablon).stalePartialOrderDays,
        42,
      );

      MockWrite.reset();

      final after = MockQueries.storeSettings(StoreIds.sablon);
      expect(after.stalePartialOrderDays, before.stalePartialOrderDays);
      expect(after.maxBreakMinutes, before.maxBreakMinutes);
    });

    test('covers every mutable list', () {
      // A new mutable mock list that nobody adds to the snapshot would leak
      // between demos and between tests. This is the check that catches it:
      // clearing everything and resetting has to bring all of it back.
      final counts = _snapshotCounts();

      for (final list in _mutableLists) {
        list.clear();
      }
      expect(_snapshotCounts().values.every((count) => count == 0), isTrue);

      MockWrite.reset();

      expect(_snapshotCounts(), counts);
    });
  });
}

/// Every mock list a mutation can touch, as the reset sees them.
List<List<Object>> get _mutableLists => [
  mockCategories,
  mockUnits,
  mockItems,
  mockSuppliers,
  mockSupplierPrices,
  mockPriceHistory,
  mockStockMovements,
  mockPurchaseOrders,
  mockGoodsReceipts,
  mockNotifications,
  mockStores,
  mockStoreSettings,
  mockEmployees,
  mockAttendances,
];

Map<String, int> _snapshotCounts() => {
  'categories': mockCategories.length,
  'units': mockUnits.length,
  'items': mockItems.length,
  'suppliers': mockSuppliers.length,
  'prices': mockSupplierPrices.length,
  'history': mockPriceHistory.length,
  'movements': mockStockMovements.length,
  'orders': mockPurchaseOrders.length,
  'receipts': mockGoodsReceipts.length,
  'notifications': mockNotifications.length,
  'stores': mockStores.length,
  'storeSettings': mockStoreSettings.length,
  'employees': mockEmployees.length,
  'attendances': mockAttendances.length,
};
