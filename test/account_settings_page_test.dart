// Paramètres → Compte: the profile is read-only until its pencil is pressed,
// then saved or put back; the linked establishments are cards.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';

import 'support/app_harness.dart';

const _edit = ValueKey('account-edit-profile');

Finder _field(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is AppTextField && w.label == label),
  matching: find.byType(TextField),
);

void main() {
  testApp('the profile saves the edited first name', (tester) async {
    final db = await pumpApp(tester, size: const Size(1280, 1400));
    appRouter.go(Routes.toAccountSettings(StoreIds.sablon));
    await tester.pumpAndSettle();

    final id = (await SessionRepository(db).currentEmployee())!.id;
    expect(tester.widget<TextField>(_field('Prénom')).readOnly, isTrue);
    expect(find.text('Enregistrer'), findsNothing);

    await tester.tap(find.byKey(_edit));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(_field('Prénom')).readOnly, isFalse);

    await tester.enterText(_field('Prénom'), 'Mathilde');
    await tester.tap(find.text('Enregistrer'));
    final saved = find.text('Profil enregistré');
    for (var i = 0; i < 20 && saved.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(saved, findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Enregistrer'), findsNothing);
    expect(
      (await EmployeeRepository(db).employee(id))!.firstName,
      'Mathilde',
    );
  });

  testApp('Annuler puts the profile back', (tester) async {
    await pumpApp(tester, size: const Size(1280, 1400));
    appRouter.go(Routes.toAccountSettings(StoreIds.sablon));
    await tester.pumpAndSettle();
    final before = tester.widget<TextField>(_field('Prénom')).controller!.text;

    await tester.tap(find.byKey(_edit));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Prénom'), 'Autre');
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(_field('Prénom')).controller!.text,
      before,
    );
    expect(tester.widget<TextField>(_field('Prénom')).readOnly, isTrue);
  });

  testApp('two fields per line, the stores as cards; one per line on a phone', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(1280, 1400));
    appRouter.go(Routes.toAccountSettings(StoreIds.sablon));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(_field('Nom')).dy,
      tester.getTopLeft(_field('Prénom')).dy,
    );
    expect(find.byType(IconInfoCard), findsWidgets);
    expect(find.text('Rôle'), findsOneWidget);

    tester.view.physicalSize = const Size(400, 1800);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(_field('Nom')).dy,
      greaterThan(tester.getTopLeft(_field('Prénom')).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
