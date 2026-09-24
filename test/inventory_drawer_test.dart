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
//
//   **Every list that names a product opens the same drawer** — the alerts
//   screen, the movement history, the dashboard and the notification feed, not
//   just the catalogue. They used to push the product's page, which took the
//   user off the list they were working through; the panel closes back onto
//   the row they tapped.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/features/inventory/presentation/widgets/item_card.dart';
import 'package:stock_inventory/features/inventory/presentation/widgets/item_detail_view.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';
import 'package:stock_inventory/features/stock_movement/presentation/widgets/movement_row.dart';

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

  group('the other lists open the same drawer', () {
    /// Goes to [route] and taps its first product row.
    ///
    /// Through the dashboard first: `appRouter` outlives one test, so a test
    /// arriving straight from the previous one can assert its screen. The row
    /// is found by type rather than by product name — the name of any one
    /// article may be scrolled out of view, and a tap that misses proves
    /// nothing about what a tap does.
    Future<void> openAndTapRow(
      WidgetTester tester,
      String route,
      Finder row,
    ) async {
      await pumpApp(tester, size: _tablet);
      appRouter.go(Routes.toDashboard(_store));
      await tester.pumpAndSettle();
      appRouter.go(route);
      await tester.pumpAndSettle();

      await tester.ensureVisible(row.first);
      await tester.pumpAndSettle();
      await tester.tap(row.first, warnIfMissed: false);
      await tester.pumpAndSettle();
    }

    testApp('Alertes opens the product over the list', (tester) async {
      await openAndTapRow(
        tester,
        Routes.toAlerts(_store),
        find.byType(StockGauge),
      );

      expect(find.byType(ItemDetailView), findsOneWidget);
      // Still on Alertes underneath — the panel is over it, not instead of it.
      expect(find.byType(ShellPage), findsWidgets);
    });

    testApp('Mouvements opens the product the row is about', (tester) async {
      // The movement names an article, and the panel answers about the
      // article rather than about the movement.
      await openAndTapRow(
        tester,
        Routes.toMovements(_store),
        find.byType(MovementRow),
      );

      expect(find.byType(ItemDetailView), findsOneWidget);
    });

    testApp('closing returns to the list that opened it', (tester) async {
      await openAndTapRow(
        tester,
        Routes.toAlerts(_store),
        find.byType(StockGauge),
      );

      await tester.tap(
        find.descendant(
          of: find.byType(ItemDetailView),
          matching: find.byTooltip('Fermer'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ItemDetailView), findsNothing);
      // The alerts screen, not whatever a back navigation would have landed on.
      expect(find.text('Alertes de stock'), findsWidgets);
    });
  });
}
