// Paramètres → Synchronisation: the state spans the page, the facts are
// cards, and below a medium screen « Synchroniser maintenant » is its icon.
//
// The page on an account device, its sync state fixed by a stand-in
// controller so no timer or server is involved.

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
import 'support/seed/dataset/dataset.dart';
import 'package:stock_inventory/features/settings/presentation/widgets/account_sync_view.dart';
import 'package:stock_inventory/services/sync_service.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';

import 'support/app_harness.dart';
import 'support/db_fixture.dart';
import 'support/fake_account_backend.dart';

class _IdleSync extends SyncController {
  @override
  SyncState build() => const SyncState(status: SyncStatus.idle);
}

void main() {
  /// The sync page at [size], on an account device with the owner signed in.
  Future<void> pumpSyncPage(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
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
          syncControllerProvider.overrideWith(_IdleSync.new),
        ],
        child: const StockInventoryApp(),
      ),
    );
    appRouter.go(Routes.toSyncStatus(StoreIds.sablon));
    await tester.pumpAndSettle();
  }

  testApp('wide: the banner fills the page and keeps its label', (
    tester,
  ) async {
    await pumpSyncPage(tester, const Size(1280, 1000));

    expect(find.text('Synchroniser maintenant'), findsOneWidget);
    final banner = tester.getSize(find.byType(SyncStatusBanner));
    final grid = tester.getSize(find.byType(ResponsiveCardGrid).first);
    expect(banner.width, grid.width);
    // Wider than the old 720dp cap.
    expect(banner.width, greaterThan(720));
    // Two cards side by side.
    final cards = find.byType(IconInfoCard);
    expect(
      tester.getTopLeft(cards.at(1)).dy,
      tester.getTopLeft(cards.at(0)).dy,
    );
  });

  testApp('small: the sync button is only its icon, one card per line', (
    tester,
  ) async {
    await pumpSyncPage(tester, const Size(400, 1400));

    expect(find.text('Synchroniser maintenant'), findsNothing);
    final button = find.byKey(const ValueKey('sync-now'));
    expect(button, findsOneWidget);
    expect(
      find.descendant(of: button, matching: find.byType(Icon)),
      findsOneWidget,
    );
    final cards = find.byType(IconInfoCard);
    expect(
      tester.getTopLeft(cards.at(1)).dy,
      greaterThan(tester.getTopLeft(cards.at(0)).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
