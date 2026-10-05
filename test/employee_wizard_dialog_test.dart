// The employee wizard, in a pop-up over Personnel: Informations
// personnelles → Tarif et rôle. Propriétaire is never assignable, and no
// password is asked: a Gérant signs in with their email and PIN.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/models/models.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';

import 'support/app_harness.dart';

const _owner = ValueKey('role-option-owner');
const _manager = ValueKey('role-option-manager');
const _staff = ValueKey('role-option-staff');
const _staffNotice = ValueKey('role-no-access');
const _signInNotice = ValueKey('role-signs-in');

Future<AppDatabase> _roster(WidgetTester tester) async {
  final db = await pumpApp(
    tester,
    size: const Size(1440, 900),
    asEmployeeId: EmployeeIds.marc,
  );
  appRouter.go(Routes.toEmployees(StoreIds.sablon));
  await tester.pumpAndSettle();
  // Personnel opens on the table; the edit path below goes through a card.
  await tester.tap(find.byTooltip('Vue grille'));
  await tester.pumpAndSettle();
  return db;
}

Finder _button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
);

bool _enabled(WidgetTester tester, String label) =>
    tester.widget<ButtonStyleButton>(_button(label).last).onPressed != null;

Future<void> _tap(WidgetTester tester, String label) async {
  final button = _button(label).last;
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

/// Personnel → Ajouter un employé.
Future<AppDatabase> _openAdd(WidgetTester tester) async {
  final db = await _roster(tester);
  await _tap(tester, 'Ajouter un employé');
  return db;
}

/// Personnel → the person's card → ⋮ → Modifier.
Future<void> _openEdit(WidgetTester tester, String name) async {
  await _roster(tester);
  await _openEditFromRoster(tester, name);
}

/// The card's ⋮ → Modifier path, on a roster already pumped.
Future<void> _openEditFromRoster(WidgetTester tester, String name) async {
  await tester.tap(
    find.descendant(
      of: find.widgetWithText(AppCard, name),
      matching: find.byKey(const ValueKey('employee-card-menu')),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Modifier'));
  await tester.pumpAndSettle();
}

Finder get _fields =>
    find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));

Future<void> _fillIdentity(WidgetTester tester) async {
  const values = [
    'Nora',
    'Benali',
    '11.22.33-444.55',
    '+32 470 12 34 56',
    'nora.benali@example.test',
  ];
  for (final (i, value) in values.indexed) {
    await tester.enterText(_fields.at(i), value);
  }
  await tester.pumpAndSettle();
}

/// Creates are walked in order: fill step 1, Suivant, fill the rate.
Future<void> _walkToRateAndRole(WidgetTester tester) async {
  await _fillIdentity(tester);
  await _tap(tester, 'Suivant');
  await tester.enterText(_fields.first, '18,5');
  await tester.pumpAndSettle();
}

void main() {
  testApp('Ajouter un employé opens the wizard in a pop-up over Personnel', (
    tester,
  ) async {
    await _openAdd(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(WizardDialog), findsOneWidget);
    expect(
      appRouter.routerDelegate.currentConfiguration.uri.toString(),
      Routes.toEmployees(StoreIds.sablon),
    );
    expect(find.textContaining('deux étapes'), findsOneWidget);
    expect(find.textContaining('Informations personnelles'), findsWidgets);
    // Step 1 is empty → cannot move on.
    expect(_enabled(tester, 'Suivant'), isFalse);
  });

  testApp('step 1: no card behind the fields; the photo picker comes last', (
    tester,
  ) async {
    await _openAdd(tester);

    final page = find.byKey(const ValueKey('wizard-page-0'));
    expect(
      find.descendant(of: page, matching: find.byType(AppCard)),
      findsNothing,
    );
    final emailY = tester.getTopLeft(_fields.last).dy;
    final picker = find.byKey(const ValueKey('employee-photo-picker'));
    expect(picker, findsOneWidget);
    expect(find.text('Choisir une photo'), findsNothing);
    expect(tester.getTopLeft(picker).dy, greaterThan(emailY));
  });

  testApp('two steps: the rate and the role together; Gérant / Employé '
      'only, never Propriétaire', (tester) async {
    await _openAdd(tester);
    await _walkToRateAndRole(tester);

    expect(find.textContaining('Tarif et rôle'), findsWidgets);
    expect(find.byKey(_manager), findsOneWidget);
    expect(find.byKey(_staff), findsOneWidget);
    expect(find.byKey(_owner), findsNothing);
    // The last step: no Suivant, Enregistrer instead.
    expect(_button('Suivant'), findsNothing);
    expect(_enabled(tester, 'Enregistrer'), isTrue);
  });

  testApp('a negative or non-numeric rate says why and blocks Enregistrer', (
    tester,
  ) async {
    await _openAdd(tester);
    await _fillIdentity(tester);
    await _tap(tester, 'Suivant');

    const error = 'Saisissez un taux horaire positif.';
    for (final typed in ['-12', 'abc', 'Infinity']) {
      await tester.enterText(_fields.first, typed);
      await tester.pumpAndSettle();
      expect(find.text(error), findsOneWidget, reason: typed);
      expect(_enabled(tester, 'Enregistrer'), isFalse, reason: typed);
    }

    for (final typed in ['18,5', '50000']) {
      await tester.enterText(_fields.first, typed);
      await tester.pumpAndSettle();
      expect(find.text(error), findsNothing, reason: typed);
      expect(_enabled(tester, 'Enregistrer'), isTrue, reason: typed);
    }
  });

  testApp('no password: the notice says how each role reaches the app', (
    tester,
  ) async {
    await _openAdd(tester);
    await _walkToRateAndRole(tester);

    expect(find.byKey(_staffNotice), findsOneWidget);
    expect(find.textContaining('Mot de passe'), findsNothing);

    await tester.tap(find.byKey(_manager));
    await tester.pumpAndSettle();
    expect(find.byKey(_staffNotice), findsNothing);
    expect(find.byKey(_signInNotice), findsOneWidget);
    expect(find.textContaining('adresse e-mail et son numéro PIN'), findsOneWidget);
    expect(find.textContaining('Mot de passe'), findsNothing);
    expect(_enabled(tester, 'Enregistrer'), isTrue);
  });

  testApp('saving closes the pop-up and adds them', (tester) async {
    final db = await _openAdd(tester);
    await _walkToRateAndRole(tester);
    await tester.tap(find.byKey(_manager));
    await tester.pumpAndSettle();
    await _tap(tester, 'Enregistrer');

    expect(find.byType(WizardDialog), findsNothing);
    expect(find.text('Nora Benali'), findsOneWidget); // on the roster behind
    final created = await EmployeeRepository(
      db,
    ).employeeByPin('11.22.33-444.55');
    expect(created, isNotNull);
    expect(created!.pay, 18.5);
    expect(created.role, EmployeeRole.manager);
    // The new Gérant signs in at once, with their email and PIN.
    expect(
      (await CredentialRepository(
        db,
      ).authenticate('nora.benali@example.test', '11.22.33-444.55')).outcome,
      LoginOutcome.success,
    );
  });

  testApp('Modifier in the card menu opens the same pop-up, savable at once', (
    tester,
  ) async {
    await _openEdit(tester, 'Amélie Vandenberghe');

    expect(find.byType(WizardDialog), findsOneWidget);
    expect(_enabled(tester, 'Enregistrer'), isTrue);

    await _tap(tester, 'Suivant');
    expect(find.byKey(_manager), findsOneWidget);
    expect(find.byKey(_owner), findsNothing);
    expect(find.byKey(_signInNotice), findsOneWidget);
  });

  testApp('Gérant → Employé: the role is saved', (tester) async {
    final db = await _roster(tester);
    await _openEditFromRoster(tester, 'Amélie Vandenberghe');
    await _tap(tester, 'Suivant');

    await tester.tap(find.byKey(_staff));
    await tester.pumpAndSettle();
    expect(find.byKey(_staffNotice), findsOneWidget);
    await _tap(tester, 'Enregistrer');

    expect(find.byType(WizardDialog), findsNothing);
    expect(
      (await EmployeeRepository(db).employee(EmployeeIds.amelie))!.role,
      EmployeeRole.staff,
    );
  });

  testApp('full screen on a phone', (tester) async {
    await _openAdd(tester);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text('Étape 1 sur 2 · Informations personnelles'),
      findsOneWidget,
    );
    // One field per line: Prénom above Nom, not beside it.
    final first = tester.getRect(_fields.at(0));
    final last = tester.getRect(_fields.at(1));
    expect(last.top, greaterThan(first.bottom));
    expect(last.left, first.left);
  });

  testApp('Réinitialiser empties the fields and returns to step 1', (
    tester,
  ) async {
    await _openAdd(tester);
    await _fillIdentity(tester);
    await _tap(tester, 'Suivant');

    await _tap(tester, 'Réinitialiser');
    await tester.tap(find.text('Réinitialiser').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('wizard-page-0')), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      expect(
        tester.widget<TextField>(_fields.at(i)).controller!.text,
        isEmpty,
      );
    }
  });
}
