// Paramètres → Notifications: one borderless card per notification, two side
// by side on a wide screen, one per line on a small one. The arrivée and
// départ cards are off by default and the owner's alone.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
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

  Switch switchOf(WidgetTester tester, String title) => tester.widget<Switch>(
    find.descendant(of: _card(title), matching: find.byType(Switch)),
  );

  testApp('the owner switches the arrivée notification on', (tester) async {
    final db = await pumpApp(tester, size: const Size(1440, 900));
    appRouter.go(Routes.toNotificationSettings(StoreIds.sablon));
    await tester.pumpAndSettle();

    expect(switchOf(tester, 'Arrivée des employés').value, isFalse);
    expect(switchOf(tester, 'Départ des employés').value, isFalse);
    expect(
      find.text('Seul le propriétaire peut modifier ce réglage.'),
      findsNothing,
    );

    await tester.ensureVisible(find.text('Arrivée des employés'));
    await tester.tap(find.text('Arrivée des employés'));
    await tester.pumpAndSettle();

    expect(switchOf(tester, 'Arrivée des employés').value, isTrue);
    final settings = await StoreRepository(db).settings(StoreIds.sablon);
    expect(settings.notifyClockIn, isTrue);
    expect(settings.notifyClockOut, isFalse);
  });

  testApp('a manager sees the pointage switches, read-only', (tester) async {
    final db = await pumpApp(
      tester,
      size: const Size(1440, 900),
      asEmployeeId: EmployeeIds.amelie,
    );
    appRouter.go(Routes.toNotificationSettings(StoreIds.sablon));
    await tester.pumpAndSettle();

    expect(switchOf(tester, 'Arrivée des employés').onChanged, isNull);
    expect(switchOf(tester, 'Départ des employés').onChanged, isNull);
    expect(
      find.text('Seul le propriétaire peut modifier ce réglage.'),
      findsNWidgets(2),
    );
    // The other notifications stay theirs to change.
    expect(switchOf(tester, 'Changements de prix').onChanged, isNotNull);

    await tester.ensureVisible(find.text('Arrivée des employés'));
    await tester.tap(find.text('Arrivée des employés'));
    await tester.pumpAndSettle();
    final settings = await StoreRepository(db).settings(StoreIds.sablon);
    expect(settings.notifyClockIn, isFalse);
  });

  testApp('phone: the pointage cards fit', (tester) async {
    await pumpApp(
      tester,
      size: const Size(360, 780),
      asEmployeeId: EmployeeIds.amelie,
    );
    appRouter.go(Routes.toNotificationSettings(StoreIds.sablon));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Départ des employés'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
