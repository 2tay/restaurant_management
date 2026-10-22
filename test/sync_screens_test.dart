// What the screens say about sync (SYNC_PLAN.md, Phase 10): the sync page
// in each state, the offline banner, and the list of things to check.
//
// The sync state is fixed by a stand-in controller, so each test shows one
// state without timers or a server.

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
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/features/settings/presentation/widgets/account_sync_view.dart';
import 'support/seed/dataset/dataset.dart'
    show EmployeeIds, StoreIds;
import 'package:stock_inventory/services/sync_service.dart';
import 'package:stock_inventory/shared/widgets/session_expired_banner.dart';

import 'support/app_harness.dart';
import 'support/db_fixture.dart';
import 'support/fake_account_backend.dart';

class _FixedSync extends SyncController {
  _FixedSync(this.fixed);

  final SyncState fixed;

  @override
  SyncState build() => fixed;
}

void main() {
  /// An account device with data, the owner signed in, the sync state fixed.
  Future<AppDatabase> pumpAccount(
    WidgetTester tester,
    SyncState state, {
    FakeAccountBackend? backend,
  }) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final db = await openSeededDatabase();
    await DeviceAccessRepository(db).writeAccount(
      email: 'owner@resto.be',
      organizationId: 'org-1',
      organizationName: 'Brasserie du Coin',
      role: 'owner',
    );
    seedDeviceAccessSnapshot(await DeviceAccessRepository(db).read());
    addTearDown(() => seedDeviceAccessSnapshot(DeviceAccess.local));
    seedCurrentEmployeeSnapshot(
      await SessionRepository(db).signIn(EmployeeIds.marc),
    );
    addTearDown(() => seedCurrentEmployeeSnapshot(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          accountBackendProvider.overrideWithValue(
            backend ?? FakeAccountBackend(),
          ),
          syncControllerProvider.overrideWith(() => _FixedSync(state)),
        ],
        child: const StockInventoryApp(),
      ),
    );
    appRouter.go(Routes.toSyncStatus(StoreIds.sablon));
    await tester.pumpAndSettle();
    return db;
  }

  testApp('up to date: the state, the account and this device', (tester) async {
    await pumpAccount(
      tester,
      SyncState(status: SyncStatus.idle, lastSyncAt: DateTime(2026, 9, 30, 14)),
    );

    expect(find.text('À jour'), findsOneWidget);
    expect(find.text('Synchroniser maintenant'), findsOneWidget);
    expect(find.text('Brasserie du Coin'), findsOneWidget);
    expect(find.text('owner@resto.be'), findsOneWidget);
    expect(find.text('Cet appareil'), findsOneWidget);
    expect(find.text('Photos en attente d\'envoi'), findsOneWidget);
    expect(find.text('Jamais'), findsNothing);
    expect(find.text('Serveur injoignable'), findsNothing);
  });

  testApp('offline: the page explains, and the banner shows everywhere', (
    tester,
  ) async {
    await pumpAccount(tester, const SyncState(status: SyncStatus.offline));

    expect(find.textContaining('Hors ligne'), findsOneWidget);
    expect(find.textContaining('Le serveur est injoignable'), findsOneWidget);

    appRouter.go(Routes.toDashboard(StoreIds.sablon));
    await tester.pumpAndSettle();
    expect(find.text('Serveur injoignable'), findsOneWidget);
  });

  testApp('a removed device says so', (tester) async {
    await pumpAccount(
      tester,
      const SyncState(
        status: SyncStatus.error,
        problem: SyncOutcome.deviceRemoved,
      ),
    );
    expect(find.text('Synchronisation arrêtée'), findsOneWidget);
    expect(find.textContaining('retiré cet appareil'), findsOneWidget);
    expect(find.text('Se reconnecter'), findsNothing);
  });

  testApp('an expired session offers to sign in again', (tester) async {
    await pumpAccount(
      tester,
      const SyncState(
        status: SyncStatus.error,
        problem: SyncOutcome.sessionExpired,
      ),
    );
    expect(find.textContaining('session du compte a expiré'), findsOneWidget);
    // On the page, and in the red bar every screen shows meanwhile.
    expect(find.text('Se reconnecter'), findsNWidgets(2));
  });

  testApp('signing in again closes the dialog without an error', (
    tester,
  ) async {
    await pumpAccount(
      tester,
      const SyncState(
        status: SyncStatus.error,
        problem: SyncOutcome.sessionExpired,
      ),
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AccountSyncView),
        matching: find.text('Se reconnecter'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reconnecter le compte'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(EditableText),
      ),
      'secret',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Se reconnecter'),
      ),
    );
    // The closing animation still shows the password field: its controller
    // must outlive it.
    await tester.pumpAndSettle();
    expect(find.text('Reconnecter le compte'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  /// Types [password] in the reconnect dialog opened from the red bar.
  Future<void> reconnectFromBar(WidgetTester tester, String password) async {
    await tester.tap(
      find.descendant(
        of: find.byType(SessionExpiredBanner),
        matching: find.text('Se reconnecter'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(EditableText),
      ),
      password,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Se reconnecter'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testApp('an expired session shows a red bar on every screen', (tester) async {
    await pumpAccount(
      tester,
      const SyncState(
        status: SyncStatus.error,
        problem: SyncOutcome.sessionExpired,
      ),
    );
    appRouter.go(Routes.toDashboard(StoreIds.sablon));
    await tester.pumpAndSettle();

    expect(
      find.text('Les modifications ne sont plus envoyées'),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(SessionExpiredBanner),
        matching: find.text('Se reconnecter'),
      ),
      findsOneWidget,
    );
    // Not the steel offline bar: this one is an error.
    expect(find.text('Serveur injoignable'), findsNothing);
  });

  testApp('no red bar while the session is fine', (tester) async {
    await pumpAccount(tester, const SyncState(status: SyncStatus.offline));
    appRouter.go(Routes.toDashboard(StoreIds.sablon));
    await tester.pumpAndSettle();
    expect(find.text('Les modifications ne sont plus envoyées'), findsNothing);
  });

  testApp("reconnecting with the same restaurant's account keeps it", (
    tester,
  ) async {
    final backend = FakeAccountBackend()
      ..addUser('owner@resto.be', 'secret', organizationId: 'org-1');
    await pumpAccount(
      tester,
      const SyncState(
        status: SyncStatus.error,
        problem: SyncOutcome.sessionExpired,
      ),
      backend: backend,
    );
    await reconnectFromBar(tester, 'secret');

    expect(backend.currentUser?.email, 'owner@resto.be');
    expect(find.textContaining("n'est pas celui du restaurant"), findsNothing);
  });

  testApp("reconnecting with another restaurant's account is refused", (
    tester,
  ) async {
    final backend = FakeAccountBackend()
      ..addUser('owner@resto.be', 'secret', organizationId: 'org-2');
    await pumpAccount(
      tester,
      const SyncState(
        status: SyncStatus.error,
        problem: SyncOutcome.sessionExpired,
      ),
      backend: backend,
    );
    await reconnectFromBar(tester, 'secret');

    expect(
      find.text("Ce compte n'est pas celui du restaurant de cet appareil."),
      findsOneWidget,
    );
    expect(backend.currentUser, isNull);
  });

  testApp('things to check are listed in words, and can be dismissed', (
    tester,
  ) async {
    final db = await pumpAccount(
      tester,
      const SyncState(status: SyncStatus.idle),
    );
    await db
        .into(db.syncErrors)
        .insert(
          SyncErrorsCompanion.insert(
            changedTable: 'categories',
            rowKey: 'c1',
            storeId: StoreIds.sablon,
            payload: '{}',
            reason: 'deleted',
            rejectedAt: DateTime.utc(2026, 9, 30, 10),
          ),
        );
    await db
        .into(db.syncErrors)
        .insert(
          SyncErrorsCompanion.insert(
            changedTable: 'attendances',
            rowKey: 'a1',
            storeId: StoreIds.sablon,
            payload:
                '{"employee": "Karim B", "date": "2026-10-12T00:00:00.000"}',
            reason: 'resolved_double_clock_in',
            rejectedAt: DateTime.utc(2026, 9, 30, 11),
          ),
        );
    await tester.pumpAndSettle();

    expect(find.text('À vérifier'), findsOneWidget);
    expect(find.textContaining('Supprimé entre-temps'), findsOneWidget);
    expect(find.textContaining('Deux pointages de Karim B'), findsOneWidget);

    await tester.ensureVisible(find.text('Compris').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compris').first);
    // The dismissal is a database write: give it real time to land.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Compris'), findsOneWidget);
  });

  testApp('a device with no account says nothing is sent', (tester) async {
    await pumpApp(tester, size: const Size(1280, 800));
    appRouter.go(Routes.toSyncStatus(StoreIds.sablon));
    await tester.pumpAndSettle();
    expect(
      find.textContaining("Cet appareil n'est relié à aucun compte"),
      findsOneWidget,
    );
    expect(find.textContaining('démonstration'), findsNothing);
    expect(find.text('Simuler le mode hors ligne'), findsNothing);
  });
}
