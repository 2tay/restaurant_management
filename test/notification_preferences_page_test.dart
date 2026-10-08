// Paramètres → Notifications: one borderless card per notification, two side
// by side on a wide screen, one per line on a small one.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';

import 'support/app_harness.dart';

Finder _card(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(AppCard));

void main() {
  testApp('wide screen: two cards per line, equal heights, no border', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(1440, 900));
    appRouter.go(Routes.toNotificationSettings(StoreIds.sablon));
    await tester.pumpAndSettle();

    final first = tester.getRect(_card('Alertes de stock faible'));
    final second = tester.getRect(_card('Changements de prix'));
    final third = tester.getRect(_card('Ajustements importants'));
    // Side by side, same height.
    expect(second.top, first.top);
    expect(second.left, greaterThan(first.right));
    expect(second.height, first.height);
    // The third starts the next line.
    expect(third.left, first.left);
    expect(third.top, greaterThan(first.bottom));

    for (final card in tester.widgetList<AppCard>(find.byType(AppCard))) {
      expect(card.bordered, isFalse);
    }
    expect(tester.takeException(), isNull);
  });

  testApp('phone: one card per line', (tester) async {
    await pumpApp(tester, size: const Size(360, 780));
    appRouter.go(Routes.toNotificationSettings(StoreIds.sablon));
    await tester.pumpAndSettle();

    final first = tester.getRect(_card('Alertes de stock faible'));
    final second = tester.getRect(_card('Changements de prix'));
    expect(second.left, first.left);
    expect(second.top, greaterThan(first.bottom));
    expect(tester.takeException(), isNull);
  });

  testApp('tapping a card toggles its notification', (tester) async {
    await pumpApp(tester, size: const Size(1440, 900));
    appRouter.go(Routes.toNotificationSettings(StoreIds.sablon));
    await tester.pumpAndSettle();

    Switch toggle() => tester.widget<Switch>(
      find.descendant(
        of: _card('Changements de prix'),
        matching: find.byType(Switch),
      ),
    );
    final before = toggle().value;
    await tester.tap(find.text('Changements de prix'));
    await tester.pumpAndSettle();
    expect(toggle().value, !before);
  });
}
