// The employee wizard, in a pop-up over Personnel: Information
// professionnelle → Rémunération → Rôle et sécurité. Propriétaire is never
// assignable, and only a role that signs in is asked for a password.

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

Future<AppDatabase> _roster(WidgetTester tester) async {
  final db = await pumpApp(
    tester,
    size: const Size(1440, 900),
    asEmployeeId: EmployeeIds.marc,
  );
  appRouter.go(Routes.toEmployees(StoreIds.sablon));
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

/// Personnel → the person's card → drawer → Modifier.
Future<void> _openEdit(WidgetTester tester, String name) async {
  await _roster(tester);
  await _openEditFromRoster(tester, name);
}

/// The card → drawer → Modifier path, on a roster already pumped. The card,
/// not just the name: the signed-in owner's name is also in the sidebar.
Future<void> _openEditFromRoster(WidgetTester tester, String name) async {
  await tester.tap(find.widgetWithText(AppCard, name));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(DetailDrawer),
      matching: find.widgetWithText(SecondaryButton, 'Modifier'),
    ),
  );
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

/// Creates are walked in order: fill step 1, Suivant, fill the rate, Suivant.
Future<void> _walkToRoleStep(WidgetTester tester) async {
  await _fillIdentity(tester);
  await _tap(tester, 'Suivant');
  await tester.enterText(_fields.first, '18,5');
  await tester.pumpAndSettle();
  await _tap(tester, 'Suivant');
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
    expect(find.textContaining('trois étapes'), findsOneWidget);
    expect(find.textContaining('Information professionnelle'), findsWidgets);
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

  testApp('walks the three steps; Gérant / Employé only, never Propriétaire',
      (tester) async {
    await _openAdd(tester);
    await _walkToRoleStep(tester);

    expect(find.byKey(_manager), findsOneWidget);
    expect(find.byKey(_staff), findsOneWidget);
    expect(find.byKey(_owner), findsNothing);
  });

  testApp('an Employé is asked for no password; a Gérant is', (tester) async {
    await _openAdd(tester);
    await _walkToRoleStep(tester);

    expect(find.byKey(_staffNotice), findsOneWidget);
    expect(find.text('Mot de passe'), findsNothing);
    expect(_enabled(tester, 'Enregistrer'), isTrue);

    await tester.tap(find.byKey(_manager));
    await tester.pumpAndSettle();
    expect(find.byKey(_staffNotice), findsNothing);
    expect(find.text('Mot de passe'), findsOneWidget);
    expect(_enabled(tester, 'Enregistrer'), isFalse);
  });

  testApp('saving an Employé closes the pop-up and adds them, with no '
      'credential', (tester) async {
    final db = await _openAdd(tester);
    await _walkToRoleStep(tester);
    await _tap(tester, 'Enregistrer');

    expect(find.byType(WizardDialog), findsNothing);
    expect(find.text('Nora Benali'), findsOneWidget); // on the roster behind
    final created = await EmployeeRepository(
      db,
    ).employeeByPin('11.22.33-444.55');
    expect(created, isNotNull);
    expect(created!.pay, 18.5);
    expect(await CredentialRepository(db).forEmployee(created.id), isNull);
  });

  testApp('Modifier in the drawer opens the same pop-up, savable at once', (
    tester,
  ) async {
    await _openEdit(tester, 'Amélie Vandenberghe');

    expect(find.byType(DetailDrawer), findsNothing);
    expect(find.byType(WizardDialog), findsOneWidget);
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
    await _openEdit(tester, 'Marc Delvaux');
    await _tap(tester, 'Suivant');
    await _tap(tester, 'Suivant');

    expect(find.byKey(_owner), findsOneWidget);
    expect(find.byKey(_manager), findsNothing);
    expect(find.byKey(_staff), findsNothing);
  });

  testApp('Gérant → Employé: saving removes their password', (tester) async {
    final db = await _roster(tester);
    expect(await CredentialRepository(db).forEmployee(EmployeeIds.amelie),
        isNotNull);
    await _openEditFromRoster(tester, 'Amélie Vandenberghe');
    await _tap(tester, 'Suivant');
    await _tap(tester, 'Suivant');

    await tester.tap(find.byKey(_staff));
    await tester.pumpAndSettle();
    expect(find.byKey(_staffNotice), findsOneWidget);
    await _tap(tester, 'Enregistrer');

    expect(find.byType(WizardDialog), findsNothing);
    expect(await CredentialRepository(db).forEmployee(EmployeeIds.amelie),
        isNull);
  });

  testApp('Employé with no password → Gérant: a password is required', (
    tester,
  ) async {
    final db = await _roster(tester);
    final credentials = CredentialRepository(db);
    await credentials.clear(EmployeeIds.karim);

    await _openEditFromRoster(tester, 'Karim Haddouch');
    await _tap(tester, 'Suivant');
    await _tap(tester, 'Suivant');

    await tester.tap(find.byKey(_manager));
    await tester.pumpAndSettle();
    // No password on file: blank is not "keep the current one".
    expect(_enabled(tester, 'Enregistrer'), isFalse);

    final passwords = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(passwords.at(0), '5678');
    await tester.enterText(passwords.at(1), '5678');
    await tester.pumpAndSettle();
    expect(_enabled(tester, 'Enregistrer'), isTrue);
    await _tap(tester, 'Enregistrer');

    final karim = await EmployeeRepository(db).employee(EmployeeIds.karim);
    final attempt = await credentials.authenticate(karim!.pin, '5678');
    expect(attempt.outcome, LoginOutcome.success);
  });

  testApp('a Gérant saved with a blank password keeps the current one', (
    tester,
  ) async {
    final db = await _roster(tester);
    final credentials = CredentialRepository(db);
    final before = await credentials.forEmployee(EmployeeIds.amelie);

    await _openEditFromRoster(tester, 'Amélie Vandenberghe');
    await _tap(tester, 'Enregistrer');

    final after = await credentials.forEmployee(EmployeeIds.amelie);
    expect(after, isNotNull);
    expect(after!.passwordHash, before!.passwordHash);
  });

  testApp('full screen on a phone', (tester) async {
    await _openAdd(tester);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text('Étape 1 sur 3 · Information professionnelle'),
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
