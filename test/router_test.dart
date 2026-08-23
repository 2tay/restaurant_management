// Walks every route in the app and checks it renders.
//
// Stage 3's deliverable is "every route is reachable". This proves it rather
// than asserting it, and keeps proving it as Stage 5 replaces placeholders with
// real screens — a screen that throws on an unknown id, or overflows at tablet
// width, fails here.
//
// Rendered at 1280x800, the design baseline (a 10" tablet in landscape).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/app.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/core/theme/app_spacing.dart';
import 'package:stock_inventory/mock_data/mock_data.dart';
import 'package:stock_inventory/shared/widgets/app_scaffold.dart';

/// The design baseline — a 10" tablet in landscape.
const Size _tabletLandscape = Size(1280, 800);

/// A small tablet in landscape. Above the 900dp collapse breakpoint, so the
/// rail stays extended and the content area has to survive on 792dp.
const Size _smallTablet = Size(1024, 600);

/// A 7" tablet, and roughly what a 10" gives you in portrait. Below the
/// breakpoint, so the rail drops to icons only.
const Size _narrowTablet = Size(800, 1000);

/// Every navigable path, with real ids substituted for path parameters.
List<({String label, String path, bool inShell})> _allRoutes() {
  const store = StoreIds.sablon;
  final item = mockItems.first.id;
  final supplier = mockSuppliers.first.id;
  final member = mockTeam.first.id;

  return [
    (label: 'login', path: Routes.login, inShell: false),
    (label: 'forgot password', path: Routes.forgotPassword, inShell: false),
    (label: 'onboarding', path: Routes.onboarding, inShell: false),
    (label: 'store selector', path: Routes.stores, inShell: false),
    (label: 'add store', path: Routes.addStore, inShell: false),

    (label: 'dashboard', path: Routes.toDashboard(store), inShell: true),

    (label: 'inventory', path: Routes.toInventory(store), inShell: true),
    (label: 'add item', path: Routes.toAddItem(store), inShell: true),
    (label: 'item detail', path: Routes.toItem(store, item), inShell: true),
    (label: 'edit item', path: Routes.toEditItem(store, item), inShell: true),
    (
      label: 'link supplier',
      path: Routes.toLinkSupplier(store, item),
      inShell: true,
    ),
    (
      label: 'price history',
      path: Routes.toPriceHistory(store, item, supplier),
      inShell: true,
    ),

    (label: 'categories', path: Routes.toCategories(store), inShell: true),
    (label: 'units', path: Routes.toUnits(store), inShell: true),

    (label: 'movements', path: Routes.toMovements(store), inShell: true),
    (label: 'stock in', path: Routes.toStockIn(store), inShell: true),
    (label: 'stock out', path: Routes.toStockOut(store), inShell: true),
    (label: 'adjustment', path: Routes.toAdjustment(store), inShell: true),

    (label: 'alerts', path: Routes.toAlerts(store), inShell: true),
    (
      label: 'notifications',
      path: Routes.toNotifications(store),
      inShell: true,
    ),

    (label: 'suppliers', path: Routes.toSuppliers(store), inShell: true),
    (label: 'add supplier', path: Routes.toAddSupplier(store), inShell: true),
    (
      label: 'supplier detail',
      path: Routes.toSupplier(store, supplier),
      inShell: true,
    ),
    (
      label: 'edit supplier',
      path: Routes.toEditSupplier(store, supplier),
      inShell: true,
    ),
    (
      label: 'supplier pricing',
      path: Routes.toSupplierPricing(store, supplier),
      inShell: true,
    ),

    (label: 'reports', path: Routes.toReports(store), inShell: true),
    (
      label: 'valuation report',
      path: Routes.toValuationReport(store),
      inShell: true,
    ),
    (
      label: 'comparison report',
      path: Routes.toComparisonReport(store),
      inShell: true,
    ),
    (label: 'usage report', path: Routes.toUsageReport(store), inShell: true),

    (label: 'team', path: Routes.toTeam(store), inShell: true),
    (label: 'add member', path: Routes.toAddTeamMember(store), inShell: true),
    (label: 'roles', path: Routes.toRoles(store), inShell: true),
    (
      label: 'edit member',
      path: Routes.toEditTeamMember(store, member),
      inShell: true,
    ),

    (
      label: 'store settings',
      path: Routes.toStoreSettings(store),
      inShell: true,
    ),
    (
      label: 'account settings',
      path: Routes.toAccountSettings(store),
      inShell: true,
    ),
    (
      label: 'notification settings',
      path: Routes.toNotificationSettings(store),
      inShell: true,
    ),
    (label: 'sync status', path: Routes.toSyncStatus(store), inShell: true),

    (label: 'search', path: Routes.toSearch(store), inShell: true),
  ];
}

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const ProviderScope(child: StockInventoryApp()));
  await tester.pumpAndSettle();
}

void main() {
  group('every route renders at tablet size', () {
    for (final route in _allRoutes()) {
      testWidgets(route.label, (tester) async {
        await _pumpAt(tester, _tabletLandscape);

        appRouter.go(route.path);
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: '${route.path} threw while rendering',
        );

        // Store-scoped screens must come up inside the shell; auth and store
        // selection must not, since there is no store context yet.
        expect(
          find.byType(AppScaffold),
          route.inShell ? findsOneWidget : findsNothing,
          reason: route.path,
        );
      });
    }
  });

  // Every French label is longer than the English it was designed against, and
  // a Row with an unbounded Text in it overflows silently until somebody looks
  // at that exact screen at that exact width. Walking every route a second time
  // at the narrow breakpoint turns that into a failing test instead of
  // something the client finds during the demo.
  group('every route survives the narrow breakpoint', () {
    for (final route in _allRoutes()) {
      testWidgets('${route.label} at 1024x600', (tester) async {
        await _pumpAt(tester, _smallTablet);

        appRouter.go(route.path);
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: '${route.path} overflowed or threw at 1024x600',
        );
      });
    }
  });

  group('the shell holds together across tablet sizes', () {
    // The rail is pinned to a fixed width on purpose — left to size itself it
    // grew to fit the longest French label and stole 148dp from the content
    // area, overflowing the top bar. These guard that fix, and would catch the
    // same thing happening again when Dutch is added.

    testWidgets('rail is extended and pinned at the 1280x800 baseline', (
      tester,
    ) async {
      await _pumpAt(tester, _tabletLandscape);

      appRouter.go(Routes.toInventory(StoreIds.sablon));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isTrue);
      expect(
        tester.getSize(find.byType(NavigationRail)).width,
        AppSizing.railWidthExpanded,
        reason: 'the rail must not grow to fit its labels',
      );
    });

    testWidgets('nothing overflows at 1024x600 with the rail still extended', (
      tester,
    ) async {
      await _pumpAt(tester, _smallTablet);

      appRouter.go(Routes.toInventory(StoreIds.sablon));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(
        rail.extended,
        isTrue,
        reason: '1024 is above the 900dp collapse breakpoint',
      );
    });

    testWidgets('rail collapses to icons on a narrow tablet', (tester) async {
      await _pumpAt(tester, _narrowTablet);

      appRouter.go(Routes.toInventory(StoreIds.sablon));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isFalse);
      expect(
        tester.getSize(find.byType(NavigationRail)).width,
        AppSizing.railWidthCollapsed,
      );
    });
  });

  group('store scoping', () {
    testWidgets('the shell resolves the store from the path', (tester) async {
      await _pumpAt(tester, _tabletLandscape);

      appRouter.go(Routes.toDashboard(StoreIds.liege));
      await tester.pumpAndSettle();

      final shell = tester.widget<AppScaffold>(find.byType(AppScaffold));
      expect(shell.store.id, StoreIds.liege);
      expect(find.text('Le Comptoir de Liège'), findsWidgets);
    });

    testWidgets('an unknown store id falls back instead of crashing', (
      tester,
    ) async {
      await _pumpAt(tester, _tabletLandscape);

      appRouter.go('/store/does-not-exist/dashboard');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final shell = tester.widget<AppScaffold>(find.byType(AppScaffold));
      expect(shell.store.id, mockStores.first.id);
    });
  });
}
