// The employee form as a three-step wizard (design step 1.2):
// Information professionnelle → Rémunération → Rôle et sécurité. Propriétaire
// is never assignable, and only a role that signs in is asked for a password.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';

import 'support/app_harness.dart';

const _owner = ValueKey('role-option-owner');
const _manager = ValueKey('role-option-manager');
const _staff = ValueKey('role-option-staff');
const _staffNotice = ValueKey('staff-no-password');

Future<AppDatabase> _open(
  WidgetTester tester,
  String path, {
  Size size = const Size(1280, 900),
}) async {
  final db = await pumpApp(tester, size: size, asEmployeeId: EmployeeIds.marc);
  appRouter.go(path);
  await tester.pumpAndSettle();
  return db;
}

Finder _button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
);

bool _enabled(WidgetTester tester, String label) =>
    tester.widget<ButtonStyleButton>(_button(label).first).onPressed != null;

Future<void> _tap(WidgetTester tester, String label) async {
  final button = _button(label).first;
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _fillIdentity(WidgetTester tester) async {
  final fields = find.byType(TextField);
  const values = [
    'Nora',
    'Benali',
    '11.22.33-444.55',
    '+32 470 12 34 56',
    'nora.benali@example.test',
  ];
  for (final (i, value) in values.indexed) {
    await tester.enterText(fields.at(i), value);
  }
  await tester.pumpAndSettle();
}

/// Creates are walked in order: fill step 1, Suivant, fill the rate, Suivant.
Future<void> _walkToRoleStep(WidgetTester tester) async {
  await _fillIdentity(tester);
  await _tap(tester, 'Suivant');
  await tester.enterText(find.byType(TextField).first, '18,5');
  await tester.pumpAndSettle();
  await _tap(tester, 'Suivant');
}

void main() {
  testApp('opens on step 1 with the title, paragraph and back link', (
    tester,
  ) async {
    await _open(tester, Routes.toAddEmployee(StoreIds.sablon));

    expect(tester.takeException(), isNull);
    expect(find.byType(WizardStepIndicator), findsOneWidget);
    // Under the test font the three labels do not fit the 720dp form, so the
    // indicator is in its compact form here (the full row is covered by
    // wizard_test.dart).
    expect(find.textContaining('Information professionnelle'), findsOneWidget);
    expect(find.textContaining('trois étapes'), findsOneWidget);
    expect(find.text("Retour à l'accueil"), findsOneWidget);
    // Step 1 is empty → cannot move on.
    expect(_enabled(tester, 'Suivant'), isFalse);
  });

  testApp('the back link returns to Personnel', (tester) async {
    await _open(tester, Routes.toAddEmployee(StoreIds.sablon));
    await _tap(tester, "Retour à l'accueil");

    expect(
      appRouter.routerDelegate.currentConfiguration.uri.toString(),
      Routes.toEmployees(StoreIds.sablon),
    );
  });

  testApp('walks the three steps; Gérant / Employé only, never Propriétaire',
      (tester) async {
    await _open(tester, Routes.toAddEmployee(StoreIds.sablon));
    await _walkToRoleStep(tester);

    expect(find.byKey(_manager), findsOneWidget);
    expect(find.byKey(_staff), findsOneWidget);
    expect(find.byKey(_owner), findsNothing);
  });

  testApp('an Employé is asked for no password; a Gérant is', (tester) async {
    await _open(tester, Routes.toAddEmployee(StoreIds.sablon));
    await _walkToRoleStep(tester);

    // Default role is Employé: no password fields, a note instead, and the
    // form can be saved as is.
    expect(find.byKey(_staffNotice), findsOneWidget);
    expect(find.text('Mot de passe'), findsNothing);
    expect(_enabled(tester, 'Enregistrer'), isTrue);

    await tester.tap(find.byKey(_manager));
    await tester.pumpAndSettle();
    expect(find.byKey(_staffNotice), findsNothing);
    expect(find.text('Mot de passe'), findsOneWidget);
    // A Gérant needs one before saving.
    expect(_enabled(tester, 'Enregistrer'), isFalse);
  });

  testApp('saving an Employé creates them with no credential', (tester) async {
    final db = await _open(tester, Routes.toAddEmployee(StoreIds.sablon));
    await _walkToRoleStep(tester);
    await _tap(tester, 'Enregistrer');

    final created = await EmployeeRepository(
      db,
    ).employeeByPin('11.22.33-444.55');
    expect(created, isNotNull);
    expect(created!.pay, 18.5);
    expect(await CredentialRepository(db).forEmployee(created.id), isNull);
  });

  testApp('editing can save from any step', (
    tester,
  ) async {
    await _open(
      tester,
      Routes.toEditEmployee(StoreIds.sablon, EmployeeIds.amelie),
    );

    expect(find.textContaining('Amélie Vandenberghe'), findsWidgets);
    expect(_enabled(tester, 'Enregistrer'), isTrue);

    await _tap(tester, 'Suivant');
    await _tap(tester, 'Suivant');
    // Amélie is a Gérant: password fields, blank = keep the current one.
    expect(find.byKey(_manager), findsOneWidget);
    expect(find.byKey(_owner), findsNothing);
    expect(find.text('Mot de passe'), findsOneWidget);
  });

  testApp('editing the owner keeps Propriétaire as the only role', (
    tester,
  ) async {
    await _open(
      tester,
      Routes.toEditEmployee(StoreIds.sablon, EmployeeIds.marc),
    );
    await _tap(tester, 'Suivant');
    await _tap(tester, 'Suivant');

    expect(find.byKey(_owner), findsOneWidget);
    expect(find.byKey(_manager), findsNothing);
    expect(find.byKey(_staff), findsNothing);
  });

  testApp('fits a phone', (tester) async {
    await _open(tester, Routes.toAddEmployee(StoreIds.sablon));
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Étape 1 sur 3 · Information professionnelle'),
        findsOneWidget);
  });
}
