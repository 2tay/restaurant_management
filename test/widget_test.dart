// Smoke test. Replaces the `flutter create` counter test, which asserted on
// boilerplate that no longer exists.
//
// This verifies the app boots and that the French l10n pipeline resolves — if
// gen-l10n or the locale wiring breaks, this fails rather than surfacing as a
// blank screen at demo time.
//
// It asserts through AppLocalizations rather than against on-screen text, so it
// keeps working as the home screen changes from stage to stage.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/app.dart';
import 'package:stock_inventory/l10n/app_localizations.dart';

void main() {
  testWidgets('boots and resolves French localizations for fr_BE', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: StockInventoryApp()));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold).first);

    expect(Localizations.localeOf(context), const Locale('fr', 'BE'));
    expect(AppLocalizations.of(context).appTitle, 'Gestion de Stock');
    expect(AppLocalizations.of(context).stockStatusLowStock, 'Stock faible');
  });

  testWidgets('applies the app theme rather than Material defaults', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: StockInventoryApp()));
    await tester.pumpAndSettle();

    final theme = Theme.of(tester.element(find.byType(Scaffold).first));

    // Guards against a regression to stock Material colours — the brief
    // explicitly forbids shipping them.
    expect(theme.colorScheme.primary, const Color(0xFF0F766E));
    expect(theme.useMaterial3, isTrue);
  });
}
