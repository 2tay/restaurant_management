// Items and stock movements.
//
// The rule these exist to defend:
//
//   **Every change to an item's quantity is a stock movement.**
//
// If that ever stops holding, the movement log becomes a partial record that
// looks complete — worse than no log at all, because people would trust it.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/core/utils/stock_status.dart';
import 'package:stock_inventory/mock_data/mock_data.dart';
import 'package:stock_inventory/models/models.dart';

import 'support/mock_reset.dart';

/// Quantity as reconstructed from the log alone.
///
/// The invariant every test in this file leans on: an item's quantity is the
/// sum of its movements, because it starts at zero and only movements change
/// it. Seeded items have a head start, so the caller supplies it.
double sumOfMovements(String itemId) {
  var total = 0.0;
  for (final movement in MockQueries.movementsForItem(itemId)) {
    total += movement.quantity;
  }
  return total;
}

void main() {
  setUp(restoreMockData);

  group('creating an item', () {
    test('records the starting quantity as an opening balance', () {
      final created = ItemMutations.create(
        storeId: StoreIds.sablon,
        name: 'Chicons',
        categoryId: CategoryIds.legumes,
        unitId: UnitIds.kg,
        quantity: 12,
        lowStockThreshold: 4,
      );

      expect(created, isNotNull);
      expect(created!.quantity, 12);

      // Not written onto the item: recorded, then applied. A newly created
      // article's history opens with a line explaining where its stock came
      // from rather than an unexplained 12 with no entries.
      final movements = MockQueries.movementsForItem(created.id);
      expect(movements.length, 1);
      expect(movements.single.type, StockMovementType.adjustment);
      expect(movements.single.systemQuantity, 0);
      expect(movements.single.countedQuantity, 12);
      expect(sumOfMovements(created.id), 12);
    });

    test('records nothing when it starts empty', () {
      final created = ItemMutations.create(
        storeId: StoreIds.sablon,
        name: 'Chicons',
        categoryId: CategoryIds.legumes,
        unitId: UnitIds.kg,
        quantity: 0,
        lowStockThreshold: 4,
      )!;

      expect(created.quantity, 0);
      expect(MockQueries.movementsForItem(created.id), isEmpty);
    });

    test('refuses a barcode another item already has', () {
      final taken = MockQueries.itemById(ItemIds.jupiler)!.barcode!;

      expect(
        ItemMutations.create(
          storeId: StoreIds.sablon,
          name: 'Jupiler bis',
          categoryId: CategoryIds.boissons,
          unitId: UnitIds.bac,
          quantity: 0,
          lowStockThreshold: 1,
          barcode: taken,
        ),
        isNull,
      );
    });

    test('stores an empty barcode as null rather than as an empty string', () {
      final created = ItemMutations.create(
        storeId: StoreIds.sablon,
        name: 'Chicons',
        categoryId: CategoryIds.legumes,
        unitId: UnitIds.kg,
        quantity: 0,
        lowStockThreshold: 4,
        barcode: '   ',
      )!;

      expect(created.barcode, isNull);
    });
  });

  group('editing an item', () {
    test('cannot change the quantity', () {
      final before = MockQueries.itemById(ItemIds.tomates)!.quantity;

      ItemMutations.update(ItemIds.tomates, name: 'Tomates grappe');

      expect(MockQueries.itemById(ItemIds.tomates)!.name, 'Tomates grappe');
      expect(
        MockQueries.itemById(ItemIds.tomates)!.quantity,
        before,
        reason: 'stock moves through the movement log and nowhere else',
      );
    });

    test('keeps its own barcode without colliding with itself', () {
      final jupiler = MockQueries.itemById(ItemIds.jupiler)!;

      expect(
        ItemMutations.update(jupiler.id, barcode: jupiler.barcode),
        isNotNull,
      );
    });

    test('refuses another item\'s barcode', () {
      final taken = MockQueries.itemById(ItemIds.jupiler)!.barcode!;

      expect(ItemMutations.update(ItemIds.cola, barcode: taken), isNull);
      expect(
        MockQueries.itemById(ItemIds.cola)!.barcode,
        isNot(taken),
        reason: 'a refused edit must not half-apply',
      );
    });

    test('can clear a barcode', () {
      ItemMutations.update(ItemIds.jupiler, clearBarcode: true);
      expect(MockQueries.itemById(ItemIds.jupiler)!.barcode, isNull);
    });
  });

  group('deleting an item', () {
    test('is refused while it is on an open order', () {
      // Poulet is on the sent Grossiste Central commande.
      expect(
        ItemMutations.deleteBlockedBy(ItemIds.poulet),
        ItemDeleteBlock.onOpenOrder,
      );
      expect(ItemMutations.delete(ItemIds.poulet), isFalse);
      expect(MockQueries.itemById(ItemIds.poulet), isNotNull);
    });

    test('cascades to its links, price history and movements', () {
      const id = ItemIds.tomates;
      expect(MockQueries.pricesForItem(id), isNotEmpty);
      expect(MockQueries.movementsForItem(id), isNotEmpty);

      expect(ItemMutations.delete(id), isTrue);

      expect(MockQueries.itemById(id), isNull);
      expect(MockQueries.pricesForItem(id), isEmpty);
      expect(MockQueries.movementsForItem(id), isEmpty);
      expect(
        mockPriceHistory.where((entry) => entry.itemId == id),
        isEmpty,
      );
    });

    test('leaves no movement pointing at an item that no longer exists', () {
      for (final item in List.of(mockItems)) {
        ItemMutations.delete(item.id);
      }

      for (final movement in mockStockMovements) {
        expect(
          MockQueries.itemById(movement.itemId),
          isNotNull,
          reason: '${movement.id} was orphaned',
        );
      }
    });
  });

  group('stock movements are the only writer of quantity', () {
    test('a delivery raises it and the log agrees', () {
      final before = MockQueries.itemById(ItemIds.tomates)!.quantity;

      MovementMutations.recordStockIn(
        storeId: StoreIds.sablon,
        itemId: ItemIds.tomates,
        quantity: 20,
        supplierId: SupplierIds.maraicher,
        unitPrice: 3.20,
      );

      expect(MockQueries.itemById(ItemIds.tomates)!.quantity, before + 20);
      expect(mockStockMovements.first.type, StockMovementType.stockIn);
      expect(mockStockMovements.first.quantity, 20);
    });

    test('a manual delivery carries no order reference', () {
      final movement = MovementMutations.recordStockIn(
        storeId: StoreIds.sablon,
        itemId: ItemIds.tomates,
        quantity: 5,
        supplierId: SupplierIds.maraicher,
      );

      // This is how the history tells "received against a commande" apart from
      // "somebody went to the market".
      expect(movement.orderId, isNull);
      expect(movement.receiptId, isNull);
    });

    test('a stock-out lowers it and is stored negative', () {
      final before = MockQueries.itemById(ItemIds.tomates)!.quantity;

      final movement = MovementMutations.recordStockOut(
        storeId: StoreIds.sablon,
        itemId: ItemIds.tomates,
        quantity: 3,
        reason: StockOutReason.sale,
      );

      expect(movement.quantity, -3);
      expect(MockQueries.itemById(ItemIds.tomates)!.quantity, before - 3);
    });

    test('a stock-out may take an item below zero', () {
      final item = MockQueries.itemById(ItemIds.tomates)!;

      MovementMutations.recordStockOut(
        storeId: StoreIds.sablon,
        itemId: item.id,
        quantity: item.quantity + 4,
        reason: StockOutReason.waste,
      );

      final after = MockQueries.itemById(item.id)!;
      expect(
        after.quantity,
        -4,
        reason: 'recording what actually left beats keeping the number tidy',
      );
      // Whatever the sign, the status still reads correctly.
      expect(stockStatusOf(after), StockStatus.outOfStock);
    });

    test('an adjustment records both figures and lands on the counted one', () {
      final item = MockQueries.itemById(ItemIds.pommesTerre)!;

      final movement = MovementMutations.recordAdjustment(
        storeId: StoreIds.sablon,
        itemId: item.id,
        systemQuantity: item.quantity,
        countedQuantity: 31,
      );

      expect(movement.systemQuantity, item.quantity);
      expect(movement.countedQuantity, 31);
      expect(movement.quantity, 31 - item.quantity);
      expect(MockQueries.itemById(item.id)!.quantity, 31);
    });

    test('quantity always equals the sum of the log', () {
      final created = ItemMutations.create(
        storeId: StoreIds.sablon,
        name: 'Chicons',
        categoryId: CategoryIds.legumes,
        unitId: UnitIds.kg,
        quantity: 10,
        lowStockThreshold: 4,
      )!;

      // An arbitrary sequence: deliveries, usage, a correction.
      MovementMutations.recordStockIn(
        storeId: StoreIds.sablon,
        itemId: created.id,
        quantity: 6,
      );
      MovementMutations.recordStockOut(
        storeId: StoreIds.sablon,
        itemId: created.id,
        quantity: 2.5,
        reason: StockOutReason.sale,
      );
      MovementMutations.recordAdjustment(
        storeId: StoreIds.sablon,
        itemId: created.id,
        systemQuantity: MockQueries.itemById(created.id)!.quantity,
        countedQuantity: 9,
      );
      MovementMutations.recordStockOut(
        storeId: StoreIds.sablon,
        itemId: created.id,
        quantity: 1,
        reason: StockOutReason.spoilage,
      );

      expect(MockQueries.itemById(created.id)!.quantity, 8);
      expect(sumOfMovements(created.id), 8);
    });

    test('receiving a delivery uses the same recorder', () {
      final before = MockQueries.itemById(ItemIds.poulet)!.quantity;

      OrderMutations.confirmReceipt(
        orderId: OrderIds.sentGrossiste,
        lines: const [
          ReceiptDraftLine(
            itemId: ItemIds.poulet,
            quantityOrdered: 15,
            quantityReceived: 15,
            orderedUnitPrice: 12.80,
            actualUnitPrice: 12.80,
          ),
        ],
      );

      final movement = mockStockMovements.first;
      expect(MockQueries.itemById(ItemIds.poulet)!.quantity, before + 15);
      expect(movement.type, StockMovementType.stockIn);
      // The receipt path differs from the manual one only in carrying
      // references, which is the entire point of having one log.
      expect(movement.orderId, OrderIds.sentGrossiste);
      expect(movement.receiptId, isNotNull);
    });
  });
}
