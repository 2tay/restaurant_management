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
import 'package:stock_inventory/data/repositories/device_repository.dart';
import 'package:stock_inventory/features/auth/presentation/pages/account_setup_page.dart';
import 'package:stock_inventory/features/auth/presentation/pages/account_waiting_page.dart';
import 'package:stock_inventory/features/auth/presentation/pages/login_page.dart';
import 'package:stock_inventory/features/auth/presentation/pages/welcome_page.dart';
import 'package:stock_inventory/data/repositories/session_repository.dart';
import 'package:stock_inventory/data/repositories/store_repository.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart'
    show EmployeeIds, StoreIds;
import 'package:stock_inventory/services/auth_service.dart';
import 'package:stock_inventory/services/sync_service.dart';

import 'support/app_harness.dart';
import 'support/db_fixture.dart';
import 'support/fake_account_backend.dart';

/// A server that takes its time, like a real one: the first download lands
/// after the waiting screen is up, through its listener.
class _SlowBackend extends FakeAccountBackend {
  static const Duration _delay = Duration(milliseconds: 300);

  @override
  Future<AccountSummary> myAccount() async {
    await Future<void>.delayed(_delay);
    return super.myAccount();
  }

  @override
  Future<List<String>> storeIds() async {
    await Future<void>.delayed(_delay);
    return super.storeIds();
  }

  @override
  Future<PullPage> pullChanges(
    String storeId, {
    required int after,
    int limit = 500,
  }) async {
    await Future<void>.delayed(_delay);
    return super.pullChanges(storeId, after: after, limit: limit);
  }
}

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
          networkChangesProvider.overrideWithValue(const Stream.empty()),
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

  testApp('an account with no data yet waits for the first sync', (
    tester,
  ) async {
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
    expect(
      find.byType(LoginPage),
      findsOneWidget,
      reason: 'an account device does not go back to the welcome screen',
    );
  });

  testApp('signing in without a restaurant leads to set-up, then joining', (
    tester,
  ) async {
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

  testApp('an account device shows the real sync state, and no demo reset', (
    tester,
  ) async {
    final db = await openSeededDatabase();
    final organization = server.addOrganization('Brasserie');
    server.addUser(
      'owner@resto.be',
      'motdepasse',
      organizationId: organization,
    );
    await server.signIn(email: 'owner@resto.be', password: 'motdepasse');
    await server.registerDevice(await DeviceRepository(db).deviceId());
    await DeviceAccessRepository(db).writeAccount(
      email: 'owner@resto.be',
      organizationId: organization,
      organizationName: 'Brasserie',
      role: 'owner',
    );
    await pumpDevice(tester, db);
    seedCurrentEmployeeSnapshot(
      await SessionRepository(db).signIn(EmployeeIds.marc),
    );

    appRouter.go(Routes.toSyncStatus(StoreIds.sablon));
    await tester.pumpAndSettle();

    expect(find.text('Synchroniser maintenant'), findsOneWidget);
    expect(find.text('À jour'), findsOneWidget);
    expect(find.text('Réinitialiser la démonstration'), findsNothing);
  });

  testApp('a slow first download still opens the PIN login', (tester) async {
    final slow = _SlowBackend();
    final organization = slow.addOrganization('Brasserie');
    slow.addUser('owner@resto.be', 'motdepasse', organizationId: organization);

    // Another tablet already put the restaurant on the server.
    await tester.runAsync(() async {
      await slow.signIn(email: 'owner@resto.be', password: 'motdepasse');
      final other = openEmptyDatabase();
      await slow.registerDevice(await DeviceRepository(other).deviceId());
      await StoreRepository(other).createStore(
        name: 'Brasserie',
        addressLine: '',
        postalCode: '',
        city: 'Namur',
        phone: '081',
      );
      await SyncRunner(db: other, backend: slow).run();
      await slow.signOut();
    });

    await pumpDevice(tester, openEmptyDatabase(), backend: slow);
    await tester.enterText(find.byType(TextField).at(0), 'owner@resto.be');
    await tester.enterText(find.byType(TextField).at(1), 'motdepasse');
    await tester.tap(find.text('Se connecter'));
    for (var i = 0; i < 40 && find.byType(LoginPage).evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1)); // the page transition

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(AccountWaitingPage), findsNothing);
  });
}
