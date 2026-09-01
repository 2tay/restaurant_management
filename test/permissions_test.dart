// Phase 6 permission enforcement: the can() table, the router guard, and the
// sidebar filtering. The three read the same table, so this file drives all
// three from one place.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/core/utils/permissions.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/models/models.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';

import 'support/app_harness.dart';
import 'support/db_fixture.dart';

const Size _tablet = Size(1280, 800);
const String _store = StoreIds.sablon;

void main() {
  group('can()', () {
    late AppDatabase db;
    late Employee owner;
    late Employee manager;

    setUp(() async {
      db = await openSeededDatabase();
      final repo = EmployeeRepository(db);
      owner = (await repo.employee(EmployeeIds.marc))!;
      manager = (await repo.employee(EmployeeIds.amelie))!;
    });

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
      expect(canAccessStore(owner, StoreIds.sablon), isTrue);
      expect(canAccessStore(owner, StoreIds.liege), isTrue);
      expect(canAccessStore(manager, manager.storeId), isTrue);
      expect(canAccessStore(manager, StoreIds.liege), isFalse);
    });

    test('visibleStores: everything for the owner, one store otherwise', () {
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
    testApp('a signed-out session is bounced to the login', (tester) async {
      await pumpApp(tester, size: _tablet, asEmployeeId: '');

      appRouter.go(Routes.toDashboard(_store));
      await tester.pumpAndSettle();

      expect(appRouter.state.uri.path, Routes.login);
    });

    testApp('a manager cannot reach the roster or payroll', (tester) async {
      await pumpApp(tester, size: _tablet, asEmployeeId: EmployeeIds.amelie);

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

    testApp('a manager can reach the pointage board and history', (tester) async {
      await pumpApp(tester, size: _tablet, asEmployeeId: EmployeeIds.amelie);

      for (final allowed in [
        Routes.toTimeclock(_store),
        Routes.toAttendanceHistory(_store),
      ]) {
        appRouter.go(allowed);
        await tester.pumpAndSettle();
        expect(appRouter.state.uri.path, allowed, reason: allowed);
      }
    });

    testApp('a manager cannot open the add-store screen', (tester) async {
      await pumpApp(tester, size: _tablet, asEmployeeId: EmployeeIds.amelie);

      appRouter.go(Routes.addStore);
      await tester.pumpAndSettle();

      expect(appRouter.state.uri.path, Routes.toDashboard(_store));
    });
  });

  group('store scoping', () {
    testApp('a manager cannot reach another store, and is sent home', (
      tester,
    ) async {
      await pumpApp(tester, size: _tablet, asEmployeeId: EmployeeIds.amelie);

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

    testApp('a manager lands on the store grid → sent to their store', (
      tester,
    ) async {
      await pumpApp(tester, size: _tablet, asEmployeeId: EmployeeIds.amelie);

      appRouter.go(Routes.stores);
      await tester.pumpAndSettle();

      expect(appRouter.state.uri.path, Routes.toDashboard(_store));
    });

    testApp('the owner reaches any store and the grid', (tester) async {
      await pumpApp(tester, size: _tablet, asEmployeeId: EmployeeIds.marc);

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

    testApp('a manager who signs in lands on their store dashboard', (
      tester,
    ) async {
      await pumpApp(tester, size: _tablet, asEmployeeId: '');

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
    testApp('the owner sees all four Gestion Employée children', (tester) async {
      await pumpApp(tester, size: _tablet, asEmployeeId: EmployeeIds.marc);
      appRouter.go(Routes.toDashboard(_store));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gestion Employée'));
      await tester.pumpAndSettle();

      expect(find.text('Personnel'), findsOneWidget);
      expect(find.text('Tableau de pointage'), findsOneWidget);
      expect(find.text('Historique pointage'), findsOneWidget);
      expect(find.text('Historique de paiement'), findsOneWidget);
    });

    testApp('a manager sees only the two pointage children', (tester) async {
      await pumpApp(tester, size: _tablet, asEmployeeId: EmployeeIds.amelie);
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
