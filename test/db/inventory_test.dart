// Stock movements: the log, and what it does to quantity and cost.
//
// The rule these exist to defend:
//
//   **Every change to an article's quantity is a stock movement.**
//
// If that ever stops holding, the movement log becomes a partial record that
// looks complete — worse than no log at all, because people would trust it.
//
// Ported from `test/inventory_test.dart`. Its three item-shaped groups moved to
// `items_test.dart` in stage 4, when the item writes arrived; its one test that
// receives a delivery against a commande waits for stage 6, which is where
// `confirmReceipt` lands.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/core/utils/stock_status.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/mock_data/mock_data.dart'
    show CategoryIds, ItemIds, StoreIds, SupplierIds, UnitIds;
import 'package:stock_inventory/models/models.dart';

import '../support/db_fixture.dart';

void main() {
  late AppDatabase db;
  late ItemRepository items;
  late MovementRepository movements;
  late SupplierRepository suppliers;
  late ReportRepository reports;

  setUp(() async {
    db = await openSeededDatabase();
    items = ItemRepository(db);
    movements = MovementRepository(db);
    suppliers = SupplierRepository(db);
    reports = ReportRepository(db);
  });

  Future<Item> poulet() async => (await items.item(ItemIds.poulet))!;

  /// The movement just recorded. Newest first, so the head of the log.
  Future<StockMovement> latestFor(String itemId) async =>
      (await movements.movementsForItem(itemId)).first;

  Future<double> sumOfMovements(String itemId) async {
    var total = 0.0;
    for (final movement in await movements.movementsForItem(itemId)) {
      total += movement.quantity;
    }
    return total;
  }

  Future<Item> chicons({
    double quantity = 0,
    double? openingUnitCost,
  }) async => (await items.create(
    storeId: StoreIds.sablon,
    name: 'Chicons',
    categoryId: CategoryIds.legumes,
    unitId: UnitIds.kg,
    quantity: quantity,
    lowStockThreshold: 4,
    openingUnitCost: openingUnitCost,
  ))!;

  group('stock movements are the only writer of quantity', () {
    test('a delivery raises it and the log agrees', () async {
      final before = (await items.item(ItemIds.tomates))!.quantity;

      await movements.recordStockIn(
        storeId: StoreIds.sablon,
        itemId: ItemIds.tomates,
        quantity: 20,
        supplierId: SupplierIds.maraicher,
        unitPrice: 3.20,
      );

      expect((await items.item(ItemIds.tomates))!.quantity, before + 20);
      final movement = await latestFor(ItemIds.tomates);
      expect(movement.type, StockMovementType.stockIn);
      expect(movement.quantity, 20);
    });

    test('a manual delivery carries no commande reference', () async {
      final movement = await movements.recordStockIn(
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

    test('a stock-out lowers it and is stored negative', () async {
      final before = (await items.item(ItemIds.tomates))!.quantity;

      final movement = await movements.recordStockOut(
        storeId: StoreIds.sablon,
        itemId: ItemIds.tomates,
        quantity: 3,
        reason: StockOutReason.sale,
      );

      expect(movement.quantity, -3);
      expect((await items.item(ItemIds.tomates))!.quantity, before - 3);
    });

    test('a stock-out may take an article below zero', () async {
      final item = (await items.item(ItemIds.tomates))!;

      await movements.recordStockOut(
        storeId: StoreIds.sablon,
        itemId: item.id,
        quantity: item.quantity + 4,
        reason: StockOutReason.waste,
      );

      final after = (await items.item(item.id))!;
      expect(
        after.quantity,
        -4,
        reason: 'recording what actually left beats keeping the number tidy',
      );
      // Whatever the sign, the status still reads correctly.
      expect(stockStatusOf(after), StockStatus.outOfStock);
    });

    test('an adjustment records both figures and lands on the counted one',
        () async {
      final item = (await items.item(ItemIds.pommesTerre))!;

      final movement = await movements.recordAdjustment(
        storeId: StoreIds.sablon,
        itemId: item.id,
        systemQuantity: item.quantity,
        countedQuantity: 31,
      );

      expect(movement.systemQuantity, item.quantity);
      expect(movement.countedQuantity, 31);
      expect(movement.quantity, 31 - item.quantity);
      expect((await items.item(item.id))!.quantity, 31);
    });

    test('quantity always equals the sum of the log', () async {
      final created = await chicons(quantity: 10);

      // An arbitrary sequence: deliveries, usage, a correction.
      await movements.recordStockIn(
        storeId: StoreIds.sablon,
        itemId: created.id,
        quantity: 6,
      );
      await movements.recordStockOut(
        storeId: StoreIds.sablon,
        itemId: created.id,
        quantity: 2.5,
        reason: StockOutReason.sale,
      );
      await movements.recordAdjustment(
        storeId: StoreIds.sablon,
        itemId: created.id,
        systemQuantity: (await items.item(created.id))!.quantity,
        countedQuantity: 9,
      );
      await movements.recordStockOut(
        storeId: StoreIds.sablon,
        itemId: created.id,
        quantity: 1,
        reason: StockOutReason.spoilage,
      );

      expect((await items.item(created.id))!.quantity, 8);
      expect(await sumOfMovements(created.id), 8);
    });

    test('two stock-outs landing at once both take effect', () async {
      // New in this phase, and the reason the read of the quantity happens
      // inside the transaction rather than around it. Phase 1 edited a list
      // element with nothing able to interleave; these are two genuinely
      // concurrent futures, which is what a double-tapped button produces. A
      // read outside the transaction would let the second one apply to a
      // quantity the first had already changed, and one of the two would
      // silently vanish.
      final created = await chicons(quantity: 20);

      await Future.wait([
        movements.recordStockOut(
          storeId: StoreIds.sablon,
          itemId: created.id,
          quantity: 3,
          reason: StockOutReason.sale,
        ),
        movements.recordStockOut(
          storeId: StoreIds.sablon,
          itemId: created.id,
          quantity: 4,
          reason: StockOutReason.sale,
        ),
      ]);

      expect((await items.item(created.id))!.quantity, 13);
      expect(await sumOfMovements(created.id), 13);
      expect(await movements.movementsForItem(created.id), hasLength(3));
    });

    test('a movement for an article that does not exist is refused', () async {
      // Phase 1 filed it anyway, with no cost figures, because a list cannot
      // refuse. This says so in words rather than as a constraint violation
      // from three frames down.
      await expectLater(
        movements.recordStockIn(
          storeId: StoreIds.sablon,
          itemId: 'item-that-never-was',
          quantity: 5,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('valuation follows the stock', () {
    test('rises by what the delivery cost, not by what stock is worth now',
        () async {
      // This used to assert `before + 10 x the supplier's current price`, which
      // is the bug: it valued the delivery at the price on file rather than at
      // the price paid, and — because the same price was then applied to every
      // unit on hand — silently revalued stock bought weeks earlier too.
      final before = await reports.stockValuation(StoreIds.sablon);

      await movements.recordStockIn(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        quantity: 10,
        supplierId: SupplierIds.grossisteCentral,
        unitPrice: 15.00,
      );

      expect(
        await reports.stockValuation(StoreIds.sablon),
        closeTo(before + 10 * 15.00, 0.01),
      );
    });

    test('a delivery at a new price leaves the old stock alone', () async {
      // The headline case, on a real seeded article. Whatever chicken was
      // already in the fridge keeps the value it had; only the 10 kg that
      // arrived is valued at 15,00.
      final item = await poulet();
      final heldBefore = item.quantity * item.averageCost!;

      await movements.recordStockIn(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        quantity: 10,
        supplierId: SupplierIds.grossisteCentral,
        unitPrice: 15.00,
      );

      final after = await poulet();
      expect(
        after.quantity * after.averageCost!,
        closeTo(heldBefore + 150, 0.01),
      );

      // And the average lands between the two, never at either end.
      expect(after.averageCost, greaterThan(item.averageCost!));
      expect(after.averageCost, lessThan(15.00));
    });

    test('a delivery does not touch what the supplier charges', () async {
      // The two numbers stay separate. A manual stock-in at 15,00 records what
      // was paid; it is not a negotiation, so the price on file is untouched.
      final priceBefore = (await suppliers.defaultPriceForItem(
        ItemIds.poulet,
      ))!.pricePerUnit;

      await movements.recordStockIn(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        quantity: 10,
        supplierId: SupplierIds.grossisteCentral,
        unitPrice: 15.00,
      );

      expect(
        (await suppliers.defaultPriceForItem(ItemIds.poulet))!.pricePerUnit,
        priceBefore,
      );
    });

    test('the category breakdown sums to the total', () async {
      final rows = await reports.valuationByCategory(StoreIds.sablon);
      final sum = rows.fold<double>(0, (total, row) => total + row.totalValue);

      expect(sum, closeTo(await reports.stockValuation(StoreIds.sablon), 0.01));
      expect(
        rows.fold<double>(0, (total, row) => total + row.shareOfTotal),
        closeTo(1, 0.01),
      );
    });

    test('an article with no supplier contributes nothing rather than a guess',
        () async {
      final before = await reports.stockValuation(StoreIds.sablon);

      final created = await chicons(quantity: 50);

      expect(await suppliers.pricesForItem(created.id), isEmpty);
      expect(
        await reports.stockValuation(StoreIds.sablon),
        before,
        reason: '50 kg of unknown cost is not 50 kg of free stock, and it is '
            'not 50 kg at a price nobody has quoted either',
      );
    });

    test('an empty establishment is worth nothing rather than crashing',
        () async {
      expect(await reports.stockValuation(StoreIds.saintGilles), 0);
      expect(await reports.valuationByCategory(StoreIds.saintGilles), isEmpty);
      expect(await reports.valuationByItem(StoreIds.saintGilles), isEmpty);
    });
  });

  group('an article starts with the cost it was bought at', () {
    test('the opening cost becomes the average cost', () async {
      final created = await chicons(quantity: 50, openingUnitCost: 3.20);

      expect(created.averageCost, closeTo(3.20, 0.001));
      expect(created.quantity, 50);
    });

    test('it is set by the opening movement, not written onto the article',
        () async {
      // The single-writer rule reaches cost as well as quantity: the article's
      // first movement is what gives it a cost, so the log explains the number
      // from the article's first day.
      final created = await chicons(quantity: 50, openingUnitCost: 3.20);

      final opening = (await movements.movementsForItem(created.id)).single;
      expect(opening.type, StockMovementType.adjustment);
      expect(opening.unitCost, closeTo(3.20, 0.001));
      expect(opening.averageCostAfter, closeTo(3.20, 0.001));
    });

    test('without one, the cost stays unknown rather than zero', () async {
      final created = await chicons(quantity: 50);

      // Not 0: an unknown cost and a free article are different claims, and
      // only one of them is true.
      expect(created.averageCost, isNull);
    });

    test('the first delivery gives an uncosted article its cost', () async {
      final created = await chicons(quantity: 50);
      final before = await reports.stockValuation(StoreIds.sablon);

      await movements.recordStockIn(
        storeId: StoreIds.sablon,
        itemId: created.id,
        quantity: 20,
        unitPrice: 3.00,
      );

      // 70 kg on hand, all of it now costed at the only price ever paid.
      final after = (await items.item(created.id))!;
      expect(after.averageCost, closeTo(3.00, 0.001));
      expect(
        await reports.stockValuation(StoreIds.sablon),
        closeTo(before + 70 * 3.00, 0.01),
      );
    });
  });

  group('stock leaving never changes what the rest cost', () {
    test('a stock out leaves the average alone', () async {
      final before = (await poulet()).averageCost;

      await movements.recordStockOut(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        quantity: 5,
        reason: StockOutReason.sale,
      );

      expect((await poulet()).averageCost, before);
    });

    test('the movement records what the stock that left had cost', () async {
      final cost = (await poulet()).averageCost!;

      await movements.recordStockOut(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        quantity: 5,
        reason: StockOutReason.waste,
      );

      // Which is what makes a waste line answer "how many euros went in the
      // bin" rather than only "how many kilos".
      final movement = await latestFor(ItemIds.poulet);
      expect(movement.unitCost, closeTo(cost, 0.001));
      expect(
        movement.quantity.abs() * movement.unitCost!,
        closeTo(5 * cost, 0.01),
      );
    });

    test('an adjustment leaves the average alone', () async {
      final item = await poulet();

      await movements.recordAdjustment(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        systemQuantity: item.quantity,
        countedQuantity: item.quantity - 3,
      );

      // A count corrects a quantity. Nobody bought anything, so there is no new
      // price to average in.
      expect((await poulet()).averageCost, item.averageCost);
    });
  });

  group('negative stock resets the cost rather than averaging into it', () {
    test('a delivery onto negative stock adopts the delivery price', () async {
      final item = await poulet();

      // Drive it below zero — allowed on purpose, and a signal that a delivery
      // went unrecorded.
      await movements.recordStockOut(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        quantity: item.quantity + 5,
        reason: StockOutReason.sale,
      );
      expect((await poulet()).quantity, lessThan(0));

      await movements.recordStockIn(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        quantity: 20,
        unitPrice: 15.00,
      );

      // Averaging against a baseline already known to be wrong would carry the
      // error forward instead of ending it — and could produce a negative
      // average, which is not a number anybody can act on.
      final after = await poulet();
      expect(after.averageCost, closeTo(15.00, 0.001));
      expect(after.averageCost, greaterThan(0));
    });
  });

  group('what stock cost on the way out', () {
    test('waste is counted in euros, not only in kilos', () async {
      final cost = (await poulet()).averageCost!;
      final before = await reports.wasteValue(StoreIds.sablon);

      await movements.recordStockOut(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        quantity: 4,
        reason: StockOutReason.waste,
      );

      expect(
        await reports.wasteValue(StoreIds.sablon),
        closeTo(before + 4 * cost, 0.01),
      );
    });

    test('a sale is consumption but not waste', () async {
      final wasteBefore = await reports.wasteValue(StoreIds.sablon);
      final consumedBefore = await reports.consumptionValue(StoreIds.sablon);
      final cost = (await poulet()).averageCost!;

      await movements.recordStockOut(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        quantity: 4,
        reason: StockOutReason.sale,
      );

      expect(await reports.wasteValue(StoreIds.sablon), wasteBefore);
      expect(
        await reports.consumptionValue(StoreIds.sablon),
        closeTo(consumedBefore + 4 * cost, 0.01),
      );
    });

    test('stock found in a count is not a loss', () async {
      final item = await poulet();
      final before = await reports.shrinkageValue(StoreIds.sablon);

      await movements.recordAdjustment(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        systemQuantity: item.quantity,
        countedQuantity: item.quantity + 6,
      );

      // Stock that was there all along and had simply not been recorded.
      expect(await reports.shrinkageValue(StoreIds.sablon), before);

      await movements.recordAdjustment(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        systemQuantity: item.quantity + 6,
        countedQuantity: item.quantity,
      );

      expect(
        await reports.shrinkageValue(StoreIds.sablon),
        closeTo(before + 6 * item.averageCost!, 0.01),
      );
    });
  });

  group('what the movement log says about cost', () {
    test('every movement records the average it produced', () async {
      await movements.recordStockIn(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        quantity: 10,
        unitPrice: 15.00,
      );

      // The audit trail: the number is verifiable rather than one that changes
      // on its own.
      final movement = await latestFor(ItemIds.poulet);
      expect(movement.unitCost, closeTo(15.00, 0.001));
      expect(
        movement.averageCostAfter,
        closeTo((await poulet()).averageCost!, 0.001),
      );
    });

    test('a delivery with no price recorded leaves the average where it was',
        () async {
      final before = (await poulet()).averageCost!;

      await movements.recordStockIn(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        quantity: 10,
      );

      // An unrecorded price is not a price of zero. Treating it as one would
      // drag the average towards nothing and quietly destroy the article's
      // value.
      expect((await poulet()).averageCost, closeTo(before, 0.001));
    });

    test('the recorder stamps the current user when nobody is named', () async {
      final expected = await AccountRepository(db).currentUserName();

      final movement = await movements.recordStockOut(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        quantity: 1,
        reason: StockOutReason.sale,
      );

      expect(movement.userName, expected);
      expect(expected, isNotEmpty);
    });
  });
}
