// Opening the movement log on one product.
//
// The rule this exists to defend:
//
//   **"Voir tout" under a product's movements shows that product's
//   movements.**
//
// The link used to land on the whole store's log with a thirty-day window, so
// somebody who clicked through from a product was shown every other product's
// movements and, if the ones they had just been looking at were older than a
// month, none of the rows they clicked to see.
//
// These read the filter pills rather than counting rows. The list is lazy, so
// what is built is a window onto the result rather than the whole of it, and
// asserting a row count against the seed would be asserting the viewport
// height. Every test also arrives through the dashboard: `appRouter` is a
// module-global that outlives one test, and the shell keeps a section page
// alive while it is the current one, so going straight to the log twice reuses
// the first test's state.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/features/stock_movement/presentation/widgets/movement_row.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';

import 'support/app_harness.dart';

const Size _tablet = Size(1280, 800);
const String _store = StoreIds.sablon;

// The French the pills carry. Written out rather than read back from
// AppLocalizations, so the test fails when the screen changes rather than
// following it.
const String _productPill = 'Produit';
const String _periodPill = 'Période';
const String _thirtyDays = '30 derniers jours';
const String _wholeHistory = "Tout l'historique";

void main() {
  /// The product the seed gives the busiest history.
  String busiestItem() {
    final counts = <String, int>{};
    for (final movement in mockStockMovements) {
      if (movement.storeId != _store) continue;
      counts[movement.itemId] = (counts[movement.itemId] ?? 0) + 1;
    }
    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ranked.first.key;
  }

  String nameOf(String itemId) =>
      mockItems.firstWhere((item) => item.id == itemId).name;

  /// Opens [route] from a known starting screen.
  Future<void> open(WidgetTester tester, String route) async {
    appRouter.go(Routes.toDashboard(_store));
    await tester.pumpAndSettle();
    appRouter.go(route);
    await tester.pumpAndSettle();
  }

  /// The current selection on the pill named [label], or null when that filter
  /// is inactive.
  String? selectionOn(WidgetTester tester, String label) => tester
      .widgetList<FilterPill>(find.byType(FilterPill))
      .firstWhere((pill) => pill.label == label)
      .selectedLabel;

  testApp('the log opens on the product it was reached from', (tester) async {
    await pumpApp(tester, size: _tablet);
    final itemId = busiestItem();

    await open(tester, Routes.toMovements(_store, itemId: itemId));

    // The filter names the product, so the list reads as deliberately narrowed
    // rather than mysteriously short.
    expect(selectionOn(tester, _productPill), nameOf(itemId));

    // And every row built is that product's.
    final rows = tester.widgetList<MovementRow>(find.byType(MovementRow));
    expect(rows, isNotEmpty);
    for (final row in rows) {
      expect(row.view.itemName, nameOf(itemId));
    }
  });

  // The product page lists a product's last movements with no date limit, so
  // the store's thirty-day default would hide exactly the rows the user
  // clicked to see.
  testApp('arriving on a product widens the period to the whole history', (
    tester,
  ) async {
    await pumpApp(tester, size: _tablet);

    await open(tester, Routes.toMovements(_store, itemId: busiestItem()));

    expect(selectionOn(tester, _periodPill), _wholeHistory);
  });

  testApp('the whole store over thirty days is still the default', (
    tester,
  ) async {
    await pumpApp(tester, size: _tablet);

    await open(tester, Routes.toMovements(_store));

    expect(
      selectionOn(tester, _productPill),
      isNull,
      reason: 'no product was asked for, so none should be filtered to',
    );
    expect(selectionOn(tester, _periodPill), _thirtyDays);
  });

  // The shell keeps a section page mounted while it is the current one, so
  // this is the path that has no fresh `initState` to fall back on: the page
  // is already there, and only the route under it changed.
  testApp('the sidebar entry clears a filter inherited from a product', (
    tester,
  ) async {
    await pumpApp(tester, size: _tablet);
    final itemId = busiestItem();

    await open(tester, Routes.toMovements(_store, itemId: itemId));
    expect(selectionOn(tester, _productPill), nameOf(itemId));

    // Straight to the sidebar destination, with no screen in between.
    appRouter.go(Routes.toMovements(_store));
    await tester.pumpAndSettle();

    expect(selectionOn(tester, _productPill), isNull);
    expect(selectionOn(tester, _periodPill), _thirtyDays);
  });

  test('the sidebar destination stays a plain section route', () {
    expect(Routes.toMovements(_store), isNot(contains('?')));
    expect(
      Routes.toMovements(_store, itemId: 'item-poulet'),
      endsWith('/movements?item=item-poulet'),
    );
  });
}
