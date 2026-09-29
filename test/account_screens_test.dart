// The account screens and the router's device level (SYNC_PLAN.md, Phase 4).
//
// What opens first depends on what the device is:
//
//   nothing chosen yet          -> the welcome screen
//   an account, no data yet     -> the waiting screen
//   an account with data        -> the employee PIN login
//   the demo                    -> as the app has always been

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/app.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/current_employee.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/device_access.dart';
import 'package:stock_inventory/data/providers.dart';
import 'package:stock_inventory/data/repositories/device_access_repository.dart';
import 'package:stock_inventory/features/auth/presentation/pages/account_setup_page.dart';
import 'package:stock_inventory/features/auth/presentation/pages/account_waiting_page.dart';
import 'package:stock_inventory/features/auth/presentation/pages/login_page.dart';
import 'package:stock_inventory/features/auth/presentation/pages/welcome_page.dart';
import 'package:stock_inventory/services/auth_service.dart';

import 'support/app_harness.dart';
import 'support/db_fixture.dart';
import 'support/fake_account_backend.dart';

void main() {
  late FakeAccountBackend server;

  setUp(() => server = FakeAccountBackend());

  /// Pumps the app on [db], with the device read from it, signed out.
  Future<void> pumpDevice(
    WidgetTester tester,
    AppDatabase db, {
    AccountBackend? backend,
  }) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    seedCurrentEmployeeSnapshot(null);
    seedDeviceAccessSnapshot(await DeviceAccessRepository(db).read());
    addTearDown(() => seedDeviceAccessSnapshot(DeviceAccess.demo));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          accountBackendProvider.overrideWithValue(backend ?? server),
        ],
        child: const StockInventoryApp(),
      ),
    );
    appRouter.go(Routes.login);
    await tester.pumpAndSettle();
  }

  testApp('a fresh install opens on the welcome screen', (tester) async {
    await pumpDevice(tester, openEmptyDatabase());
    expect(find.byType(WelcomePage), findsOneWidget);
    expect(find.text('Essayer la démo'), findsOneWidget);
  });

  testApp('trying the demo lands on the pre-filled PIN login', (tester) async {
    final db = openEmptyDatabase();
    await pumpDevice(tester, db);

    await tester.ensureVisible(find.text('Essayer la démo'));
    await tester.tap(find.text('Essayer la démo'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('78.02.14-153.24'), findsOneWidget);
    expect(deviceAccessSnapshot.mode, DeviceMode.demo);
  });

  testApp('a build with no server offers only the demo', (tester) async {
    await pumpDevice(
      tester,
      openEmptyDatabase(),
      backend: const UnconfiguredAccountBackend(),
    );
    expect(
      find.textContaining('Aucun serveur n\'est configuré'),
      findsOneWidget,
    );
    expect(find.text('Se connecter'), findsNothing);
    expect(find.text('Essayer la démo'), findsOneWidget);
  });

  testApp('an account with no data yet waits for the first sync',
      (tester) async {
    final db = openEmptyDatabase();
    await DeviceAccessRepository(db).writeAccount(
      email: 'manager@resto.be',
      organizationId: 'org-1',
      organizationName: 'Brasserie du Coin',
      role: 'manager',
    );
    await pumpDevice(tester, db);

    expect(find.byType(AccountWaitingPage), findsOneWidget);
    expect(find.textContaining('Brasserie du Coin'), findsOneWidget);

    // Nothing else is reachable.
    appRouter.go(Routes.stores);
    await tester.pumpAndSettle();
    expect(find.byType(AccountWaitingPage), findsOneWidget);
  });

  testApp('an account with data opens on an empty PIN login', (tester) async {
    final db = await openSeededDatabase();
    await DeviceAccessRepository(db).writeAccount(
      email: 'owner@resto.be',
      organizationId: 'org-1',
      organizationName: 'Resto',
      role: 'owner',
    );
    await pumpDevice(tester, db);

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('78.02.14-153.24'), findsNothing, reason: 'no demo PIN');
    expect(find.textContaining('Prototype de démonstration'), findsNothing);

    appRouter.go(Routes.welcome);
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget,
        reason: 'an account device does not go back to the welcome screen');
  });

  testApp('signing in without a restaurant leads to set-up, then joining',
      (tester) async {
    final db = openEmptyDatabase();
    server.addUser('manager@resto.be', 'motdepasse');
    final code = server.codeFor(server.addOrganization('Brasserie'));
    await pumpDevice(tester, db);

    await tester.enterText(find.byType(TextField).at(0), 'manager@resto.be');
    await tester.enterText(find.byType(TextField).at(1), 'motdepasse');
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountSetupPage), findsOneWidget);

    await tester.tap(find.text('Rejoindre'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), code);
    await tester.tap(find.text('Rejoindre le restaurant'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountWaitingPage), findsOneWidget);
    expect(find.textContaining('Brasserie'), findsOneWidget);
  });

  testApp('a wrong password is said in words', (tester) async {
    server.addUser('owner@resto.be', 'motdepasse');
    await pumpDevice(tester, openEmptyDatabase());

    await tester.enterText(find.byType(TextField).at(0), 'owner@resto.be');
    await tester.enterText(find.byType(TextField).at(1), 'mauvais');
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    expect(
      find.text('Adresse e-mail ou mot de passe incorrect.'),
      findsOneWidget,
    );
    expect(find.byType(WelcomePage), findsOneWidget);
  });
}
