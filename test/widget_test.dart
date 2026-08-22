// Stage 0 smoke test. Replaces the `flutter create` counter test, which
// asserted on boilerplate that no longer exists.
//
// This verifies the app boots and that the French l10n pipeline resolves —
// if gen-l10n or the locale wiring breaks, this fails rather than surfacing
// as a blank screen at demo time.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/app.dart';

void main() {
  testWidgets('boots and renders French localized strings', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: StockInventoryApp()));
    await tester.pumpAndSettle();

    expect(find.text('Gestion de Stock'), findsOneWidget);

    final context = tester.element(find.byType(Scaffold));
    expect(Localizations.localeOf(context), const Locale('fr', 'BE'));
  });
}
