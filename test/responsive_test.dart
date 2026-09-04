// Walks every route at the window sizes `router_test.dart` does not cover, and
// again with the type turned up.
//
// The router walk proves each route *renders*, at 1280x800, 1024x600 and
// 800x1280. This proves the two claims that walk cannot: that the same screens
// hold at a 360dp phone and a 1600dp desktop window, and that they hold when
// the user has made the text bigger. A `RenderFlex` overflow surfaces as an
// exception in a widget test, so `takeException()` is the whole assertion — a
// fixed-width column that no longer fits fails here rather than striping the
// screen yellow in front of the client.
//
// Deliberately the same route list as the router walk (`route_walk.dart`)
// rather than a chosen sample. The screens that break at a new width are never
// the ones anybody thought to check: this suite found twelve.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/core/theme/app_spacing.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/shared/widgets/app_scaffold.dart';
import 'package:stock_inventory/shared/widgets/app_sidebar.dart';
import 'package:stock_inventory/shared/widgets/primary_button.dart';

import 'support/app_harness.dart';
import 'support/route_walk.dart';

/// The ends of the supported range, plus the breakpoint between them.
///
/// - 360x780 — the narrowest phone anything must survive. The sidebar is in a
///   drawer here and the shell grows a top bar.
/// - 600x960 — sitting exactly on [AppBreakpoints.compact], where that switch
///   happens. A size on a threshold catches off-by-one comparisons.
/// - 1600x900 — a desktop window, where line length rather than fit is the
///   risk.
///
/// The tablet sizes in between are `router_test.dart`'s job.
const _sizes = <String, Size>{
  'phone 360x780': Size(360, 780),
  'boundary 600x960': Size(600, 960),
  'desktop 1600x900': Size(1600, 900),
};

/// Goes to [path] on a freshly pumped app and returns whatever it threw.
///
/// `appRouter` is a global and keeps the location the previous test left it on,
/// so the first frame after `pumpApp` renders *that* page. Its exception
/// belongs to the test that navigated there, not to this one — dropping it here
/// is what stops a single broken screen failing every test after it.
Future<Object?> _renderAt(
  WidgetTester tester,
  Size size,
  String path,
) async {
  await pumpApp(tester, size: size);
  tester.takeException();

  appRouter.go(path);
  await tester.pumpAndSettle();
  return tester.takeException();
}

void main() {
  for (final entry in _sizes.entries) {
    group('every route survives ${entry.key}', () {
      for (final route in allRoutes()) {
        testApp('${route.label} at ${entry.key}', (tester) async {
          expect(
            await _renderAt(tester, entry.value, route.path),
            isNull,
            reason: '${route.path} overflowed or threw at ${entry.key}',
          );
        });
      }
    });
  }

  // Turning the OS text size up is the other axis a fixed layout fails on, and
  // it fails silently in the same way. 1.5x is the setting someone who needs
  // reading glasses and is not wearing them will have picked; it is also where
  // a row pinned to a fixed height starts clipping its own contents.
  group('every route survives 150% text', () {
    for (final route in allRoutes()) {
      testApp('${route.label} at 1.5x text', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        expect(
          await _renderAt(tester, const Size(1280, 800), route.path),
          isNull,
          reason: '${route.path} clipped or overflowed at 150% text',
        );
      });
    }
  });

  group('page header actions shrink rather than stack', () {
    // The stock history header carries three actions — Ajuster le stock,
    // Sortie de stock, Enregistrer une livraison. At full size that is far more
    // than a 360dp window holds.

    testApp('supporting actions collapse to icons on a phone', (tester) async {
      final handle = tester.ensureSemantics();
      await _renderAt(
        tester,
        const Size(360, 780),
        Routes.toMovements(StoreIds.sablon),
      );

      expect(find.text('Ajuster le stock'), findsNothing);
      expect(find.text('Ajuster'), findsNothing);
      expect(
        find.bySemanticsLabel('Ajuster le stock'),
        findsOneWidget,
        reason: 'the label is moved to the button name, never dropped',
      );
      handle.dispose();
    });

    testApp('they use the short label on a portrait tablet', (tester) async {
      await _renderAt(
        tester,
        const Size(800, 1000),
        Routes.toMovements(StoreIds.sablon),
      );

      expect(find.text('Ajuster'), findsOneWidget);
      expect(find.text('Ajuster le stock'), findsNothing);
    });

    testApp('and the full label at the design baseline', (tester) async {
      await _renderAt(
        tester,
        const Size(1280, 800),
        Routes.toMovements(StoreIds.sablon),
      );

      expect(find.text('Ajuster le stock'), findsOneWidget);
    });

    testApp('a header with one action never collapses it', (tester) async {
      // The suppliers list offers only "Ajouter un fournisseur". Reducing the
      // one thing the screen can do to a glyph leaves nothing to read.
      await _renderAt(
        tester,
        const Size(360, 780),
        Routes.toSuppliers(StoreIds.sablon),
      );

      expect(find.text('Ajouter'), findsOneWidget);
    });

    testApp('a lone action stays beside the title when it fits', (
      tester,
    ) async {
      // The rule is "does it fit", not "how wide is the screen". Produits'
      // single Ajouter has room to the right of the title even at 700dp, and
      // pushing it onto its own line there wasted a whole row of a short
      // window for nothing.
      await _renderAt(
        tester,
        const Size(700, 900),
        Routes.toInventory(StoreIds.sablon),
      );

      // The button rather than its text, so the assertion is about the layout
      // and not about which density the header landed on.
      final title = tester.getRect(find.text('Produits'));
      final action = tester.getRect(find.byType(PrimaryButton));

      expect(
        action.left,
        greaterThan(title.right),
        reason: 'the action sits to the right of the title',
      );
      expect(
        action.top,
        lessThan(title.bottom),
        reason: 'and on the same line, not under it',
      );

      // Out at the right edge, not tucked against the title. A `Wrap` that has
      // shrink-wrapped to its children leaves `spaceBetween` nothing to
      // distribute and puts the button right beside the word "Produits" with
      // the rest of the header empty — which is what this catches.
      final header = tester.getRect(find.byType(ShellPage));
      expect(
        header.right - action.right,
        lessThan(AppSpacing.pagePadding + 1),
        reason: 'flush with the content edge',
      );
    });

    testApp('three actions do take their own line when they must', (
      tester,
    ) async {
      await _renderAt(
        tester,
        const Size(700, 900),
        Routes.toMovements(StoreIds.sablon),
      );

      final title = tester.getRect(find.text('Mouvements de stock'));
      final action = tester.getRect(find.byType(PrimaryButton));

      expect(
        action.top,
        greaterThan(title.bottom),
        reason: 'three of them genuinely do not fit beside the title',
      );
    });
  });

  group('page subtitles', () {
    // A subtitle is commentary — the title above it has already named the
    // screen. On a phone it costs three lines before any content appears.

    testApp('a descriptive subtitle is dropped on a phone', (tester) async {
      await _renderAt(
        tester,
        const Size(360, 780),
        Routes.toMovements(StoreIds.sablon),
      );

      expect(
        find.text('Historique de toutes les entrées, sorties et corrections.'),
        findsNothing,
      );
      expect(find.text('Mouvements de stock'), findsOneWidget);
    });

    testApp('and kept on a tablet', (tester) async {
      await _renderAt(
        tester,
        const Size(1280, 800),
        Routes.toMovements(StoreIds.sablon),
      );

      expect(
        find.text('Historique de toutes les entrées, sorties et corrections.'),
        findsOneWidget,
      );
    });

    testApp('a subtitle carrying information survives the phone', (
      tester,
    ) async {
      // "3 non lues" is not a description of the notifications screen, it is
      // the answer the user came for.
      await _renderAt(
        tester,
        const Size(360, 780),
        Routes.toNotifications(StoreIds.sablon),
      );

      expect(find.textContaining('non lue'), findsWidgets);
    });
  });

  group('the shell moves the sidebar into a drawer on a phone', () {
    // The sidebar is 88dp even at its narrowest, which is a quarter of a 360dp
    // window. Below AppBreakpoints.compact it moves behind a hamburger instead.

    testApp('no sidebar on screen at 360dp until it is asked for', (
      tester,
    ) async {
      await _renderAt(
        tester,
        const Size(360, 780),
        Routes.toInventory(StoreIds.sablon),
      );

      expect(
        find.byType(AppSidebar),
        findsNothing,
        reason: 'an 88dp rail is a quarter of a 360dp window',
      );

      // Found by icon rather than by tooltip: the tooltip is localised, and
      // this suite runs in French.
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.byType(AppSidebar), findsOneWidget);
      expect(
        tester.getSize(find.byType(AppSidebar)).width,
        AppSizing.sidebarWidthExpanded,
        reason: 'the drawer has room for labels, so it shows them',
      );
    });

    testApp('navigating from the drawer closes it behind the user', (
      tester,
    ) async {
      await _renderAt(
        tester,
        const Size(360, 780),
        Routes.toInventory(StoreIds.sablon),
      );

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SidebarNavTile).first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.byType(AppSidebar),
        findsNothing,
        reason: 'the drawer must not stay open over the page it just opened',
      );
    });

    testApp('the sidebar is back on screen at the 600dp boundary', (
      tester,
    ) async {
      await _renderAt(
        tester,
        const Size(600, 960),
        Routes.toInventory(StoreIds.sablon),
      );

      expect(find.byType(AppSidebar), findsOneWidget);
      expect(
        tester.getSize(find.byType(AppSidebar)).width,
        AppSizing.sidebarWidthCollapsed,
        reason: '600 is above the phone threshold but below the 1100dp one',
      );
    });
  });
}
