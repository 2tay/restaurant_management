// Paramètres → Synchronisation: the state spans the page, the facts are
// cards, and below a medium screen « Synchroniser maintenant » is its icon.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/features/settings/presentation/widgets/account_sync_view.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';

import 'support/app_harness.dart';

void main() {
  testApp('wide: the banner fills the page and keeps its label', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(1280, 1000));
    appRouter.go(Routes.toSyncStatus(StoreIds.sablon));
    await tester.pumpAndSettle();

    expect(find.text('Synchroniser maintenant'), findsOneWidget);
    final banner = tester.getSize(find.byType(SyncStatusBanner));
    final grid = tester.getSize(find.byType(ResponsiveCardGrid));
    expect(banner.width, grid.width);
    // Wider than the old 720dp cap.
    expect(banner.width, greaterThan(720));
    // Two cards side by side.
    final cards = find.byType(IconInfoCard);
    expect(
      tester.getTopLeft(cards.at(1)).dy,
      tester.getTopLeft(cards.at(0)).dy,
    );
  });

  testApp('small: the sync button is only its icon, one card per line', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(400, 1400));
    appRouter.go(Routes.toSyncStatus(StoreIds.sablon));
    await tester.pumpAndSettle();

    expect(find.text('Synchroniser maintenant'), findsNothing);
    final button = find.byKey(const ValueKey('sync-now'));
    expect(button, findsOneWidget);
    expect(
      find.descendant(of: button, matching: find.byType(Icon)),
      findsOneWidget,
    );
    final cards = find.byType(IconInfoCard);
    expect(
      tester.getTopLeft(cards.at(1)).dy,
      greaterThan(tester.getTopLeft(cards.at(0)).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
