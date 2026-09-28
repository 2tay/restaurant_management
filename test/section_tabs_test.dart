// Section tab bars hold at every width.
//
// The settings tabs become a side list on a wide page and a single scrolling
// bar below that, whose closed tabs shrink to icons when the labels no longer
// fit. The other tab bars (catalogue, alerts, order and supplier detail) share
// the same widget and must never overflow either.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';

import 'support/app_harness.dart';

const String _store = StoreIds.sablon;

const _sizes = {
  'phone': Size(360, 780),
  'tablet portrait': Size(800, 1280),
  'desktop': Size(1440, 900),
  'short landscape': Size(1024, 600),
};

void main() {
  final pages = {
    'Établissement': Routes.toStoreSettings(_store),
    'Compte': Routes.toAccountSettings(_store),
    'Notifications (réglages)': Routes.toNotificationSettings(_store),
    'Synchronisation': Routes.toSyncStatus(_store),
    'Catégories': Routes.toCategories(_store),
    'Unités': Routes.toUnits(_store),
    'Alertes': Routes.toAlerts(_store),
    'Notifications': Routes.toNotifications(_store),
    'Fournisseur': Routes.toSupplier(_store, mockSuppliers.first.id),
  };

  for (final MapEntry(key: sizeName, value: size) in _sizes.entries) {
    for (final textScale in [1.0, 2.0]) {
      for (final MapEntry(key: name, value: route) in pages.entries) {
        testApp('$name at $sizeName, text x$textScale: no overflow', (
          tester,
        ) async {
          tester.platformDispatcher.textScaleFactorTestValue = textScale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await pumpApp(tester, size: size);
          appRouter.go(route);
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byType(SectionTabs), findsWidgets);
        });
      }
    }
  }

  testApp('settings tabs sit beside the page when it is wide', (tester) async {
    await pumpApp(tester, size: const Size(1440, 900));
    appRouter.go(Routes.toSyncStatus(_store));
    await tester.pumpAndSettle();

    // Side list: the one-line descriptions are shown.
    expect(find.text('Connexion et données locales'), findsOneWidget);
    final tabs = tester.getTopLeft(find.byType(SectionTabs));
    final title = tester.getTopLeft(find.text('État de la synchronisation'));
    expect(tabs.dx, lessThan(title.dx));
  });

  testApp('settings tabs are a bar under the title on a phone', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(360, 780));
    appRouter.go(Routes.toSyncStatus(_store));
    await tester.pumpAndSettle();

    expect(find.text('Connexion et données locales'), findsNothing);
    // Only the open tab keeps its label; the others are icons with tooltips.
    expect(find.text('Synchronisation'), findsOneWidget);
    expect(find.text('Compte'), findsNothing);
    expect(find.byTooltip('Compte'), findsOneWidget);
  });
}
