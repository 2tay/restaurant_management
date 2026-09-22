// List pages scroll as a whole.
//
// The rule this exists to defend:
//
//   **On a list page the title, the buttons and the filters scroll away with
//   the list — nothing above it stays pinned.**
//
// These pages used to keep their header fixed and scroll only the list in the
// space left under it. Each test drags the page by its title: pinned, the
// title stays where it was; scrolling with the page, it moves up.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';

import 'support/app_harness.dart';

// Short, so every page has more content than fits.
const Size _short = Size(1280, 520);
const String _store = StoreIds.sablon;

void main() {
  final pages = {
    'Produits': Routes.toInventory(_store),
    'Mouvements': Routes.toMovements(_store),
    'Commandes': Routes.toOrders(_store),
    'Alertes': Routes.toAlerts(_store),
    'Fournisseurs': Routes.toSuppliers(_store),
    'Notifications': Routes.toNotifications(_store),
    'Fiche produit': Routes.toItem(_store, mockItems.first.id),
  };

  for (final MapEntry(key: name, value: route) in pages.entries) {
    testApp('$name: the title scrolls away with the page', (tester) async {
      await pumpApp(tester, size: _short);
      appRouter.go(Routes.toDashboard(_store));
      await tester.pumpAndSettle();
      appRouter.go(route);
      await tester.pumpAndSettle();

      final title = find
          .text(tester.widget<ShellPage>(find.byType(ShellPage)).title)
          .first;
      final before = tester.getTopLeft(title).dy;

      await tester.drag(title, const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text(tester.widget<ShellPage>(find.byType(ShellPage)).title),
        findsWidgets,
      );
      final after = tester.getTopLeft(title).dy;
      expect(after, lessThan(before), reason: '$name kept its title pinned');
    });
  }
}
