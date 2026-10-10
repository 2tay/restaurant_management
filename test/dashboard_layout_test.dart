// The dashboard's sections, at every width.
//
// The rules this exists to defend:
//
//   **The quick actions are one row, at every width.**
//
//   **The figures never scroll sideways.** One row where the five fit; two
//   per row otherwise, the last one alone across the full width.

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

  /// The figures: all on one line, or two per line with the last alone and
  /// as wide as a full line — and every one inside the screen.
  void expectFiguresGrid(WidgetTester tester, Size size) {
    final rects = [
      for (final element in find.byType(SummaryTile).evaluate())
        tester.getRect(find.byWidget(element.widget)),
    ];
    expect(rects, hasLength(5));
    for (final rect in rects) {
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(size.width));
    }

    final lines = <int, List<Rect>>{};
    for (final rect in rects) {
      lines.putIfAbsent(rect.top.round(), () => []).add(rect);
    }
    if (lines.length == 1) return;

    final ordered = lines.keys.toList()..sort();
    expect(ordered, hasLength(3), reason: 'two, two, then one');
    expect(lines[ordered[0]], hasLength(2));
    expect(lines[ordered[1]], hasLength(2));
    final last = lines[ordered[2]]!.single;
    final full = lines[ordered[0]]!;
    expect(last.left, closeTo(full.first.left, 1));
    expect(last.right, closeTo(full.last.right, 1));
  }

  for (final MapEntry(key: name, value: size) in _sizes.entries) {
    testApp('on a $name, the figures fit and the actions are one row', (
      tester,
    ) async {
      await open(tester, size);

      expect(tester.takeException(), isNull);
      expectFiguresGrid(tester, size);
      expectOneRow<QuickActionButton>(tester, 4);
    });
  }

  testApp('on a phone, the figures are two per row', (tester) async {
    await open(tester, _sizes['phone']!);

    final tops = {
      for (final element in find.byType(SummaryTile).evaluate())
        tester.getTopLeft(find.byWidget(element.widget)).dy.round(),
    };
    expect(tops, hasLength(3));
  });

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
    // The activity first: its table has no « Stock » column.
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('Stock'), findsNothing);

    await tester.tap(alertsTab);
    await tester.pumpAndSettle();

    // The alerts, as their table.
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('Stock'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
