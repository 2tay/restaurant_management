// What a commande pre-fills each line with.
//
// The rule this exists to defend:
//
//   **A commande refills a product to its maximum, not to its alert line.**
//
// Ordering the shortfall below the threshold puts a product back at exactly
// the quantity that made it low in the first place, so the next portion sold
// re-alerts it and it reappears on the next commande. That was the behaviour
// before `Item.maxStock` existed, and it is still the behaviour for a product
// that has not declared one.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/core/utils/stock_status.dart';
import 'package:stock_inventory/models/models.dart';

void main() {
  Item item({
    required double quantity,
    required double threshold,
    double maxStock = 0,
  }) => Item(
    id: 'item-test',
    storeId: 'store-test',
    name: 'Tomates',
    categoryId: 'cat-test',
    unitId: 'unit-kg',
    quantity: quantity,
    lowStockThreshold: threshold,
    maxStock: maxStock,
    updatedAt: DateTime(2026, 9, 2),
  );

  group('with a maximum declared', () {
    test('orders the gap between the shelf and a full one', () {
      expect(topUpQuantity(item(quantity: 4, threshold: 5, maxStock: 15)), 11);
    });

    test('an empty shelf orders a full one', () {
      expect(topUpQuantity(item(quantity: 0, threshold: 5, maxStock: 15)), 15);
    });

    // The point of the whole change: 4 kg on the shelf, alert at 5, full at 15.
    // The old rule ordered 1 and left the product still flagged as low.
    test('it lands the product above its alert line, not on it', () {
      final low = item(quantity: 4, threshold: 5, maxStock: 15);
      final after = low.copyWith(quantity: low.quantity + topUpQuantity(low));

      expect(stockStatusOf(after), StockStatus.inStock);
    });

    test('rounds up to a quantity somebody would actually order', () {
      expect(
        topUpQuantity(item(quantity: 2.4, threshold: 5, maxStock: 15)),
        13,
        reason: '12.6 is not a number anybody writes on a commande',
      );
    });

    test('a full shelf still orders something rather than nothing', () {
      // Putting an article on a commande on purpose means ordering some of it.
      // A line pre-filled with zero is a line the user has to fix by hand.
      expect(topUpQuantity(item(quantity: 15, threshold: 5, maxStock: 15)), 1);
      expect(topUpQuantity(item(quantity: 40, threshold: 5, maxStock: 15)), 1);
    });
  });

  group('with no maximum declared', () {
    // Zero is what every article carried the day the column was added, so this
    // is what an install upgraded in place keeps doing until somebody sets one.
    test('falls back to topping up to the threshold', () {
      expect(topUpQuantity(item(quantity: 4, threshold: 5)), 1);
      expect(topUpQuantity(item(quantity: 0, threshold: 5)), 5);
    });

    test('an article that is not low orders one threshold worth', () {
      expect(topUpQuantity(item(quantity: 20, threshold: 5)), 5);
    });

    test('never zero, even with no threshold either', () {
      expect(topUpQuantity(item(quantity: 0, threshold: 0)), 1);
    });
  });
}
