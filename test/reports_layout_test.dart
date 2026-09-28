// The reports, one row per section — the same rule as the dashboard.
//
// The figures and the three report cards each sit on one line at every
// width: shared equally when they fit, scrolling sideways when they do not.
// The usage report's two trends sit side by side once there is room.

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

// Written out rather than read from AppLocalizations, so the test fails when
// the screen changes rather than following it.
const _reportTitles = [
  'Comparaison des prix',
  'Valorisation du stock',
  'Consommation et pertes',
];

void main() {
  Future<void> open(WidgetTester tester, Size size, String route) async {
    await pumpApp(tester, size: size);
    appRouter.go(Routes.toDashboard(_store));
    await tester.pumpAndSettle();
    appRouter.go(route);
    await tester.pumpAndSettle();
  }

  Set<int> topsOf(WidgetTester tester, Iterable<Finder> finders) => {
    for (final finder in finders) tester.getTopLeft(finder).dy.round(),
  };

  for (final MapEntry(key: name, value: size) in _sizes.entries) {
    testApp('reports on a $name: figures and report cards, one row each', (
      tester,
    ) async {
      await open(tester, size, Routes.toReports(_store));

      expect(tester.takeException(), isNull);

      final tiles = find.byType(SummaryTile);
      expect(tiles, findsNWidgets(3));
      expect(
        topsOf(tester, [for (var i = 0; i < 3; i++) tiles.at(i)]),
        hasLength(1),
        reason: 'the figures wrapped',
      );

      // The titles sit in the report cards; the section header above them
      // shares none of these words.
      expect(
        topsOf(tester, [
          for (final title in _reportTitles) find.text(title).last,
        ]),
        hasLength(1),
        reason: 'the report cards wrapped',
      );
    });

    testApp('usage report on a $name: its figures are one row', (tester) async {
      await open(tester, size, Routes.toUsageReport(_store));

      expect(tester.takeException(), isNull);
      final tiles = find.byType(SummaryTile);
      expect(tiles, findsNWidgets(3));
      expect(
        topsOf(tester, [for (var i = 0; i < 3; i++) tiles.at(i)]),
        hasLength(1),
      );
    });
  }

  testApp('with room, the two usage trends sit side by side', (tester) async {
    await open(
      tester,
      _sizes['landscape tablet']!,
      Routes.toUsageReport(_store),
    );

    expect(
      topsOf(tester, [
        find.text('Consommation quotidienne'),
        find.text('Part de pertes par semaine'),
      ]),
      hasLength(1),
    );
  });
}
