// The stock gauge: what it paints, and in what colour.
//
// The rules these exist to defend:
//
//   **The bar has width.** Two earlier versions drew the fill with a
//   `FractionallySizedBox` inside a `Stack`, which hands its children loose
//   constraints — a fraction of nothing is nothing, so the gauge rendered as
//   an empty track on every screen. It read as a broken colour rule rather
//   than a broken layout, and it survived one round of "fixing" because
//   nothing asserted the fill had a size. Now something does.
//
//   **Red under the minimum, amber up to the maximum, green at or above it.**
//   Against a declared range the question is how full, so the colours key to
//   the range — not to zero, the way `stockStatusOf` does.
//
//   **A full bar says "full", not "how far past full".** A product eight times
//   over its ceiling draws the same bar as one exactly at it, so the overflow
//   is marked separately.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/core/theme/app_colors.dart';
import 'package:stock_inventory/l10n/app_localizations.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';

void main() {
  Future<void> pumpGauge(
    WidgetTester tester, {
    required double quantity,
    double minimum = 8,
    double maximum = 20,
    double width = 200,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: StockGauge(
                quantity: quantity,
                minimum: minimum,
                maximum: maximum,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  LinearProgressIndicator barOf(WidgetTester tester) =>
      tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );

  group('the bar actually paints', () {
    testWidgets('it has width', (tester) async {
      await pumpGauge(tester, quantity: 10);

      final size = tester.getSize(find.byType(LinearProgressIndicator));
      expect(
        size.width,
        greaterThan(0),
        reason: 'a collapsed bar is the bug this whole file exists for',
      );
      expect(size.width, closeTo(200, 1));
    });

    testWidgets('the fill is a real fraction of the maximum', (tester) async {
      await pumpGauge(tester, quantity: 10, maximum: 20);

      expect(barOf(tester).value, closeTo(0.5, 0.001));
    });

    testWidgets('an empty product draws an empty bar', (tester) async {
      await pumpGauge(tester, quantity: 0);

      expect(barOf(tester).value, 0);
    });

    // Negative stock means an unrecorded delivery, not a bar running backwards.
    testWidgets('negative stock draws empty rather than inverted', (
      tester,
    ) async {
      await pumpGauge(tester, quantity: -4);

      expect(barOf(tester).value, 0);
    });
  });

  group('the colour keys to the range', () {
    testWidgets('under the minimum is red', (tester) async {
      await pumpGauge(tester, quantity: 6);

      expect(barOf(tester).color, AppColors.outOfStock.solid);
    });

    testWidgets('between the bounds is amber', (tester) async {
      await pumpGauge(tester, quantity: 12);

      expect(barOf(tester).color, AppColors.lowStock.solid);
    });

    testWidgets('at the maximum is green', (tester) async {
      await pumpGauge(tester, quantity: 20);

      expect(barOf(tester).color, AppColors.inStock.solid);
    });

    // The boundary the wording turns on: at the minimum you are not yet below
    // it, so it is amber rather than red.
    testWidgets('exactly at the minimum is amber, not red', (tester) async {
      await pumpGauge(tester, quantity: 8);

      expect(barOf(tester).color, AppColors.lowStock.solid);
    });
  });

  group('past the maximum', () {
    testWidgets('the bar fills and the overflow is marked', (tester) async {
      // The case from the product screen: 50 kg against a 6 kg ceiling.
      await pumpGauge(tester, quantity: 50, minimum: 2, maximum: 6);

      expect(barOf(tester).value, 1.0);
      expect(barOf(tester).color, AppColors.inStock.solid);
      expect(find.byType(Tooltip), findsOneWidget);
    });

    testWidgets('exactly at the maximum is not an overflow', (tester) async {
      await pumpGauge(tester, quantity: 20, maximum: 20);

      expect(barOf(tester).value, 1.0);
      expect(find.byType(Tooltip), findsNothing);
    });
  });

  // The length must not depend on how big the numbers happen to be: two
  // products in the same state draw the same bar.
  testWidgets('the same proportion draws the same bar at any scale', (
    tester,
  ) async {
    await pumpGauge(tester, quantity: 6, minimum: 8, maximum: 20);
    final small = barOf(tester).value;

    await pumpGauge(tester, quantity: 60, minimum: 80, maximum: 200);

    expect(barOf(tester).value, closeTo(small!, 0.001));
  });

  // A product that predates the required range has nothing to draw against.
  testWidgets('no maximum draws nothing at all', (tester) async {
    await pumpGauge(tester, quantity: 5, minimum: 2, maximum: 0);

    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
