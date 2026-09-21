// A product's detail, as a drawer over the list.
//
// The rules this exists to defend:
//
//   **Opening a product does not shrink the list** — the detail slides in
//   over it, the way the pointage history opens a day.
//
//   **A link inside the drawer opens its page in plain sight** — the drawer
//   closes first. A drawer is a dialog above the shell; a page pushed from
//   inside it without closing it would open underneath, out of view.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/features/inventory/presentation/widgets/item_card.dart';
import 'package:stock_inventory/features/inventory/presentation/widgets/item_detail_view.dart';

import 'support/app_harness.dart';

const Size _tablet = Size(1280, 800);
const Size _phone = Size(360, 740);
const String _store = StoreIds.sablon;

void main() {
  Future<void> open(WidgetTester tester, Size size) async {
    await pumpApp(tester, size: size);
    appRouter.go(Routes.toDashboard(_store));
    await tester.pumpAndSettle();
    appRouter.go(Routes.toInventory(_store));
    await tester.pumpAndSettle();
  }

  Future<void> tapFirstProduct(WidgetTester tester) async {
    await tester.tap(find.byType(ItemCard).first);
    await tester.pumpAndSettle();
  }

  testApp('the detail slides in over the list, which keeps its width', (
    tester,
  ) async {
    await open(tester, _tablet);
    final before = tester.getSize(find.byType(ItemCard).first);

    await tapFirstProduct(tester);

    expect(find.byType(ItemDetailView), findsOneWidget);
    expect(tester.getSize(find.byType(ItemCard).first), before);
    // A drawer on the right, not a pane taking half the page.
    final drawer = tester.getRect(find.byType(ItemDetailView));
    expect(drawer.right, greaterThan(_tablet.width - 40));
    expect(drawer.width, lessThan(_tablet.width / 2));
  });

  testApp('the close button dismisses it', (tester) async {
    await open(tester, _tablet);
    await tapFirstProduct(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(ItemDetailView),
        matching: find.byTooltip('Fermer'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ItemDetailView), findsNothing);
  });

  testApp('"Modifier" closes the drawer and opens the form in view', (
    tester,
  ) async {
    await open(tester, _tablet);
    await tapFirstProduct(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(ItemDetailView),
        matching: find.text('Modifier'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ItemDetailView), findsNothing);
    expect(find.text('Modifier le produit'), findsWidgets);
  });

  testApp('on a phone the drawer takes the whole width', (tester) async {
    await open(tester, _phone);
    await tapFirstProduct(tester);

    expect(tester.takeException(), isNull);
    final drawer = tester.getRect(find.byType(ItemDetailView));
    // The full screen, less the drawer's own padding.
    expect(drawer.width, greaterThan(_phone.width - 80));
  });
}
