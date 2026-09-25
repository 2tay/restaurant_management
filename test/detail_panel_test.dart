// Details open as a panel over the list, not as a page instead of it.
//
// The rules these exist to defend:
//
//   **A list you are working through survives looking at one of its rows.**
//   Réceptions used to push a page, so coming back meant a navigation you had
//   to undo — once per commande.
//
//   **A réception opened from inside a commande replaces the panel's content
//   and grows a back arrow.** It does not stack a second panel: on a phone a
//   panel is already full width, so the one underneath would be invisible, and
//   two scrims deep gets murky.
//
//   **A réception is never navigated to from inside the app.** It is a detail
//   of something else — a commande you are reading, a movement you are
//   tracing — so it opens as a panel over whatever asked for it. The route
//   survives for deep links only.
//
//   **A panel carries no destructive action.** Supprimer, Annuler and Clôturer
//   stay on the page. A list you are half-way through is the worst place to
//   cancel a commande from.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/features/orders/presentation/widgets/order_detail_view.dart';
import 'package:stock_inventory/features/orders/presentation/widgets/receipt_detail_view.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';

import 'support/app_harness.dart';

const Size _tablet = Size(1280, 800);
const String _store = StoreIds.sablon;

void main() {
  /// Goes to [route] from a known screen.
  ///
  /// `appRouter` outlives one test, so a test arriving straight from the
  /// previous one would assert that test's screen.
  Future<void> open(WidgetTester tester, String route) async {
    await pumpApp(tester, size: _tablet);
    appRouter.go(Routes.toDashboard(_store));
    await tester.pumpAndSettle();
    appRouter.go(route);
    await tester.pumpAndSettle();
  }

  /// Taps the first match, scrolling it into view first — a tap that misses
  /// proves nothing about what a tap does.
  Future<void> tapFirst(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
    await tester.tap(finder.first, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  /// Opens Réceptions and taps its first pending commande.
  Future<void> openPendingPanel(WidgetTester tester) async {
    await open(tester, Routes.toReceptions(_store));
    await tapFirst(tester, find.byType(AppCard));
  }

  testApp('a pending commande opens as a panel over the list', (tester) async {
    await open(tester, Routes.toReceptions(_store));
    expect(find.byType(OrderDetailBody), findsNothing);

    await tapFirst(tester, find.byType(AppCard));

    expect(find.byType(OrderDetailBody), findsOneWidget);
    // The list is still mounted underneath — the panel is over it, not
    // instead of it.
    expect(find.byType(ShellPage), findsWidgets);
  });

  testApp('the panel carries no destructive action', (tester) async {
    await openPendingPanel(tester);

    final panel = find.byType(OrderDetailBody);
    expect(
      find.descendant(of: panel, matching: find.text('Supprimer')),
      findsNothing,
    );
    expect(
      find.descendant(of: panel, matching: find.text('Annuler la commande')),
      findsNothing,
    );
  });

  testApp('closing it lands back on Réceptions', (tester) async {
    await openPendingPanel(tester);

    await tapFirst(
      tester,
      find.descendant(
        of: find.byType(OrderDetailBody),
        matching: find.byTooltip('Fermer'),
      ),
    );

    expect(find.byType(OrderDetailBody), findsNothing);
    // Where we started, and not wherever a back navigation would have gone.
    expect(find.text('Réceptions'), findsWidgets);
  });

  // The first panel has nothing behind it, so it shows a close button and no
  // back arrow. The arrow only appears once the panel has walked forward.
  testApp('the first panel has no back arrow', (tester) async {
    await openPendingPanel(tester);

    expect(
      find.descendant(
        of: find.byType(OrderDetailBody),
        matching: find.byTooltip('Retour'),
      ),
      findsNothing,
    );
  });

  // A réception is a detail *of* the commande: you check what arrived and then
  // go back to the lines. It opens as a panel whether the commande is a page
  // or a panel itself.
  testApp('a réception opens as a panel from the commande page', (
    tester,
  ) async {
    // Chosen from the seeded réceptions rather than from the commandes: a
    // status of "received" is not a promise that this particular commande has
    // a réception on file, and an empty tab would pass the test by accident.
    final receipt = mockGoodsReceipts.firstWhere(
      (receipt) => receipt.storeId == _store,
    );
    await open(tester, Routes.toOrder(_store, receipt.orderId));

    // Scoped to the tab bar: "Réceptions" is also a sidebar destination, and
    // an unscoped finder taps that and navigates clean off the commande.
    await tapFirst(
      tester,
      find.descendant(
        of: find.byType(SectionTabs),
        matching: find.text('Réceptions'),
      ),
    );
    expect(find.byType(ReceiptDetailBody), findsNothing);

    // The receipt card itself, not whichever card comes first — the summary
    // at the top of the commande is an AppCard too.
    await tapFirst(
      tester,
      find.byKey(ValueKey('receipt-${receipt.id}')),
    );

    expect(find.byType(ReceiptDetailBody), findsOneWidget);
    // Still on the commande underneath.
    expect(find.byType(OrderDetailBody), findsOneWidget);
  });
}
