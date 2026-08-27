// The Phase 1.6 ordering rules, exercised against the in-memory layer.
//
// These are the rules Phase 2 will reimplement against real storage, so they
// are worth pinning now — the screens are cheap to rebuild, the semantics are
// not. The one they all defend:
//
//   **An order never changes stock. Only a receipt does.**
//
// The mock lists are global and mutable, so every test restores them — see
// test/support/mock_reset.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/core/utils/order_status.dart';
import 'package:stock_inventory/mock_data/mock_data.dart';
import 'package:stock_inventory/models/models.dart';

import 'support/mock_reset.dart';

double quantityOf(String itemId) => MockQueries.itemById(itemId)!.quantity;

void main() {
  setUp(restoreMockData);

  group('barcodes', () {
    test('are unique across the items of a store', () {
      final seen = <String, Map<String, String>>{};

      for (final item in mockItems) {
        final barcode = item.barcode;
        if (barcode == null) continue;
        final byStore = seen.putIfAbsent(item.storeId, () => {});
        expect(
          byStore.containsKey(barcode),
          isFalse,
          reason:
              '$barcode is on both ${byStore[barcode]} and ${item.name} '
              'in ${item.storeId}',
        );
        byStore[barcode] = item.name;
      }
    });

    test('are optional, and absent on fresh produce', () {
      final withBarcode = mockItems.where((i) => i.barcode != null).length;

      expect(withBarcode, greaterThan(0));
      expect(
        withBarcode,
        lessThan(mockItems.length),
        reason: 'an app where everything has one would not prove it is optional',
      );

      // Produce arrives loose in the supplier's crates. If this ever gains a
      // barcode it means somebody treated the field as required.
      expect(MockQueries.itemById(ItemIds.tomates)!.barcode, isNull);
      expect(MockQueries.itemById(ItemIds.poulet)!.barcode, isNull);
      expect(MockQueries.itemById(ItemIds.jupiler)!.barcode, isNotNull);
    });

    test('lookup returns a collection, not a single item', () {
      final barcode = MockQueries.itemById(ItemIds.jupiler)!.barcode!;
      final matches = MockQueries.itemsWithBarcode(StoreIds.sablon, barcode);

      // The shape is the point: multiple barcodes per item is the likeliest
      // next requirement, and a collection absorbs it.
      expect(matches, isA<List<Item>>());
      expect(matches.single.id, ItemIds.jupiler);
    });

    test('conflict detection ignores the item being edited', () {
      final jupiler = MockQueries.itemById(ItemIds.jupiler)!;

      expect(
        MockQueries.barcodeConflict(StoreIds.sablon, jupiler.barcode!),
        isNotNull,
        reason: 'a new item using this code collides',
      );
      expect(
        MockQueries.barcodeConflict(
          StoreIds.sablon,
          jupiler.barcode!,
          excludingItemId: jupiler.id,
        ),
        isNull,
        reason: 'saving an item with its own barcode unchanged must work',
      );
    });

    test('the same barcode in another store is not a conflict', () {
      final shared = MockQueries.itemById(ItemIds.liegeJupiler)!.barcode;

      expect(shared, MockQueries.itemById(ItemIds.jupiler)!.barcode);
      expect(
        MockQueries.itemsWithBarcode(StoreIds.liege, shared!).single.id,
        ItemIds.liegeJupiler,
      );
    });

    test('search matches an exact barcode but not a fragment', () {
      final item = MockQueries.itemById(ItemIds.cola)!;
      final barcode = item.barcode!;

      expect(MockQueries.itemMatchesSearch(item, barcode.toLowerCase()), isTrue);
      expect(
        MockQueries.itemMatchesSearch(item, barcode.substring(0, 6)),
        isFalse,
        reason: 'a partial barcode is not a barcode',
      );
      expect(MockQueries.itemMatchesSearch(item, 'coca'), isTrue);
    });
  });

  group('an order never moves stock', () {
    test('creating a draft leaves quantities alone', () {
      final before = quantityOf(ItemIds.tomates);

      OrderMutations.createDraft(
        storeId: StoreIds.sablon,
        supplierId: SupplierIds.maraicher,
        lines: const [
          PurchaseOrderLine(
            id: 'test-line',
            itemId: ItemIds.tomates,
            quantityOrdered: 50,
            unitPrice: 3.20,
          ),
        ],
      );

      expect(quantityOf(ItemIds.tomates), before);
    });

    test('sending an order leaves quantities alone', () {
      final before = quantityOf(ItemIds.tomates);
      final movementsBefore = mockStockMovements.length;

      OrderMutations.send(OrderIds.draftMaraicher);

      expect(
        MockQueries.orderById(OrderIds.draftMaraicher)!.status,
        PurchaseOrderStatus.sent,
      );
      expect(quantityOf(ItemIds.tomates), before);
      expect(mockStockMovements.length, movementsBefore);
    });

    test('but it does count towards on-order', () {
      final before = MockQueries.onOrderQuantity(
        StoreIds.sablon,
        ItemIds.tomates,
      );

      OrderMutations.send(OrderIds.draftMaraicher);

      expect(
        MockQueries.onOrderQuantity(StoreIds.sablon, ItemIds.tomates),
        before + 20,
        reason: 'a draft is not on order; a sent order is',
      );
    });
  });

  group('status transitions', () {
    test('a sent order is locked against editing', () {
      OrderMutations.send(OrderIds.draftMaraicher);
      final order = MockQueries.orderById(OrderIds.draftMaraicher)!;

      expect(orderIsEditable(order), isFalse);

      OrderMutations.updateDraft(order.id, lines: const []);
      expect(
        MockQueries.orderById(order.id)!.lines, isNotEmpty,
        reason: 'the supplier already holds this document',
      );
    });

    test('a draft can be deleted; a sent order cannot', () {
      OrderMutations.deleteDraft(OrderIds.draftMaraicher);
      expect(MockQueries.orderById(OrderIds.draftMaraicher), isNull);

      OrderMutations.deleteDraft(OrderIds.sentGrossiste);
      expect(MockQueries.orderById(OrderIds.sentGrossiste), isNotNull);
    });

    test('a sent order can be cancelled only before anything arrives', () {
      expect(orderCanCancel(MockQueries.orderById(OrderIds.sentGrossiste)!), isTrue);

      // Partially received: cancelling would orphan the stock movements the
      // delivered lines already created.
      expect(
        orderCanCancel(MockQueries.orderById(OrderIds.partialBoucherie)!),
        isFalse,
      );

      OrderMutations.cancel(OrderIds.partialBoucherie);
      expect(
        MockQueries.orderById(OrderIds.partialBoucherie)!.status,
        PurchaseOrderStatus.partial,
      );
    });

    test('closing short records the shortfall instead of erasing it', () {
      OrderMutations.closeShort(OrderIds.partialBoucherie);
      final order = MockQueries.orderById(OrderIds.partialBoucherie)!;

      expect(order.status, PurchaseOrderStatus.received);

      final jambon = order.lines.firstWhere(
        (line) => line.itemId == ItemIds.jambonArdenne,
      );
      expect(jambon.closedShort, isTrue);
      expect(
        jambon.quantityOrdered,
        5,
        reason: 'rewriting the order to what arrived would erase the evidence',
      );
      expect(lineShortfall(jambon), 5);

      // And it stops counting as on the way.
      expect(
        MockQueries.onOrderQuantity(StoreIds.sablon, ItemIds.jambonArdenne),
        0,
      );
    });
  });

  group('receiving', () {
    test('generates one stock movement per line and moves the stock', () {
      final before = quantityOf(ItemIds.poulet);
      final movementsBefore = mockStockMovements.length;

      OrderMutations.send(OrderIds.sentGrossiste);
      final receipt = OrderMutations.confirmReceipt(
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

      expect(quantityOf(ItemIds.poulet), before + 15);
      expect(mockStockMovements.length, movementsBefore + 1);

      final movement = mockStockMovements.first;
      expect(movement.type, StockMovementType.stockIn);
      expect(movement.quantity, 15);
      // The trail: quantity -> movement -> receipt -> order -> supplier.
      expect(movement.receiptId, receipt.id);
      expect(movement.orderId, OrderIds.sentGrossiste);
      expect(movement.supplierId, SupplierIds.grossisteCentral);
    });

    test('a partly delivered order stays open on the untouched lines', () {
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

      final order = MockQueries.orderById(OrderIds.sentGrossiste)!;
      expect(order.status, PurchaseOrderStatus.partial);
      expect(
        MockQueries.onOrderQuantity(StoreIds.sablon, ItemIds.poulet),
        0,
        reason: 'that line is complete',
      );
      expect(
        MockQueries.onOrderQuantity(StoreIds.sablon, ItemIds.riz),
        25,
        reason: 'the rice has not arrived',
      );
    });

    test('closing a line short settles it without inventing stock', () {
      final before = quantityOf(ItemIds.riz);

      OrderMutations.confirmReceipt(
        orderId: OrderIds.sentGrossiste,
        lines: const [
          ReceiptDraftLine(
            itemId: ItemIds.riz,
            quantityOrdered: 25,
            quantityReceived: 10,
            orderedUnitPrice: 1.95,
            actualUnitPrice: 1.95,
            closeShort: true,
          ),
        ],
      );

      expect(quantityOf(ItemIds.riz), before + 10);

      final line = MockQueries.orderById(OrderIds.sentGrossiste)!.lines
          .firstWhere((l) => l.itemId == ItemIds.riz);
      expect(line.closedShort, isTrue);
      expect(lineShortfall(line), 15);
      expect(MockQueries.onOrderQuantity(StoreIds.sablon, ItemIds.riz), 0);
    });

    test('receiving every line closes the order', () {
      final order = MockQueries.orderById(OrderIds.sentGrossiste)!;

      OrderMutations.confirmReceipt(
        orderId: order.id,
        lines: [
          for (final line in order.lines)
            ReceiptDraftLine(
              itemId: line.itemId,
              quantityOrdered: line.quantityOrdered,
              quantityReceived: line.quantityOrdered,
              orderedUnitPrice: line.unitPrice,
              actualUnitPrice: line.unitPrice,
            ),
        ],
      );

      expect(
        MockQueries.orderById(order.id)!.status,
        PurchaseOrderStatus.received,
      );
      expect(MockQueries.orderById(order.id)!.closedAt, isNotNull);
    });

    test('over-delivery is accepted and recorded', () {
      final before = quantityOf(ItemIds.mayonnaise);

      OrderMutations.confirmReceipt(
        orderId: OrderIds.sentGrossiste,
        lines: const [
          ReceiptDraftLine(
            itemId: ItemIds.mayonnaise,
            quantityOrdered: 10,
            quantityReceived: 14,
            orderedUnitPrice: 4.15,
            actualUnitPrice: 4.15,
          ),
        ],
      );

      expect(quantityOf(ItemIds.mayonnaise), before + 14);
      expect(
        outcomeOf(ordered: 10, received: 14, wasUnordered: false),
        ReceiptLineOutcome.over,
      );
    });

    test('an unordered line moves stock but never touches the order lines', () {
      final before = quantityOf(ItemIds.sel);
      final orderedBefore = MockQueries.orderById(
        OrderIds.sentGrossiste,
      )!.lines.length;

      final receipt = OrderMutations.confirmReceipt(
        orderId: OrderIds.sentGrossiste,
        lines: const [
          ReceiptDraftLine(
            itemId: ItemIds.sel,
            quantityOrdered: 0,
            quantityReceived: 5,
            orderedUnitPrice: 0.70,
            actualUnitPrice: 0.70,
            wasUnordered: true,
          ),
        ],
      );

      expect(quantityOf(ItemIds.sel), before + 5);
      expect(receipt.lines.single.wasUnordered, isTrue);
      expect(
        MockQueries.orderById(OrderIds.sentGrossiste)!.lines.length,
        orderedBefore,
        reason: 'an unordered arrival does not rewrite what was ordered',
      );
    });

    test('a confirmed receipt is attached to its order', () {
      final receipt = OrderMutations.confirmReceipt(
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

      expect(
        MockQueries.receiptsForOrder(OrderIds.sentGrossiste),
        contains(receipt),
      );
      expect(MockQueries.receiptById(receipt.id), receipt);
    });
  });

  group('what a delivery does to the value of the stock', () {
    // The bug this group exists for:
    //
    //   100 kg of chicken bought at 8,00 is worth 800. A van arrives with 50 kg
    //   at 10,00, which cost 500. The stock is worth 1 300.
    //
    // The app used to report 1 500 — quantity times the supplier's current
    // price — inventing 200 that nobody ever spent, on the one screen an owner
    // reads to find out what they are holding. A price drop invented a loss the
    // same way.

    test('the old stock keeps the price it was bought at', () {
      // Set the item up as the scenario describes rather than leaning on the
      // seed, so the arithmetic is readable in the failure message.
      final item = MockQueries.itemById(ItemIds.poulet)!;
      MovementMutations.recordAdjustment(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        systemQuantity: item.quantity,
        countedQuantity: 0,
      );
      MovementMutations.recordStockIn(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        quantity: 100,
        unitPrice: 8.00,
      );

      final held = MockQueries.itemById(ItemIds.poulet)!;
      expect(held.quantity, 100);
      expect(held.averageCost, closeTo(8.00, 0.001));

      OrderMutations.send(OrderIds.sentGrossiste);
      OrderMutations.confirmReceipt(
        orderId: OrderIds.sentGrossiste,
        lines: const [
          ReceiptDraftLine(
            itemId: ItemIds.poulet,
            quantityOrdered: 15,
            quantityReceived: 50,
            orderedUnitPrice: 12.80,
            actualUnitPrice: 10.00,
          ),
        ],
      );

      final after = MockQueries.itemById(ItemIds.poulet)!;
      expect(after.quantity, 150);
      expect(after.averageCost, closeTo(8.6667, 0.001));
      expect(
        after.quantity * after.averageCost!,
        closeTo(1300, 0.01),
        reason: '1 300 was spent; 1 500 is the bug',
      );
    });

    test('the supplier price still updates to what was charged', () {
      // The fix is not "stop updating the price". A price is what the *next*
      // unit will cost and it must follow the delivery note; a cost is what the
      // units on the shelf were paid for and must not.
      OrderMutations.send(OrderIds.sentGrossiste);
      OrderMutations.confirmReceipt(
        orderId: OrderIds.sentGrossiste,
        lines: const [
          ReceiptDraftLine(
            itemId: ItemIds.poulet,
            quantityOrdered: 15,
            quantityReceived: 15,
            orderedUnitPrice: 12.80,
            actualUnitPrice: 15.00,
          ),
        ],
      );

      expect(
        MockQueries.priceFor(ItemIds.poulet, SupplierIds.grossisteCentral)!
            .pricePerUnit,
        closeTo(15.00, 0.001),
      );
      // And the cost sits below it, because only 15 of the kilos on hand were
      // bought at 15,00.
      expect(
        MockQueries.itemById(ItemIds.poulet)!.averageCost,
        lessThan(15.00),
      );
    });

    test('two deliveries at two prices average across all of it', () {
      final item = MockQueries.itemById(ItemIds.poulet)!;
      MovementMutations.recordAdjustment(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        systemQuantity: item.quantity,
        countedQuantity: 0,
      );

      OrderMutations.send(OrderIds.sentGrossiste);
      for (final price in const [8.00, 12.00]) {
        OrderMutations.confirmReceipt(
          orderId: OrderIds.sentGrossiste,
          lines: [
            ReceiptDraftLine(
              itemId: ItemIds.poulet,
              quantityOrdered: 15,
              quantityReceived: 50,
              orderedUnitPrice: 12.80,
              actualUnitPrice: price,
            ),
          ],
        );
      }

      // 400 + 600 spent on 100 kg.
      final after = MockQueries.itemById(ItemIds.poulet)!;
      expect(after.quantity, 100);
      expect(after.averageCost, closeTo(10.00, 0.001));
    });

    test('the receipt movement carries the cost it applied', () {
      OrderMutations.send(OrderIds.sentGrossiste);
      final receipt = OrderMutations.confirmReceipt(
        orderId: OrderIds.sentGrossiste,
        lines: const [
          ReceiptDraftLine(
            itemId: ItemIds.poulet,
            quantityOrdered: 15,
            quantityReceived: 15,
            orderedUnitPrice: 12.80,
            actualUnitPrice: 15.00,
          ),
        ],
      );

      // Receiving goes through the same single writer as a manual stock-in, so
      // it produces the same audit trail rather than a second kind of movement.
      final movement = mockStockMovements.first;
      expect(movement.receiptId, receipt.id);
      expect(movement.unitCost, closeTo(15.00, 0.001));
      expect(
        movement.averageCostAfter,
        closeTo(MockQueries.itemById(ItemIds.poulet)!.averageCost!, 0.001),
      );
    });

    test('an unordered item with no price on file still gets a cost', () {
      OrderMutations.send(OrderIds.sentGrossiste);
      OrderMutations.confirmReceipt(
        orderId: OrderIds.sentGrossiste,
        lines: const [
          ReceiptDraftLine(
            itemId: ItemIds.persil,
            quantityOrdered: 0,
            quantityReceived: 4,
            orderedUnitPrice: 0,
            actualUnitPrice: 1.50,
            wasUnordered: true,
          ),
        ],
      );

      final movement = mockStockMovements.first;
      expect(movement.itemId, ItemIds.persil);
      expect(movement.unitCost, closeTo(1.50, 0.001));
      expect(MockQueries.itemById(ItemIds.persil)!.averageCost, isNotNull);
    });
  });

  group('prices captured at receiving', () {
    test('a changed price updates the supplier price and writes history', () {
      final before = MockQueries.priceFor(
        ItemIds.poulet,
        SupplierIds.grossisteCentral,
      )!.pricePerUnit;
      final historyBefore = MockQueries.priceHistoryFor(
        ItemIds.poulet,
        SupplierIds.grossisteCentral,
      ).length;

      OrderMutations.confirmReceipt(
        orderId: OrderIds.sentGrossiste,
        lines: const [
          ReceiptDraftLine(
            itemId: ItemIds.poulet,
            quantityOrdered: 15,
            quantityReceived: 15,
            orderedUnitPrice: 12.80,
            actualUnitPrice: 14.50,
          ),
        ],
      );

      expect(
        MockQueries.priceFor(
          ItemIds.poulet,
          SupplierIds.grossisteCentral,
        )!.pricePerUnit,
        14.50,
      );

      final history = MockQueries.priceHistoryFor(
        ItemIds.poulet,
        SupplierIds.grossisteCentral,
      );
      expect(history.length, historyBefore + 1);
      expect(history.first.oldPrice, before);
      expect(history.first.newPrice, 14.50);
    });

    test('an unchanged price writes nothing', () {
      final historyBefore = MockQueries.priceHistoryFor(
        ItemIds.poulet,
        SupplierIds.grossisteCentral,
      ).length;

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

      expect(
        MockQueries.priceHistoryFor(
          ItemIds.poulet,
          SupplierIds.grossisteCentral,
        ).length,
        historyBefore,
      );
    });

    test('the significant-change threshold is 15% and symmetric', () {
      expect(OrderRules.significantPriceChange, 0.15);

      expect(priceMovedSignificantly(10, 11), isFalse);
      expect(priceMovedSignificantly(10, 12), isTrue);
      expect(priceMovedSignificantly(10, 8), isTrue);

      // No baseline to move from: a first delivery must not be flagged.
      expect(priceMovedSignificantly(0, 20), isFalse);
    });
  });

  group('stale partial orders', () {
    test('the threshold defaults to seven days and drives the flag', () {
      expect(MockSettings.stalePartialOrderDays, 7);
      expect(OrderRules.defaultStalePartialDays, 7);

      final stale = MockQueries.staleOrders(StoreIds.sablon);
      expect(
        stale.map((o) => o.id),
        contains(OrderIds.partialBoucherie),
        reason: 'sent nine days ago and still partial',
      );

      // Raising it past the age of the order clears the flag.
      MockSettings.stalePartialOrderDays = 60;
      expect(MockQueries.staleOrders(StoreIds.sablon), isEmpty);
    });

    test('only partial orders are ever stale', () {
      MockSettings.stalePartialOrderDays = 1;

      for (final order in MockQueries.staleOrders(StoreIds.sablon)) {
        expect(order.status, PurchaseOrderStatus.partial);
      }
    });
  });

  group('the seeded dataset supports the walkthrough', () {
    test('covers every status', () {
      final statuses = MockQueries.ordersForStore(
        StoreIds.sablon,
      ).map((o) => o.status).toSet();

      expect(statuses, containsAll(PurchaseOrderStatus.values));
    });

    test('covers every receipt outcome', () {
      final outcomes = <ReceiptLineOutcome>{};
      var closedShort = 0;
      var priceChanges = 0;

      for (final receipt in mockGoodsReceipts) {
        for (final line in receipt.lines) {
          outcomes.add(
            outcomeOf(
              ordered: line.quantityOrdered,
              received: line.quantityReceived,
              wasUnordered: line.wasUnordered,
            ),
          );
          if (line.closedShort) closedShort++;

          final order = MockQueries.orderById(receipt.orderId)!;
          final ordered = order.lines
              .where((l) => l.itemId == line.itemId)
              .firstOrNull;
          if (ordered != null &&
              (ordered.unitPrice - line.actualUnitPrice).abs() > 0.001) {
            priceChanges++;
          }
        }
      }

      expect(outcomes, containsAll(ReceiptLineOutcome.values));
      expect(closedShort, greaterThan(0));
      expect(priceChanges, greaterThan(0));
    });

    test('every seeded receipt line refers to a real item', () {
      for (final receipt in mockGoodsReceipts) {
        expect(MockQueries.orderById(receipt.orderId), isNotNull);
        for (final line in receipt.lines) {
          expect(
            MockQueries.itemById(line.itemId),
            isNotNull,
            reason: '${line.itemId} on ${receipt.id}',
          );
        }
      }
    });

    test('every seeded order line refers to an item its supplier supplies', () {
      for (final order in mockPurchaseOrders) {
        for (final line in order.lines) {
          expect(
            MockQueries.priceFor(line.itemId, order.supplierId),
            isNotNull,
            reason:
                '${order.reference} orders ${line.itemId} from a supplier with '
                'no price on file — the line builder could not have produced it',
          );
        }
      }
    });

    test('receipt-generated movements point at a real receipt and order', () {
      final generated = mockStockMovements.where((m) => m.receiptId != null);
      expect(generated, isNotEmpty);

      for (final movement in generated) {
        expect(MockQueries.receiptById(movement.receiptId!), isNotNull);
        expect(MockQueries.orderById(movement.orderId!), isNotNull);
        expect(movement.type, StockMovementType.stockIn);
      }
    });

    test('the manual stock-in path still exists alongside it', () {
      final manual = mockStockMovements.where(
        (m) => m.type == StockMovementType.stockIn && m.receiptId == null,
      );

      expect(
        manual,
        isNotEmpty,
        reason:
            'somebody buying 5 kg of tomatoes at the market with no order '
            'behind it must still be recordable',
      );
    });
  });
}
