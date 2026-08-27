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

  group('valuation follows the stock', () {
    test('rises by what the delivery cost, not by what stock is worth now', () {
      // This used to assert `before + 10 × the supplier's current price`, which
      // is the bug: it valued the delivery at the price on file rather than at
      // the price paid, and — because the same price was then applied to every
      // unit on hand — silently revalued stock bought weeks earlier too.
      final before = MockQueries.stockValuation(StoreIds.sablon);

      MovementMutations.recordStockIn(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        quantity: 10,
        supplierId: SupplierIds.grossisteCentral,
        unitPrice: 15.00,
      );

      expect(
        MockQueries.stockValuation(StoreIds.sablon),
        closeTo(before + 10 * 15.00, 0.01),
      );
    });

    test('a delivery at a new price leaves the old stock alone', () {
      // The headline case, on a real seeded item. Whatever chicken was already
      // in the fridge keeps the value it had; only the 10 kg that arrived is
      // valued at 15,00.
      final item = MockQueries.itemById(ItemIds.poulet)!;
      final heldBefore = item.quantity * item.averageCost!;

      MovementMutations.recordStockIn(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        quantity: 10,
        supplierId: SupplierIds.grossisteCentral,
        unitPrice: 15.00,
      );

      final after = MockQueries.itemById(ItemIds.poulet)!;
      expect(
        after.quantity * after.averageCost!,
        closeTo(heldBefore + 150, 0.01),
      );

      // And the average lands between the two, never at either end.
      expect(after.averageCost, greaterThan(item.averageCost!));
      expect(after.averageCost, lessThan(15.00));
    });

    test('a delivery does not touch what the supplier charges', () {
      // The two numbers stay separate. A manual stock-in at 15,00 records what
      // was paid; it is not a negotiation, so the price on file is untouched.
      final priceBefore = MockQueries.defaultPriceForItem(
        ItemIds.poulet,
      )!.pricePerUnit;

      MovementMutations.recordStockIn(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        quantity: 10,
        supplierId: SupplierIds.grossisteCentral,
        unitPrice: 15.00,
      );

      expect(
        MockQueries.defaultPriceForItem(ItemIds.poulet)!.pricePerUnit,
        priceBefore,
      );
    });

    test('the category breakdown sums to the total', () {
      final rows = MockQueries.valuationByCategory(StoreIds.sablon);
      final sum = rows.fold<double>(0, (total, row) => total + row.totalValue);

      expect(sum, closeTo(MockQueries.stockValuation(StoreIds.sablon), 0.01));
      expect(
        rows.fold<double>(0, (total, row) => total + row.shareOfTotal),
        closeTo(1, 0.01),
      );
    });

    test('an item with no supplier contributes nothing rather than a guess', () {
      final created = ItemMutations.create(
        storeId: StoreIds.sablon,
        name: 'Chicons',
        categoryId: CategoryIds.legumes,
        unitId: UnitIds.kg,
        quantity: 50,
        lowStockThreshold: 4,
      )!;
      final before = MockQueries.stockValuation(StoreIds.sablon);

      expect(MockQueries.pricesForItem(created.id), isEmpty);
      expect(MockQueries.stockValuation(StoreIds.sablon), before);
    });

    test('an empty store is worth nothing rather than crashing', () {
      expect(MockQueries.stockValuation(StoreIds.saintGilles), 0);
      expect(MockQueries.valuationByCategory(StoreIds.saintGilles), isEmpty);
      expect(MockQueries.valuationByItem(StoreIds.saintGilles), isEmpty);
    });
  });

  group('an article starts with the cost it was bought at', () {
    test('the opening cost becomes the average cost', () {
      final created = ItemMutations.create(
        storeId: StoreIds.sablon,
        name: 'Chicons',
        categoryId: CategoryIds.legumes,
        unitId: UnitIds.kg,
        quantity: 50,
        openingUnitCost: 3.20,
        lowStockThreshold: 4,
      )!;

      expect(created.averageCost, closeTo(3.20, 0.001));
      expect(created.quantity, 50);
    });

    test('it is set by the opening movement, not written onto the item', () {
      // The single-writer rule reaches cost as well as quantity: the article's
      // first movement is what gives it a cost, so the log explains the number
      // from the article's first day.
      final created = ItemMutations.create(
        storeId: StoreIds.sablon,
        name: 'Chicons',
        categoryId: CategoryIds.legumes,
        unitId: UnitIds.kg,
        quantity: 50,
        openingUnitCost: 3.20,
        lowStockThreshold: 4,
      )!;

      final opening = MockQueries.movementsForItem(created.id).single;
      expect(opening.type, StockMovementType.adjustment);
      expect(opening.unitCost, closeTo(3.20, 0.001));
      expect(opening.averageCostAfter, closeTo(3.20, 0.001));
    });

    test('without one, the cost stays unknown rather than zero', () {
      final created = ItemMutations.create(
        storeId: StoreIds.sablon,
        name: 'Chicons',
        categoryId: CategoryIds.legumes,
        unitId: UnitIds.kg,
        quantity: 50,
        lowStockThreshold: 4,
      )!;

      // Not 0: an unknown cost and a free article are different claims, and
      // only one of them is true.
      expect(created.averageCost, isNull);
    });

    test('the first delivery gives an uncosted article its cost', () {
      final created = ItemMutations.create(
        storeId: StoreIds.sablon,
        name: 'Chicons',
        categoryId: CategoryIds.legumes,
        unitId: UnitIds.kg,
        quantity: 50,
        lowStockThreshold: 4,
      )!;
      final before = MockQueries.stockValuation(StoreIds.sablon);

      MovementMutations.recordStockIn(
        storeId: StoreIds.sablon,
        itemId: created.id,
        quantity: 20,
        unitPrice: 3.00,
      );

      // 70 kg on hand, all of it now costed at the only price ever paid.
      final after = MockQueries.itemById(created.id)!;
      expect(after.averageCost, closeTo(3.00, 0.001));
      expect(
        MockQueries.stockValuation(StoreIds.sablon),
        closeTo(before + 70 * 3.00, 0.01),
      );
    });
  });

  group('stock leaving never changes what the rest cost', () {
    test('a stock out leaves the average alone', () {
      final before = MockQueries.itemById(ItemIds.poulet)!.averageCost;

      MovementMutations.recordStockOut(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        quantity: 5,
        reason: StockOutReason.sale,
      );

      expect(MockQueries.itemById(ItemIds.poulet)!.averageCost, before);
    });

    test('the movement records what the stock that left had cost', () {
      final cost = MockQueries.itemById(ItemIds.poulet)!.averageCost!;

      MovementMutations.recordStockOut(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        quantity: 5,
        reason: StockOutReason.waste,
      );

      // Which is what makes a waste line answer "how many euros went in the
      // bin" rather than only "how many kilos".
      final movement = mockStockMovements.first;
      expect(movement.unitCost, closeTo(cost, 0.001));
      expect(movement.quantity.abs() * movement.unitCost!, closeTo(5 * cost, 0.01));
    });

    test('an adjustment leaves the average alone', () {
      final item = MockQueries.itemById(ItemIds.poulet)!;

      MovementMutations.recordAdjustment(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        systemQuantity: item.quantity,
        countedQuantity: item.quantity - 3,
      );

      // A count corrects a quantity. Nobody bought anything, so there is no new
      // price to average in.
      expect(
        MockQueries.itemById(ItemIds.poulet)!.averageCost,
        item.averageCost,
      );
    });
  });

  group('negative stock resets the cost rather than averaging into it', () {
    test('a delivery onto negative stock adopts the delivery price', () {
      final item = MockQueries.itemById(ItemIds.poulet)!;

      // Drive it below zero — allowed on purpose, and a signal that a delivery
      // went unrecorded.
      MovementMutations.recordStockOut(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        quantity: item.quantity + 5,
        reason: StockOutReason.sale,
      );
      expect(MockQueries.itemById(ItemIds.poulet)!.quantity, lessThan(0));

      MovementMutations.recordStockIn(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        quantity: 20,
        unitPrice: 15.00,
      );

      // Averaging against a baseline already known to be wrong would carry the
      // error forward instead of ending it — and could produce a negative
      // average, which is not a number anybody can act on.
      final after = MockQueries.itemById(ItemIds.poulet)!;
      expect(after.averageCost, closeTo(15.00, 0.001));
      expect(after.averageCost, greaterThan(0));
    });
  });

  group('what stock cost on the way out', () {
    test('waste is counted in euros, not only in kilos', () {
      final cost = MockQueries.itemById(ItemIds.poulet)!.averageCost!;
      final before = MockQueries.wasteValue(StoreIds.sablon);

      MovementMutations.recordStockOut(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        quantity: 4,
        reason: StockOutReason.waste,
      );

      expect(
        MockQueries.wasteValue(StoreIds.sablon),
        closeTo(before + 4 * cost, 0.01),
      );
    });

    test('a sale is consumption but not waste', () {
      final wasteBefore = MockQueries.wasteValue(StoreIds.sablon);
      final consumedBefore = MockQueries.consumptionValue(StoreIds.sablon);
      final cost = MockQueries.itemById(ItemIds.poulet)!.averageCost!;

      MovementMutations.recordStockOut(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        quantity: 4,
        reason: StockOutReason.sale,
      );

      expect(MockQueries.wasteValue(StoreIds.sablon), wasteBefore);
      expect(
        MockQueries.consumptionValue(StoreIds.sablon),
        closeTo(consumedBefore + 4 * cost, 0.01),
      );
    });

    test('stock found in a count is not a loss', () {
      final item = MockQueries.itemById(ItemIds.poulet)!;
      final before = MockQueries.shrinkageValue(StoreIds.sablon);

      MovementMutations.recordAdjustment(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        systemQuantity: item.quantity,
        countedQuantity: item.quantity + 6,
      );

      // Stock that was there all along and had simply not been recorded.
      expect(MockQueries.shrinkageValue(StoreIds.sablon), before);

      MovementMutations.recordAdjustment(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        systemQuantity: item.quantity + 6,
        countedQuantity: item.quantity,
      );

      expect(
        MockQueries.shrinkageValue(StoreIds.sablon),
        closeTo(before + 6 * item.averageCost!, 0.01),
      );
    });
  });

  group('what the movement log says about cost', () {
    test('every movement records the average it produced', () {
      MovementMutations.recordStockIn(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        quantity: 10,
        unitPrice: 15.00,
      );

      // The audit trail: the number is verifiable rather than one that changes
      // on its own.
      final movement = mockStockMovements.first;
      expect(movement.unitCost, closeTo(15.00, 0.001));
      expect(
        movement.averageCostAfter,
        closeTo(MockQueries.itemById(ItemIds.poulet)!.averageCost!, 0.001),
      );
    });

    test('a delivery with no price recorded leaves the average where it was',
        () {
      final before = MockQueries.itemById(ItemIds.poulet)!.averageCost!;

      MovementMutations.recordStockIn(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        quantity: 10,
      );

      // An unrecorded price is not a price of zero. Treating it as one would
      // drag the average towards nothing and quietly destroy the item's value.
      expect(
        MockQueries.itemById(ItemIds.poulet)!.averageCost,
        closeTo(before, 0.001),
      );
    });
  });
}
