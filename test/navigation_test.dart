// Verifies the Phase 1.5 navigation contract.
//
// Phase 1 had no navigation stack at all — every move was a `go`, which
// replaces rather than stacks — so "back" was impossible rather than merely
// missing. These tests pin the fix so it cannot quietly regress.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';

import 'support/app_harness.dart';

const Size _tablet = Size(1280, 800);
const String _store = StoreIds.sablon;

Future<void> _pump(WidgetTester tester) => pumpApp(tester, size: _tablet);

/// Root sections show no back control — the sidebar is their navigation, and a
/// back control there would be lying about the stack.
final _rootScreens = <String, String>{
  'dashboard': Routes.toDashboard(_store),
  'inventory': Routes.toInventory(_store),
  'movements': Routes.toMovements(_store),
  'orders': Routes.toOrders(_store),
  'suppliers': Routes.toSuppliers(_store),
  'categories': Routes.toCategories(_store),
  'units': Routes.toUnits(_store),
  'alerts': Routes.toAlerts(_store),
  'notifications': Routes.toNotifications(_store),
  'reports': Routes.toReports(_store),
  'employees': Routes.toEmployees(_store),
  'timeclock': Routes.toTimeclock(_store),
  'attendance history': Routes.toAttendanceHistory(_store),
  'payroll': Routes.toPayroll(_store),
  'store settings': Routes.toStoreSettings(_store),
  'account settings': Routes.toAccountSettings(_store),
  'notification settings': Routes.toNotificationSettings(_store),
  'sync status': Routes.toSyncStatus(_store),
};

/// Everything reached by a push must offer a way back.
Map<String, String> _pushedScreens() {
  final item = mockItems.first.id;
  final supplier = mockSuppliers.first.id;
  final employee = mockEmployees.first.id;

  return {
    'item detail': Routes.toItem(_store, item),
    'add item': Routes.toAddItem(_store),
    'edit item': Routes.toEditItem(_store, item),
    'link supplier': Routes.toLinkSupplier(_store, item),
    'price history': Routes.toPriceHistory(_store, item, supplier),
    'stock in': Routes.toStockIn(_store),
    'stock out': Routes.toStockOut(_store),
    'adjustment': Routes.toAdjustment(_store),
    'orders: new': Routes.toNewOrder(_store),
    'orders: detail': Routes.toOrder(_store, OrderIds.draftMaraicher),
    'orders: edit': Routes.toEditOrder(_store, OrderIds.draftMaraicher),
    'orders: receive': Routes.toReceiveOrder(_store, OrderIds.partialBoucherie),
    'orders: receipt': Routes.toReceipt(_store, ReceiptIds.cremerieFinal),
    'supplier detail': Routes.toSupplier(_store, supplier),
    'add supplier': Routes.toAddSupplier(_store),
    'edit supplier': Routes.toEditSupplier(_store, supplier),
    'supplier pricing': Routes.toSupplierPricing(_store, supplier),
    'valuation report': Routes.toValuationReport(_store),
    'comparison report': Routes.toComparisonReport(_store),
    'usage report': Routes.toUsageReport(_store),
    'add employee': Routes.toAddEmployee(_store),
    'employee detail': Routes.toEmployee(_store, employee),
    'edit employee': Routes.toEditEmployee(_store, employee),
    'search': Routes.toSearch(_store),
  };
}

void main() {
  group('back control appears exactly where it should', () {
    for (final entry in _rootScreens.entries) {
      testApp('${entry.key} (root) shows no back control', (tester) async {
        await _pump(tester);
        appRouter.go(entry.value);
        await tester.pumpAndSettle();

        expect(
          find.byType(BackControl),
          findsNothing,
          reason: '${entry.key} is a sidebar destination',
        );
      });
    }

    for (final entry in _pushedScreens().entries) {
      testApp('${entry.key} (pushed) offers a back control', (
        tester,
      ) async {
        await _pump(tester);
        unawaited(appRouter.push(entry.value));
        await tester.pumpAndSettle();

        expect(
          find.byType(BackControl),
          findsOneWidget,
          reason: '${entry.key} strands the user without one',
        );
      });
    }
  });

  group('the stack behaves', () {
    testApp('pushing then popping returns to where you were', (
      tester,
    ) async {
      await _pump(tester);
      appRouter.go(Routes.toInventory(_store));
      await tester.pumpAndSettle();

      unawaited(appRouter.push(Routes.toItem(_store, mockItems.first.id)));
      await tester.pumpAndSettle();
      expect(appRouter.canPop(), isTrue);

      appRouter.pop();
      await tester.pumpAndSettle();

      expect(appRouter.canPop(), isFalse);
      expect(
        appRouter.state.uri.path,
        Routes.toInventory(_store),
        reason: 'pop should land back on the list',
      );
    });

    testApp('repeated push and pop never corrupts the stack', (
      tester,
    ) async {
      // The failure this guards against is a screen that pushes instead of
      // popping, quietly growing the stack until back stops working.
      await _pump(tester);
      appRouter.go(Routes.toInventory(_store));
      await tester.pumpAndSettle();

      for (var i = 0; i < 5; i++) {
        unawaited(appRouter.push(Routes.toItem(_store, mockItems.first.id)));
        await tester.pumpAndSettle();
        appRouter.pop();
        await tester.pumpAndSettle();
      }

      expect(appRouter.canPop(), isFalse);
      expect(appRouter.state.uri.path, Routes.toInventory(_store));
      expect(tester.takeException(), isNull);
    });

    testApp('switching section clears anything pushed on top', (
      tester,
    ) async {
      await _pump(tester);
      appRouter.go(Routes.toInventory(_store));
      await tester.pumpAndSettle();
      unawaited(appRouter.push(Routes.toItem(_store, mockItems.first.id)));
      await tester.pumpAndSettle();

      // Tapping a sidebar destination is a `go`, so the pushed detail should
      // not survive it.
      appRouter.go(Routes.toSuppliers(_store));
      await tester.pumpAndSettle();

      expect(appRouter.canPop(), isFalse);
    });
  });

  group('the sidebar tracks where the user is', () {
    testApp('highlights the section a nested screen belongs to', (
      tester,
    ) async {
      await _pump(tester);
      unawaited(appRouter.push(Routes.toItem(_store, mockItems.first.id)));
      await tester.pumpAndSettle();

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      // Inventaire is the second destination.
      expect(
        rail.selectedIndex,
        1,
        reason: 'an item detail is still inside Inventaire',
      );
    });

    testApp('highlights Fournisseurs on a supplier pricing screen', (
      tester,
    ) async {
      await _pump(tester);
      unawaited(
        appRouter.push(
          Routes.toSupplierPricing(_store, mockSuppliers.first.id),
        ),
      );
      await tester.pumpAndSettle();

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      // Dashboard, Inventaire, Mouvements, Commandes, Fournisseurs.
      expect(rail.selectedIndex, 4);
    });

    testApp('highlights Gestion Employée from a nested employee screen', (
      tester,
    ) async {
      await _pump(tester);
      unawaited(
        appRouter.push(Routes.toEmployee(_store, mockEmployees.first.id)),
      );
      await tester.pumpAndSettle();

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      // Dashboard, Inventaire, Mouvements, Commandes, Fournisseurs, Catégories
      // et unités, Alertes, Rapports, Gestion Employée.
      expect(rail.selectedIndex, 8);
    });
  });

  group('the Gestion Employée dropdown', () {
    testApp('expands to reveal all four sections, and each navigates', (
      tester,
    ) async {
      await _pump(tester);
      appRouter.go(Routes.toDashboard(_store));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gestion Employée'));
      await tester.pumpAndSettle();

      expect(find.text('Personnel'), findsOneWidget);
      expect(find.text('Tableau de pointage'), findsOneWidget);
      expect(find.text('Historique pointage'), findsOneWidget);
      expect(find.text('Historique de paiement'), findsOneWidget);

      await tester.tap(find.text('Personnel'));
      await tester.pumpAndSettle();
      expect(appRouter.state.uri.path, Routes.toEmployees(_store));
    });

    testApp('the Tableau de bord item reaches the pointage board', (
      tester,
    ) async {
      await _pump(tester);
      appRouter.go(Routes.toDashboard(_store));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gestion Employée'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tableau de pointage'));
      await tester.pumpAndSettle();

      expect(appRouter.state.uri.path, Routes.toTimeclock(_store));
    });
  });

  group('forms protect unsaved input', () {
    testApp('a clean form leaves without asking', (tester) async {
      await _pump(tester);
      appRouter.go(Routes.toInventory(_store));
      await tester.pumpAndSettle();
      unawaited(appRouter.push(Routes.toAddItem(_store)));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(BackControl));
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmDialog), findsNothing);
      expect(appRouter.state.uri.path, Routes.toInventory(_store));
    });

    testApp('a dirty form confirms before discarding', (tester) async {
      await _pump(tester);
      appRouter.go(Routes.toInventory(_store));
      await tester.pumpAndSettle();
      unawaited(appRouter.push(Routes.toAddItem(_store)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Chicons');
      await tester.pumpAndSettle();

      await tester.tap(find.byType(BackControl));
      await tester.pumpAndSettle();

      expect(
        find.byType(ConfirmDialog),
        findsOneWidget,
        reason: 'typed input must not vanish silently',
      );

      // Keeping the input leaves the user on the form.
      await tester.tap(find.text('Continuer la saisie'));
      await tester.pumpAndSettle();
      expect(appRouter.state.uri.path, Routes.toAddItem(_store));

      // Discarding leaves.
      await tester.tap(find.byType(BackControl));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abandonner'));
      await tester.pumpAndSettle();
      expect(appRouter.state.uri.path, Routes.toInventory(_store));
    });
  });

  group('dialogs follow the button convention', () {
    testApp('dismissive action sits left of the confirming action', (
      tester,
    ) async {
      await _pump(tester);
      unawaited(appRouter.push(Routes.toItem(_store, mockItems.first.id)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Supprimer').first);
      await tester.pumpAndSettle();

      final cancel = tester.getCenter(find.text('Annuler'));
      final confirm = tester.getCenter(find.text('Supprimer').last);

      expect(
        cancel.dx,
        lessThan(confirm.dx),
        reason: 'dismissive left, constructive right — everywhere',
      );
    });
  });
}
