// Paramètres → Compte → Sécurité: the owner changes the restaurant account's
// password there; the PIN is shown masked and never changed here, since it is
// the employee's CIN and the owner corrects it in Personnel.
//
// The sync state is fixed by a stand-in controller, so no timer or server
// runs behind the page.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/app.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/current_employee.dart';
import 'package:stock_inventory/data/device_access.dart';
import 'package:stock_inventory/data/providers.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'support/seed/dataset/dataset.dart' show EmployeeIds, StoreIds;
import 'package:stock_inventory/services/auth_service.dart';
import 'package:stock_inventory/services/sync_service.dart';

import 'support/app_harness.dart';
import 'support/db_fixture.dart';
import 'support/fake_account_backend.dart';

class _IdleSync extends SyncController {
  @override
  SyncState build() => const SyncState(status: SyncStatus.idle);
}

const _pencil = ValueKey('account-change-password');

void main() {
  late FakeAccountBackend server;

  setUp(() async {
    server = FakeAccountBackend();
    final organization = server.addOrganization('Brasserie du Coin');
    server.addUser(
      'owner@resto.be',
      'ancien-mdp',
      organizationId: organization,
    );
    await server.signIn(email: 'owner@resto.be', password: 'ancien-mdp');
  });

  /// The account settings page on an account device, [employeeId] signed in.
  Future<void> pumpSettings(
    WidgetTester tester, {
    String employeeId = EmployeeIds.marc,
    bool account = true,
  }) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final db = await openSeededDatabase();
    if (account) {
      await DeviceAccessRepository(db).writeAccount(
        email: 'owner@resto.be',
        organizationId: 'org-1',
        organizationName: 'Brasserie du Coin',
        role: 'owner',
      );
    }
    seedDeviceAccessSnapshot(await DeviceAccessRepository(db).read());
    addTearDown(() => seedDeviceAccessSnapshot(DeviceAccess.local));
    seedCurrentEmployeeSnapshot(await SessionRepository(db).signIn(employeeId));
    addTearDown(() => seedCurrentEmployeeSnapshot(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          accountBackendProvider.overrideWithValue(server),
          syncControllerProvider.overrideWith(_IdleSync.new),
        ],
        child: const StockInventoryApp(),
      ),
    );
    appRouter.go(Routes.toAccountSettings(StoreIds.sablon));
    await tester.pumpAndSettle();
  }

  Future<void> fill(
    WidgetTester tester, {
    required String current,
    required String next,
    String? confirm,
  }) async {
    Finder field(String key) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(TextField),
    );
    await tester.enterText(field('password-current'), current);
    await tester.enterText(field('password-new'), next);
    await tester.enterText(field('password-confirm'), confirm ?? next);
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
  }

  Future<bool> serverTakes(String password) async {
    try {
      await server.signIn(email: 'owner@resto.be', password: password);
      return true;
    } on AccountException {
      return false;
    }
  }

  testApp('the owner changes the account password', (tester) async {
    await pumpSettings(tester);
    expect(find.text('Mot de passe du compte'), findsOneWidget);

    await tester.tap(find.byKey(_pencil));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('owner@resto.be'),
      ),
      findsOneWidget,
    );

    await fill(tester, current: 'ancien-mdp', next: 'nouveau-mdp');

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Mot de passe du compte modifié.'), findsOneWidget);
    expect(await serverTakes('nouveau-mdp'), isTrue);
    expect(await serverTakes('ancien-mdp'), isFalse);
  });

  testApp('a wrong current password keeps the dialog open', (tester) async {
    await pumpSettings(tester);
    await tester.tap(find.byKey(_pencil));
    await tester.pumpAndSettle();

    await fill(tester, current: 'pas-le-bon', next: 'nouveau-mdp');

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Mot de passe actuel incorrect.'), findsOneWidget);
    expect(await serverTakes('ancien-mdp'), isTrue);
  });

  testApp('a short or mistyped new password is refused before sending', (
    tester,
  ) async {
    await pumpSettings(tester);
    await tester.tap(find.byKey(_pencil));
    await tester.pumpAndSettle();

    await fill(tester, current: 'ancien-mdp', next: 'court');
    expect(find.textContaining('8 caractères minimum'), findsWidgets);

    await fill(
      tester,
      current: 'ancien-mdp',
      next: 'nouveau-mdp',
      confirm: 'nouveau-mdx',
    );
    expect(
      find.text('Les deux nouveaux mots de passe ne sont pas identiques.'),
      findsOneWidget,
    );
    expect(await serverTakes('ancien-mdp'), isTrue);
  });

  testApp('a manager sees the PIN masked and no account password', (
    tester,
  ) async {
    await pumpSettings(tester, employeeId: EmployeeIds.amelie);
    expect(find.byKey(_pencil), findsNothing);
    expect(find.text('Numéro PIN'), findsOneWidget);
    final pin = (await tester.runAsync(
      () => EmployeeRepository(
        ProviderScope.containerOf(
          tester.element(find.byType(StockInventoryApp)),
        ).read(databaseProvider),
      ).employee(EmployeeIds.amelie),
    ))!.pin;
    expect(find.text(pin), findsNothing, reason: 'never shown whole');
  });

  testApp('a device with no account has no account password', (tester) async {
    await pumpSettings(tester, account: false);
    expect(find.byKey(_pencil), findsNothing);
    expect(find.text('Numéro PIN'), findsOneWidget);
  });
}
