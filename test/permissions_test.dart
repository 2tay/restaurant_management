// Phase 6 permission enforcement: the can() table, the router guard, and the
// sidebar filtering. The three read the same table, so this file drives all
// three from one place.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/app.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/core/utils/permissions.dart';
import 'package:stock_inventory/mock_data/mock_data.dart';
import 'package:stock_inventory/models/models.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';

import 'support/mock_reset.dart';

const Size _tablet = Size(1280, 800);
const String _store = StoreIds.sablon;

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = _tablet;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: StockInventoryApp()));
  await tester.pumpAndSettle();
}

void main() {
  setUp(restoreMockData);

  group('can()', () {
    test('the owner holds every capability', () {
      for (final capability in Capability.values) {
        expect(can(EmployeeRole.owner, capability), isTrue, reason: '$capability');
      }
    });

    test('the manager holds only the two pointage capabilities', () {
      expect(can(EmployeeRole.manager, Capability.viewTimeclock), isTrue);
      expect(can(EmployeeRole.manager, Capability.viewAttendanceHistory), isTrue);
      for (final capability in const [
        Capability.manageEmployees,
        Capability.managePayroll,
        Capability.editStoreSettings,
        Capability.createStore,
        Capability.spanAllStores,
      ]) {
        expect(can(EmployeeRole.manager, capability), isFalse, reason: '$capability');
      }
    });

    test('canAccessStore: owner spans, others are bound to their store', () {
      final owner = MockQueries.employeeById(EmployeeIds.marc)!;
      final manager = MockQueries.employeeById(EmployeeIds.amelie)!;

      expect(canAccessStore(owner, StoreIds.sablon), isTrue);
      expect(canAccessStore(owner, StoreIds.liege), isTrue);
      expect(canAccessStore(manager, manager.storeId), isTrue);
      expect(canAccessStore(manager, StoreIds.liege), isFalse);
    });

    test('visibleStores: everything for the owner, one store otherwise', () {
      final owner = MockQueries.employeeById(EmployeeIds.marc)!;
      final manager = MockQueries.employeeById(EmployeeIds.amelie)!;

      expect(visibleStores(owner, mockStores).length, mockStores.length);
      expect(
        visibleStores(manager, mockStores).map((s) => s.id),
        [manager.storeId],
      );
    });

    test('staff hold nothing', () {
      for (final capability in Capability.values) {
        expect(can(EmployeeRole.staff, capability), isFalse, reason: '$capability');
      }
    });
  });

  group('router guard', () {
    testWidgets('a signed-out session is bounced to the login', (tester) async {
      MockSession.signOut();
      await _pump(tester);

      appRouter.go(Routes.toDashboard(_store));
      await tester.pumpAndSettle();

      expect(appRouter.state.uri.path, Routes.login);
    });

    testWidgets('a manager cannot reach the roster or payroll', (tester) async {
      MockSession.signIn(MockQueries.employeeById(EmployeeIds.amelie)!);
      await _pump(tester);

      for (final blocked in [
        Routes.toEmployees(_store),
        Routes.toPayroll(_store),
        Routes.toAddEmployee(_store),
      ]) {
        appRouter.go(blocked);
        await tester.pumpAndSettle();
        expect(
          appRouter.state.uri.path,
          Routes.toDashboard(_store),
          reason: blocked,
        );
      }
    });

    testWidgets('a manager can reach the pointage board and history', (
      tester,
    ) async {
      MockSession.signIn(MockQueries.employeeById(EmployeeIds.amelie)!);
      await _pump(tester);

      for (final allowed in [
        Routes.toTimeclock(_store),
        Routes.toAttendanceHistory(_store),
      ]) {
        appRouter.go(allowed);
        await tester.pumpAndSettle();
        expect(appRouter.state.uri.path, allowed, reason: allowed);
      }
    });

    testWidgets('a manager cannot open the add-store screen', (tester) async {
      MockSession.signIn(MockQueries.employeeById(EmployeeIds.amelie)!);
      await _pump(tester);

      appRouter.go(Routes.addStore);
      await tester.pumpAndSettle();

      // Sent home — a manager's home is their own store's dashboard.
      expect(appRouter.state.uri.path, Routes.toDashboard(_store));
    });
  });

  group('store scoping', () {
    testWidgets('a manager cannot reach another store, and is sent home', (
      tester,
    ) async {
      MockSession.signIn(MockQueries.employeeById(EmployeeIds.amelie)!);
      await _pump(tester);

      for (final foreign in [
        Routes.toDashboard(StoreIds.liege),
        Routes.toTimeclock(StoreIds.liege),
        Routes.toInventory(StoreIds.liege),
      ]) {
        appRouter.go(foreign);
        await tester.pumpAndSettle();
        expect(
          appRouter.state.uri.path,
          Routes.toDashboard(_store),
          reason: foreign,
        );
      }
    });

    testWidgets('a manager lands on the store grid → sent to their store', (
      tester,
    ) async {
      MockSession.signIn(MockQueries.employeeById(EmployeeIds.amelie)!);
      await _pump(tester);

      appRouter.go(Routes.stores);
      await tester.pumpAndSettle();

      expect(appRouter.state.uri.path, Routes.toDashboard(_store));
    });

    testWidgets('the owner reaches any store and the grid', (tester) async {
      MockSession.resetToDefault(); // owner
      await _pump(tester);

      for (final anywhere in [
        Routes.toDashboard(StoreIds.liege),
        Routes.toInventory(StoreIds.liege),
        Routes.stores,
      ]) {
        appRouter.go(anywhere);
        await tester.pumpAndSettle();
        expect(appRouter.state.uri.path, anywhere, reason: anywhere);
      }
    });

    testWidgets('a manager who signs in lands on their store dashboard', (
      tester,
    ) async {
      MockSession.signOut();
      await _pump(tester);

      await tester.enterText(
        find.byType(TextField).at(0),
        '89.07.30-201.44', // Amélie's CIN
      );
      await tester.enterText(find.byType(TextField).at(1), '1234');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Se connecter'));
      await tester.pumpAndSettle();

      expect(appRouter.state.uri.path, Routes.toDashboard(_store));
    });
  });

  group('sidebar', () {
    testWidgets('the owner sees all four Gestion Employée children', (
      tester,
    ) async {
      MockSession.resetToDefault(); // owner
      await _pump(tester);
      appRouter.go(Routes.toDashboard(_store));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gestion Employée'));
      await tester.pumpAndSettle();

      expect(find.text('Personnel'), findsOneWidget);
      expect(find.text('Tableau de pointage'), findsOneWidget);
      expect(find.text('Historique pointage'), findsOneWidget);
      expect(find.text('Historique de paiement'), findsOneWidget);
    });

    testWidgets('a manager sees only the two pointage children', (tester) async {
      MockSession.signIn(MockQueries.employeeById(EmployeeIds.amelie)!);
      await _pump(tester);
      appRouter.go(Routes.toDashboard(_store));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gestion Employée'));
      await tester.pumpAndSettle();

      expect(find.text('Personnel'), findsNothing);
      expect(find.text('Historique de paiement'), findsNothing);
      expect(find.text('Tableau de pointage'), findsOneWidget);
      expect(find.text('Historique pointage'), findsOneWidget);
    });
  });
}
