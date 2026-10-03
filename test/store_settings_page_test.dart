// Paramètres → Établissement: the journée de service's auto-open time, picked
// with the time picker and saved with the rest of the store settings.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';

import 'support/app_harness.dart';

void main() {
  testApp('the auto-open time is picked, shown and saved', (tester) async {
    final db = await pumpApp(tester, size: const Size(1280, 1400));
    appRouter.go(Routes.toStoreSettings(StoreIds.sablon));
    await tester.pumpAndSettle();

    final button = find.byKey(const ValueKey('store-settings-auto-open'));
    await tester.ensureVisible(button);
    expect(
      find.descendant(
        of: button,
        matching: find.text('Ouverture automatique à partir de 05:00'),
      ),
      findsOneWidget,
    );

    await tester.tap(button);
    await tester.pumpAndSettle();
    // Type the time rather than drag the dial.
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(TimePickerDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), '07');
    await tester.enterText(fields.at(1), '30');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(
      find.text('Ouverture automatique à partir de 07:30'),
      findsOneWidget,
    );

    // The header scrolls with the page: bring the button back first.
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    // The save is three writes in a row; its snackbar is the sign it is done.
    final saved = find.text('Paramètres enregistrés');
    for (var i = 0; i < 20 && saved.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(saved, findsOneWidget);

    final settings = await StoreRepository(db).settings(StoreIds.sablon);
    expect(settings.businessDayAutoOpenMinutes, 7 * 60 + 30);
  });
}
