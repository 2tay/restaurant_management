// A restaurant that used the app offline creates its account from that data
// (SYNC_PLAN.md, Phase 9), through a running Supabase.
//
// Tablet A holds the demo plus an establishment the restaurant created. It
// signs up and creates the restaurant from its own data: the demo is dropped,
// the rest is sent, nothing is refused. Tablet B joins and receives exactly
// that establishment.
//
//   supabase start
//   flutter test test/integration --concurrency=1 --dart-define-from-file=config/local.json

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock_inventory/core/config/env.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/device_access.dart';
import 'package:stock_inventory/data/employee_photo_store.dart';
import 'package:stock_inventory/data/providers.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/models/models.dart';
import 'package:stock_inventory/services/auth_service.dart';
import 'package:stock_inventory/services/sync_service.dart';

import '../support/db_fixture.dart';

void main() {
  final skip = Env.hasServer
      ? false
      : 'no server: run with --dart-define-from-file=config/local.json';

  Future<(AccountBackend, DeviceAccessController)> tablet(
    AppDatabase db,
  ) async {
    final backend = SupabaseAccountBackend(
      SupabaseClient(
        Env.supabaseUrl,
        Env.supabasePublishableKey,
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
          authFlowType: AuthFlowType.implicit,
        ),
      ),
    );
    final backups = await Directory.systemTemp.createTemp('backups_it_');
    addTearDown(() => backups.delete(recursive: true));
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        accountBackendProvider.overrideWithValue(backend),
        employeePhotoStoreProvider.overrideWithValue(_NoPhotos()),
        backupDirectoryProvider.overrideWithValue(() async => backups),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() => seedDeviceAccessSnapshot(DeviceAccess.demo));
    final controller = container.read(deviceAccessProvider.notifier);
    await controller.hydrate();
    return (backend, controller);
  }

  test(
    'offline data becomes the account, and another tablet receives it',
    () async {
      final run = DateTime.now().microsecondsSinceEpoch;
      final a = await openSeededDatabase();
      final store = await StoreRepository(a).createStore(
        name: 'Chez Nous $run',
        addressLine: 'Rue 1',
        postalCode: '5000',
        city: 'Namur',
        phone: '081',
      );
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
        quantity: 12,
        openingUnitCost: 2,
      ))!;
      await EmployeeRepository(a).create(
        storeId: store.id,
        firstName: 'Léa',
        lastName: 'Martin',
        pin: 'PIN-$run',
        phone: '081',
        email: 'lea-$run@example.test',
        role: EmployeeRole.owner,
        pay: 0,
      );

      final (backendA, controllerA) = await tablet(a);
      await controllerA.signUp('owner-$run@example.test', 'motdepasse-local');
      expect(await controllerA.localData(), LocalDataKind.own);
      await controllerA.createRestaurantFromLocalData('Chez Nous $run');

      final sent = await SyncRunner(db: a, backend: backendA).run();
      expect(sent.outcome, SyncOutcome.done, reason: sent.detail);
      expect(sent.rejected, 0, reason: 'nothing of the upload is refused');
      expect(await OutboxRepository(a).pendingCount(), 0);

      final code = await backendA.createJoinCode();
      final b = openEmptyDatabase();
      final (backendB, controllerB) = await tablet(b);
      await controllerB.signUp('manager-$run@example.test', 'motdepasse-local');
      await controllerB.joinWithCode(code);
      final received = await SyncRunner(db: b, backend: backendB).run();
      expect(received.outcome, SyncOutcome.done, reason: received.detail);

      final stores = await StoreRepository(b).stores();
      expect(stores.map((s) => s.name), ['Chez Nous $run'], reason: 'no demo');
      expect((await ItemRepository(b).item(item.id))!.quantity, 12);
      final login = await CredentialRepository(
        b,
      ).authenticate('lea-$run@example.test', 'PIN-$run');
      expect(login.outcome, LoginOutcome.success);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _NoPhotos extends EmployeePhotoStore {
  @override
  Future<void> deleteFor(String employeeId) async {}
}
