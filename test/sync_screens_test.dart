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
import 'package:stock_inventory/data/seed/dataset/dataset.dart'
    show EmployeeIds, StoreIds;
import 'package:stock_inventory/services/sync_service.dart';

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
  Future<AppDatabase> pumpAccount(WidgetTester tester, SyncState state) async {
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
    addTearDown(() => seedDeviceAccessSnapshot(DeviceAccess.demo));
    seedCurrentEmployeeSnapshot(
      await SessionRepository(db).signIn(EmployeeIds.marc),
    );
    addTearDown(() => seedCurrentEmployeeSnapshot(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          accountBackendProvider.overrideWithValue(FakeAccountBackend()),
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
    expect(find.text('Réinitialiser la démonstration'), findsNothing);
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
    expect(find.text('Se reconnecter'), findsOneWidget);
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

  testApp('the demo keeps its own honest notice', (tester) async {
    await pumpApp(tester, size: const Size(1280, 800));
    appRouter.go(Routes.toSyncStatus(StoreIds.sablon));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Démonstration : les données restent'),
      findsOneWidget,
    );
    expect(find.text('Réinitialiser la démonstration'), findsWidgets);
  });
}
