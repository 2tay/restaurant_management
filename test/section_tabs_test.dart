// Section tab bars hold at every width.
//
// The settings tabs are one bar across the top of the page at every width,
// whose closed tabs shrink to icons when the labels no longer fit. The other tab bars (catalogue, alerts, order and supplier detail) share
// the same widget and must never overflow either.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/core/theme/app_spacing.dart';
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

  testApp('settings tabs: one bar under the title, across the whole page, '
      'even when it is wide', (tester) async {
    await pumpApp(tester, size: const Size(1440, 900));
    appRouter.go(Routes.toSyncStatus(_store));
    await tester.pumpAndSettle();

    // No side list: no one-line descriptions.
    expect(find.text('Connexion et données locales'), findsNothing);
    final bar = tester.getRect(find.byType(SectionTabs));
    final title = tester.getRect(find.text('État de la synchronisation'));
    expect(bar.top, greaterThan(title.bottom));
    expect(bar.left, closeTo(title.left, 1));
    // The page's whole width: from the title's left edge to the page inset.
    final page = tester.getRect(find.byType(ShellPage));
    expect(bar.right, closeTo(page.right - AppSpacing.pagePadding, 1));
    // Four tabs sharing it equally.
    final widths = {
      for (final label in [
        'Établissement',
        'Compte',
        'Notifications',
        'Synchronisation',
      ])
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.descendant(
                      of: find.byType(SectionTabs),
                      matching: find.text(label),
                    ),
                    matching: find.byType(AnimatedContainer),
                  )
                  .first,
            )
            .width
            .round(),
    };
    expect(widths, hasLength(1));
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
