// Two tablets of one restaurant, through a running Supabase
// (SYNC_PLAN.md, Phase 6).
//
// Tablet A: the owner signs up and creates the restaurant. Tablet B: a
// manager joins with A's code, and the first sync brings the restaurant's
// data. Then changes cross both ways, stock stays equal on both sides, and a
// live update arrives without being asked for.
//
//   supabase start
//   flutter test test/integration --dart-define-from-file=config/local.json

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock_inventory/core/config/env.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/device_access.dart';
import 'package:stock_inventory/data/employee_photo_store.dart';
import 'package:stock_inventory/data/providers.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/services/auth_service.dart';
import 'package:stock_inventory/services/sync_service.dart';

import '../support/db_fixture.dart';

void main() {
  final skip = Env.hasServer
      ? false
      : 'no server: run with --dart-define-from-file=config/local.json';

  SupabaseAccountBackend backendFor() => SupabaseAccountBackend(
    SupabaseClient(
      Env.supabaseUrl,
      Env.supabasePublishableKey,
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    ),
  );

  /// A tablet: its own database, its own server session.
  Future<(AppDatabase, AccountBackend, DeviceAccessController)> tablet() async {
    final db = openEmptyDatabase();
    final backend = backendFor();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        accountBackendProvider.overrideWithValue(backend),
        employeePhotoStoreProvider.overrideWithValue(_NoPhotos()),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() => seedDeviceAccessSnapshot(DeviceAccess.demo));
    final controller = container.read(deviceAccessProvider.notifier);
    await controller.hydrate();
    return (db, backend, controller);
  }

  test(
    'a manager\'s tablet receives the restaurant, and changes cross both '
    'ways',
    () async {
      final run = DateTime.now().microsecondsSinceEpoch;

      // Tablet A: the owner and the restaurant.
      final (a, backendA, controllerA) = await tablet();
      await controllerA.signUp('owner-$run@example.test', 'motdepasse-local');
      await controllerA.createRestaurant(
        restaurantName: 'Resto $run',
        city: 'Namur',
        phone: '081',
        firstName: 'Léa',
        lastName: 'Martin',
        pin: 'PIN-$run',
      );
      final store = (await StoreRepository(a).stores()).single;
      final category = (await CatalogRepository(
        a,
      ).createCategory(storeId: store.id, name: 'Légumes'))!;
      final unit = (await CatalogRepository(
        a,
      ).createUnit(storeId: store.id, name: 'Kilogramme', abbreviation: 'kg'))!;
      final item = (await ItemRepository(a).create(
        storeId: store.id,
        name: 'Tomates',
        categoryId: category.id,
        unitId: unit.id,
        lowStockThreshold: 1,
        quantity: 10,
        openingUnitCost: 2,
      ))!;
      var result = await SyncRunner(db: a, backend: backendA).run();
      expect(result.outcome, SyncOutcome.done, reason: result.detail);
      final code = await backendA.createJoinCode();

      // Tablet B: a manager joins, and waits for the data.
      final (b, backendB, controllerB) = await tablet();
      await controllerB.signUp('manager-$run@example.test', 'motdepasse-local');
      await controllerB.joinWithCode(code);
      expect((await DeviceAccessRepository(b).read()).hasLocalData, isFalse);

      result = await SyncRunner(db: b, backend: backendB).run();
      expect(result.outcome, SyncOutcome.done, reason: result.detail);
      expect(result.received, greaterThanOrEqualTo(6));
      expect((await DeviceAccessRepository(b).read()).hasLocalData, isTrue);
      expect((await StoreRepository(b).stores()).single.name, 'Resto $run');
      expect(await OutboxRepository(b).pendingCount(), 0);

      // The stock arrived and was rebuilt from its movement.
      final onB = (await ItemRepository(b).item(item.id))!;
      expect(onB.quantity, 10);
      expect(onB.averageCost, closeTo(2, 1e-9));

      // The owner's PIN works on the manager's tablet.
      final login = await CredentialRepository(
        b,
      ).authenticate('owner-$run@example.test', 'PIN-$run');
      expect(login.outcome, LoginOutcome.success);

      // B renames and receives a delivery; A gets both.
      await CatalogRepository(b).renameCategory(category.id, 'Légumes frais');
      await MovementRepository(b).recordStockIn(
        storeId: store.id,
        itemId: item.id,
        quantity: 5,
        unitPrice: 4,
      );
      await SyncRunner(db: b, backend: backendB).run();
      result = await SyncRunner(db: a, backend: backendA).run();
      expect(result.outcome, SyncOutcome.done, reason: result.detail);

      expect(
        (await CatalogRepository(a).category(category.id))!.name,
        'Légumes frais',
      );
      final onA = (await ItemRepository(a).item(item.id))!;
      expect(onA.quantity, 15);
      expect(onA.averageCost, closeTo((10 * 2 + 5 * 4) / 15, 1e-9));

      // The dates came back as the same instants.
      final storeOnA = (await StoreRepository(a).stores()).single;
      final storeOnB = (await StoreRepository(b).stores()).single;
      expect(storeOnB.createdAt, storeOnA.createdAt);

      // Live: B hears about A's next change without asking. First wait until
      // the server says it is really watching (LiveSignal.ready), then change.
      final signals = <LiveSignal>[];
      final live = backendB.storeChanges([store.id]).listen(signals.add);
      addTearDown(live.cancel);
      Future<void> waitFor(LiveSignal wanted) async {
        final deadline = DateTime.now().add(const Duration(seconds: 20));
        while (!signals.contains(wanted) && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }

      await waitFor(LiveSignal.ready);
      expect(signals, contains(LiveSignal.ready), reason: 'never ready');

      await CatalogRepository(a).renameCategory(category.id, 'Légumes bio');
      await SyncRunner(db: a, backend: backendA).run();
      await waitFor(LiveSignal.changed);
      expect(
        signals,
        contains(LiveSignal.changed),
        reason: "no live event for A's change",
      );
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _NoPhotos extends EmployeePhotoStore {
  @override
  Future<void> deleteFor(String employeeId) async {}
}
