// Walks every route in the app and checks it renders.
//
// Stage 3's deliverable is "every route is reachable". This proves it rather
// than asserting it, and keeps proving it as Stage 5 replaces placeholders with
// real screens — a screen that throws on an unknown id, or overflows at tablet
// width, fails here.
//
// Rendered at 1280x800, the design baseline (a 10" tablet in landscape).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/core/theme/app_spacing.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/shared/widgets/app_scaffold.dart';
import 'package:stock_inventory/shared/widgets/app_sidebar.dart';

import 'support/app_harness.dart';
import 'support/route_walk.dart';

/// The design baseline — a 10" tablet in landscape.
const Size _tabletLandscape = Size(1280, 800);

/// A small tablet in landscape. Above the 900dp collapse breakpoint, so the
/// rail stays extended and the content area has to survive on 792dp.
const Size _smallTablet = Size(1024, 600);

/// A 7" tablet, and roughly what a 10" gives you in portrait. Below the
/// breakpoint, so the rail drops to icons only.
const Size _narrowTablet = Size(800, 1000);

/// A 10" tablet rotated to portrait. Not a design target, but the app does not
/// lock orientation, so every screen must degrade rather than break.
const Size _portraitTablet = Size(800, 1280);


Future<void> _pumpAt(WidgetTester tester, Size size) =>
    pumpApp(tester, size: size);

void main() {
  group('every route renders at tablet size', () {
    for (final route in allRoutes()) {
      testApp(route.label, (tester) async {
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
    for (final route in allRoutes()) {
      testApp('${route.label} at 1024x600', (tester) async {
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

  // The brief asks for landscape-first but requires portrait to stay usable.
  // Nothing in the app locks orientation, so a user can rotate at any moment
  // and every screen has to survive it.
  group('every route survives portrait', () {
    for (final route in allRoutes()) {
      testApp('${route.label} at 800x1280', (tester) async {
        await _pumpAt(tester, _portraitTablet);

        appRouter.go(route.path);
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: '${route.path} broke in portrait',
        );
      });
    }
  });

  group('the shell holds together across tablet sizes', () {
    // The sidebar is pinned to a fixed width on purpose — 280dp so no French
    // destination label is ever truncated, and it must not grow past that when
    // Dutch is added. Below ~1100dp it drops to an icon strip so the dense
    // content area keeps its room.

    testApp('sidebar is expanded and 280dp wide at the 1280x800 baseline', (
      tester,
    ) async {
      await _pumpAt(tester, _tabletLandscape);

      appRouter.go(Routes.toInventory(StoreIds.sablon));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(AppSidebar)).width,
        AppSizing.sidebarWidthExpanded,
        reason: 'the sidebar must not grow to fit its labels',
      );
    });

    testApp('sidebar collapses to an icon strip at 1024x600', (tester) async {
      await _pumpAt(tester, _smallTablet);

      appRouter.go(Routes.toInventory(StoreIds.sablon));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(AppSidebar)).width,
        AppSizing.sidebarWidthCollapsed,
        reason: '1024 is below the ~1100dp sidebar breakpoint',
      );
    });

    testApp('sidebar collapses to icons on a narrow tablet', (tester) async {
      await _pumpAt(tester, _narrowTablet);

      appRouter.go(Routes.toInventory(StoreIds.sablon));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(AppSidebar)).width,
        AppSizing.sidebarWidthCollapsed,
      );
    });
  });

  group('store scoping', () {
    testApp('the shell resolves the store from the path', (tester) async {
      await _pumpAt(tester, _tabletLandscape);

      appRouter.go(Routes.toDashboard(StoreIds.liege));
      await tester.pumpAndSettle();

      final shell = tester.widget<AppScaffold>(find.byType(AppScaffold));
      expect(shell.store.id, StoreIds.liege);
      expect(find.text('Le Comptoir de Liège'), findsWidgets);
    });

    testApp('an unknown store id falls back instead of crashing', (
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
