// The cost arithmetic, on its own.
//
// The rule these exist to defend:
//
//   **A delivery revalues only the units it delivered.**
//
// Stock bought last week at 8 € stays worth 8 € when this morning's van
// arrives at 10 €. Getting that wrong is not a rounding error — it invents
// money that was never spent, on the one screen an owner reads to find out how
// much their stock is worth.
//
// These are pure functions, so nothing here writes to the mock lists. The same
// scenarios are run end to end through the mutation layer in
// `inventory_test.dart` and `orders_test.dart`.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/core/utils/stock_cost.dart';

void main() {
  group('a delivery remixes the average', () {
    test('the bug: old stock keeps the price it was bought at', () {
      // 100 kg at 8.00 plus 50 kg at 10.00 cost 1 300 in total, so a kilo cost
      // 8.6667 on average. Valuing all 150 kg at this morning's 10.00 would
      // report 1 500 and invent 200 that nobody ever spent.
      final cost = costAfterStockIn(
        oldQuantity: 100,
        oldAverageCost: 8.00,
        inQuantity: 50,
        inUnitPrice: 10.00,
      );

      expect(cost, closeTo(8.6667, 0.0001));
      expect(valueOf(150, cost), closeTo(1300, 0.01));
    });

    test('a cheaper delivery pulls the average down, not all the way', () {
      final cost = costAfterStockIn(
        oldQuantity: 100,
        oldAverageCost: 10.00,
        inQuantity: 100,
        inUnitPrice: 8.00,
      );

      expect(cost, closeTo(9.00, 0.0001));
      expect(valueOf(200, cost), closeTo(1800, 0.01));
    });

    test('the same price twice leaves the average alone', () {
      final cost = costAfterStockIn(
        oldQuantity: 40,
        oldAverageCost: 5.50,
        inQuantity: 60,
        inUnitPrice: 5.50,
      );

      expect(cost, closeTo(5.50, 0.0001));
    });

    test('deliveries compound in sequence', () {
      var cost = costAfterStockIn(
        oldQuantity: 0,
        oldAverageCost: null,
        inQuantity: 100,
        inUnitPrice: 8.00,
      );
      cost = costAfterStockIn(
        oldQuantity: 100,
        oldAverageCost: cost,
        inQuantity: 50,
        inUnitPrice: 10.00,
      );
      cost = costAfterStockIn(
        oldQuantity: 150,
        oldAverageCost: cost,
        inQuantity: 50,
        inUnitPrice: 12.00,
      );

      // 800 + 500 + 600 = 1 900 spent on 200 kg.
      expect(cost, closeTo(9.50, 0.0001));
      expect(valueOf(200, cost), closeTo(1900, 0.01));
    });
  });

  group('a delivery onto nothing adopts its own price', () {
    test('an empty item takes the delivery price', () {
      final cost = costAfterStockIn(
        oldQuantity: 0,
        oldAverageCost: null,
        inQuantity: 50,
        inUnitPrice: 10.00,
      );

      expect(cost, closeTo(10.00, 0.0001));
    });

    test('an item emptied down to zero starts fresh', () {
      // The last known cost is deliberately not averaged in: there is no stock
      // left for it to describe.
      final cost = costAfterStockIn(
        oldQuantity: 0,
        oldAverageCost: 8.00,
        inQuantity: 50,
        inUnitPrice: 10.00,
      );

      expect(cost, closeTo(10.00, 0.0001));
    });

    test('a known quantity with an unknown cost takes the delivery price', () {
      final cost = costAfterStockIn(
        oldQuantity: 30,
        oldAverageCost: null,
        inQuantity: 50,
        inUnitPrice: 10.00,
      );

      expect(cost, closeTo(10.00, 0.0001));
    });
  });

  group('negative stock resets rather than averages', () {
    test('a delivery onto negative stock adopts the delivery price', () {
      // Negative stock means an earlier delivery was never recorded. Averaging
      // against a baseline already known to be wrong would carry the error
      // forward instead of ending it.
      final cost = costAfterStockIn(
        oldQuantity: -5,
        oldAverageCost: 8.00,
        inQuantity: 20,
        inUnitPrice: 10.00,
      );

      expect(cost, closeTo(10.00, 0.0001));
    });

    test('a delivery that does not clear the hole still resets', () {
      final cost = costAfterStockIn(
        oldQuantity: -30,
        oldAverageCost: 8.00,
        inQuantity: 10,
        inUnitPrice: 10.00,
      );

      // Never a negative average, whatever the arithmetic would have said.
      expect(cost, closeTo(10.00, 0.0001));
      expect(cost, greaterThan(0));
    });
  });

  group('stock leaving never moves the cost', () {
    test('a stock out leaves the average untouched', () {
      expect(costAfterStockOut(8.6667), closeTo(8.6667, 0.0001));
    });

    test('the value that left is quantity times the average', () {
      // 20 kg out of 150 at 8.6667: 130 kg left, worth 1 126.67, and 173.33
      // went with the stock.
      expect(valueOf(130, 8.6667), closeTo(1126.67, 0.01));
      expect(valueOf(20, 8.6667), closeTo(173.33, 0.01));
    });

    test('an unknown cost stays unknown', () {
      expect(costAfterStockOut(null), isNull);
    });
  });

  group('an adjustment never moves the cost', () {
    test('counting less leaves the average untouched', () {
      expect(costAfterAdjustment(8.6667), closeTo(8.6667, 0.0001));
    });

    test('the shrinkage is valued at the average', () {
      // Thought 150, counted 140: 10 kg missing at 8.6667 is 86.67 gone.
      expect(valueOf(10, 8.6667), closeTo(86.67, 0.01));
    });

    test('an adjustment may set a cost that is not yet known', () {
      // The opening balance: an item's first stock, with nothing to preserve.
      expect(
        costAfterAdjustmentWithOpening(oldAverageCost: null, unitCost: 8.00),
        closeTo(8.00, 0.0001),
      );
    });

    test('an adjustment may never change a cost that is known', () {
      expect(
        costAfterAdjustmentWithOpening(oldAverageCost: 8.00, unitCost: 99.00),
        closeTo(8.00, 0.0001),
      );
    });

    test('an adjustment with no cost to offer leaves it unknown', () {
      expect(
        costAfterAdjustmentWithOpening(oldAverageCost: null, unitCost: null),
        isNull,
      );
    });
  });

  group('valuing stock', () {
    test('an unknown cost contributes nothing rather than a guess', () {
      expect(valueOf(150, null), 0);
    });

    test('nothing on hand is worth nothing', () {
      expect(valueOf(0, 8.6667), 0);
    });

    test('negative stock values negative, so the discrepancy stays visible',
        () {
      expect(valueOf(-5, 8.00), closeTo(-40, 0.01));
    });
  });

  group('comparing costs', () {
    test('a difference under a tenth of a cent is the same cost', () {
      expect(sameCost(8.6667, 8.66675), isTrue);
    });

    test('a real difference is a real difference', () {
      expect(sameCost(8.00, 8.01), isFalse);
    });

    test('unknown equals unknown, and never equals a number', () {
      expect(sameCost(null, null), isTrue);
      expect(sameCost(null, 8.00), isFalse);
    });
  });
}
