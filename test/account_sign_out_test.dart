// Signing the account out from Paramètres → Compte: the device is wiped and
// the app lands on the welcome screen, not on the restaurant's screens left
// empty (« Aucun établissement »).

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
import 'support/seed/dataset/dataset.dart'
    show EmployeeIds, StoreIds;

import 'support/app_harness.dart';
import 'support/db_fixture.dart';
import 'support/fake_account_backend.dart';

void main() {
  testApp('signing the account out lands on the welcome screen', (
    tester,
  ) async {
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
          accountBackendProvider.overrideWithValue(FakeAccountBackend()),
        ],
        child: const StockInventoryApp(),
      ),
    );
    appRouter.go(Routes.toAccountSettings(StoreIds.sablon));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Se déconnecter du compte'));
    await tester.pumpAndSettle();
    // The confirmation dialog's own button.
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Se déconnecter du compte'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bienvenue'), findsOneWidget);
    expect(find.text('Aucun établissement'), findsNothing);
    expect(
      appRouter.routerDelegate.currentConfiguration.uri.path,
      Routes.welcome,
    );
  });
}
