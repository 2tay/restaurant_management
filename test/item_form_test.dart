// The product form's two pickers that are not category or unit.
//
// The rules these exist to defend:
//
//   **An edit form opens showing what is on the record**, including the
//   default supplier — a field that reads "Aucun" for a product that has one
//   is not a blank field, it is a wrong answer, and saving it writes the wrong
//   answer back.
//
//   **The default supplier is an edit-only field.** At creation there is no
//   supplier link yet and no price behind it, so the picker would be offering
//   a preference about a relationship that does not exist.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';

import 'support/app_harness.dart';

const Size _tablet = Size(1280, 800);
const String _store = StoreIds.sablon;
const String _supplierLabel = 'Fournisseur par défaut';

void main() {
  /// A seeded product that has a default supplier on file.
  String itemWithSupplier() => mockItems
      .firstWhere(
        (item) => item.storeId == _store && item.defaultSupplierId != null,
      )
      .id;

  /// Opens [route] from a known screen.
  ///
  /// `appRouter` is a module-global that outlives one test, and two form
  /// routes in a row reuse the same live page — so a test arriving straight
  /// from the one before it asserts the previous test's screen.
  Future<void> open(WidgetTester tester, String route) async {
    appRouter.go(Routes.toInventory(_store));
    await tester.pumpAndSettle();
    appRouter.go(route);
    await tester.pumpAndSettle();
  }

  testApp('the edit form opens on the supplier already on the record', (
    tester,
  ) async {
    await pumpApp(tester, size: _tablet);
    final itemId = itemWithSupplier();

    await open(tester, Routes.toEditItem(_store, itemId));

    // The widget's own value, not `find.text`. A dropdown builds every option
    // into an IndexedStack and paints one, so the supplier's name is in the
    // tree whether or not it is the one selected — searching for the text
    // proves only that the menu has the supplier in it.
    final picker = tester.widget<AppDropdown<String>>(
      find.byWidgetPredicate(
        (w) => w is AppDropdown<String> && w.label == _supplierLabel,
      ),
    );

    expect(
      picker.value,
      mockItems.firstWhere((i) => i.id == itemId).defaultSupplierId,
      reason: 'the picker must open on the supplier the product actually has',
    );
  });

  testApp('the create form does not ask for a default supplier', (
    tester,
  ) async {
    await pumpApp(tester, size: _tablet);

    await open(tester, Routes.toAddItem(_store));

    expect(find.text(_supplierLabel), findsNothing);
  });

  testApp('the edit form does ask for one', (tester) async {
    await pumpApp(tester, size: _tablet);

    await open(tester, Routes.toEditItem(_store, itemWithSupplier()));

    expect(find.text(_supplierLabel), findsOneWidget);
  });
}
