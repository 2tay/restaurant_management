// Paramètres → Établissement: two blocks read-only until their pencil is
// pressed, each saved on its own; the journée de service's auto-open time,
// picked with the time picker and saved with its block.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';

import 'support/app_harness.dart';

const _editGeneral = ValueKey('store-settings-edit-general');
const _editOperations = ValueKey('store-settings-edit-operations');

/// The [TextField] inside the [AppTextField] labelled [label] — by widget,
/// not by text: « Commandes » is also a sidebar entry.
Finder _field(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is AppTextField && w.label == label),
  matching: find.byType(TextField),
);

/// Pumps until the save snackbar shows — the save is several writes in a row.
Future<void> _waitSaved(WidgetTester tester) async {
  final saved = find.text('Paramètres enregistrés');
  for (var i = 0; i < 20 && saved.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(saved, findsOneWidget);
}

void main() {
  testApp('read-only at rest; the pencil offers Annuler and Enregistrer', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(1280, 1400));
    appRouter.go(Routes.toStoreSettings(StoreIds.sablon));
    await tester.pumpAndSettle();

    expect(find.text('Informations générales'), findsOneWidget);
    expect(find.text('Fonctionnement'), findsOneWidget);
    expect(find.text('Enregistrer'), findsNothing);
    expect(find.text('Annuler'), findsNothing);
    expect(
      tester.widget<TextField>(_field("Nom de l'établissement")).readOnly,
      isTrue,
    );

    await tester.tap(find.byKey(_editGeneral));
    await tester.pumpAndSettle();

    // Only the block opened: its pencil is gone, the other's stays.
    expect(find.byKey(_editGeneral), findsNothing);
    expect(find.byKey(_editOperations), findsOneWidget);
    expect(find.text('Enregistrer'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);
    expect(
      tester.widget<TextField>(_field("Nom de l'établissement")).readOnly,
      isFalse,
    );
    expect(tester.widget<TextField>(_field('Pauses')).readOnly, isTrue);
  });

  testApp('Annuler puts the typed name back and writes nothing', (
    tester,
  ) async {
    final db = await pumpApp(tester, size: const Size(1280, 1400));
    appRouter.go(Routes.toStoreSettings(StoreIds.sablon));
    await tester.pumpAndSettle();
    final before = (await StoreRepository(db).store(StoreIds.sablon))!.name;

    await tester.tap(find.byKey(_editGeneral));
    await tester.pumpAndSettle();
    await tester.enterText(_field("Nom de l'établissement"), 'Autre nom');
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(find.text('Autre nom'), findsNothing);
    expect(find.text(before), findsWidgets);
    expect(find.text('Enregistrer'), findsNothing);
    expect((await StoreRepository(db).store(StoreIds.sablon))!.name, before);
  });

  testApp('the general block saves the name', (tester) async {
    final db = await pumpApp(tester, size: const Size(1280, 1400));
    appRouter.go(Routes.toStoreSettings(StoreIds.sablon));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_editGeneral));
    await tester.pumpAndSettle();
    await tester.enterText(_field("Nom de l'établissement"), 'Le Sablon');
    await tester.tap(find.text('Enregistrer'));
    await _waitSaved(tester);
    await tester.pumpAndSettle();

    expect(find.text('Enregistrer'), findsNothing);
    expect(
      (await StoreRepository(db).store(StoreIds.sablon))!.name,
      'Le Sablon',
    );
  });

  testApp('the auto-open time is picked, shown and saved', (tester) async {
    final db = await pumpApp(tester, size: const Size(1280, 1400));
    appRouter.go(Routes.toStoreSettings(StoreIds.sablon));
    await tester.pumpAndSettle();

    final field = find.descendant(
      of: find.byKey(const ValueKey('store-settings-auto-open')),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(field).controller!.text, '05:00');

    // Read-only until the pencil: a tap opens nothing.
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsNothing);

    await tester.tap(find.byKey(_editOperations));
    await tester.pumpAndSettle();
    await tester.ensureVisible(field);
    await tester.tap(field);
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

    expect(tester.widget<TextField>(field).controller!.text, '07:30');

    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await _waitSaved(tester);

    final settings = await StoreRepository(db).settings(StoreIds.sablon);
    expect(settings.businessDayAutoOpenMinutes, 7 * 60 + 30);
  });

  testApp('two fields per line on a wide screen', (tester) async {
    await pumpApp(tester, size: const Size(1280, 1400));
    appRouter.go(Routes.toStoreSettings(StoreIds.sablon));
    await tester.pumpAndSettle();

    final name = tester.getTopLeft(_field("Nom de l'établissement"));
    final address = tester.getTopLeft(_field('Adresse'));
    expect(address.dy, name.dy);
    expect(address.dx, greaterThan(name.dx));

    final postal = tester.getTopLeft(_field('Code postal'));
    final phone = tester.getTopLeft(_field('Téléphone'));
    expect(phone.dy, postal.dy);

    expect(
      tester.getTopLeft(_field('Commandes')).dy,
      tester.getTopLeft(_field('Préférences')).dy,
    );
    expect(
      tester.getTopLeft(_field('Journée de service')).dy,
      tester.getTopLeft(_field('Pauses')).dy,
    );
  });

  testApp('one field per line on a phone, the postal code beside the commune', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(400, 1600));
    appRouter.go(Routes.toStoreSettings(StoreIds.sablon));
    await tester.pumpAndSettle();

    final name = tester.getTopLeft(_field("Nom de l'établissement"));
    final address = tester.getTopLeft(_field('Adresse'));
    expect(address.dy, greaterThan(name.dy));
    expect(address.dx, name.dx);

    final postal = tester.getBottomLeft(_field('Code postal'));
    final city = tester.getBottomLeft(_field('Commune'));
    expect(city.dy, postal.dy);
    expect(city.dx, greaterThan(postal.dx));

    expect(tester.takeException(), isNull);
  });
}
