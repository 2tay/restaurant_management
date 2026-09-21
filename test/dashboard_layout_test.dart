// The dashboard, one row per section.
//
// The rule this exists to defend:
//
//   **Each section of the tableau de bord is one row, at every width.**
//
// The figures used to sit in a wrapping grid: five in four columns left one
// alone on a second row, and on a phone they stacked one per line — five
// screens of scrolling before the first quick action. `CardRow` makes the
// rule structural; these read the cards' positions to hold it there.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/features/dashboard/presentation/widgets/summary_tile.dart';

import 'support/app_harness.dart';

const String _store = StoreIds.sablon;

const _sizes = {
  'phone': Size(360, 740),
  'large phone': Size(600, 900),
  'portrait tablet': Size(900, 1200),
  'landscape tablet': Size(1280, 800),
};

void main() {
  Future<void> open(WidgetTester tester, Size size) async {
    await pumpApp(tester, size: size);
    appRouter.go(Routes.toInventory(_store));
    await tester.pumpAndSettle();
    appRouter.go(Routes.toDashboard(_store));
    await tester.pumpAndSettle();
  }

  /// Every card of [type] starts at the same height: one row, nothing wrapped.
  void expectOneRow<T extends Widget>(WidgetTester tester, int count) {
    final finder = find.byType(T);
    expect(finder, findsNWidgets(count));
    final tops = {
      for (final element in finder.evaluate())
        tester.getTopLeft(find.byWidget(element.widget)).dy.round(),
    };
    expect(tops, hasLength(1), reason: '$T cards sit on ${tops.length} rows');
  }

  for (final MapEntry(key: name, value: size) in _sizes.entries) {
    testApp('on a $name, the figures and the actions are one row each', (
      tester,
    ) async {
      await open(tester, size);

      expect(tester.takeException(), isNull);
      expectOneRow<SummaryTile>(tester, 5);
      expectOneRow<QuickActionButton>(tester, 4);
    });
  }

  testApp('the four quick actions fit a phone without scrolling', (
    tester,
  ) async {
    await open(tester, _sizes['phone']!);

    for (final element in find.byType(QuickActionButton).evaluate()) {
      final rect = tester.getRect(find.byWidget(element.widget));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(360));
    }
  });

  testApp('on a phone, activity and alerts are two tabs of one panel', (
    tester,
  ) async {
    await open(tester, _sizes['phone']!);

    final alertsTab = find.text('À surveiller');
    await tester.ensureVisible(alertsTab);
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.tap(alertsTab);
    await tester.pumpAndSettle();

    // The alert lines, each with its gauge towards the threshold.
    expect(find.byType(LinearProgressIndicator), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
