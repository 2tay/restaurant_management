// Data already on a device at its first account connection
// (SYNC_PLAN.md, Phase 9).
//
//   only the demo                      -> wiped (Phase 4)
//   own data, the account is empty     -> sent to the account
//   own data, the account has data     -> backed up to a file, then replaced

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/data/current_employee.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/device_access.dart';
import 'package:stock_inventory/data/employee_photo_store.dart';
import 'package:stock_inventory/data/providers.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart' show StoreIds;
import 'package:stock_inventory/models/models.dart';
import 'package:stock_inventory/services/sync_service.dart';

import '../support/db_fixture.dart';
import '../support/fake_account_backend.dart';

void main() {
  late FakeAccountBackend server;
  late Directory backups;

  setUp(() async {
    server = FakeAccountBackend();
    seedCurrentEmployeeSnapshot(null);
    backups = await Directory.systemTemp.createTemp('backups_test_');
    addTearDown(() => backups.delete(recursive: true));
  });

  tearDown(() {
    seedDeviceAccessSnapshot(DeviceAccess.demo);
    seedCurrentEmployeeSnapshot(null);
  });

  Future<ProviderContainer> containerFor(AppDatabase db) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        accountBackendProvider.overrideWithValue(server),
        employeePhotoStoreProvider.overrideWithValue(_NoPhotos()),
        backupDirectoryProvider.overrideWithValue(() async => backups),
      ],
    );
    addTearDown(container.dispose);
    await container.read(deviceAccessProvider.notifier).hydrate();
    return container;
  }

  /// The demo, plus an establishment the restaurant created itself, with an
  /// article and its staff.
  Future<({AppDatabase db, Store store})> demoPlusOwn() async {
    final db = await openSeededDatabase();
    final store = await StoreRepository(db).createStore(
      name: 'Chez Nous',
      addressLine: 'Rue 1',
      postalCode: '5000',
      city: 'Namur',
      phone: '081',
    );
    final category = (await CatalogRepository(
      db,
    ).createCategory(storeId: store.id, name: 'Légumes'))!;
    final unit = (await CatalogRepository(
      db,
    ).createUnit(storeId: store.id, name: 'Kilogramme', abbreviation: 'kg'))!;
    await ItemRepository(db).create(
      storeId: store.id,
      name: 'Tomates',
      categoryId: category.id,
      unitId: unit.id,
      lowStockThreshold: 1,
      quantity: 12,
      openingUnitCost: 2,
    );
    await EmployeeRepository(db).create(
      storeId: store.id,
      firstName: 'Léa',
      lastName: 'Martin',
      pin: 'PIN-LEA',
      phone: '081',
      email: 'lea@chez-nous.be',
      role: EmployeeRole.owner,
      pay: 0,
      password: '4321',
    );
    return (db: db, store: store);
  }

  group('what the device holds', () {
    test('nothing, the demo, or its own data', () async {
      expect(
        await LocalDataRepository(openEmptyDatabase()).kind(),
        LocalDataKind.none,
      );
      expect(
        await LocalDataRepository(await openSeededDatabase()).kind(),
        LocalDataKind.demo,
      );
      final mixed = await demoPlusOwn();
      expect(await LocalDataRepository(mixed.db).kind(), LocalDataKind.own);
      expect(await LocalDataRepository(mixed.db).ownStoreNames(), [
        'Chez Nous',
      ]);
    });
  });

  test('own data goes to a new account, without the demo', () async {
    final device = await demoPlusOwn();
    final container = await containerFor(device.db);
    final controller = container.read(deviceAccessProvider.notifier);
    await controller.signUp('lea@chez-nous.be', 'motdepasse');

    await controller.createRestaurantFromLocalData('Chez Nous');

    final access = container.read(deviceAccessProvider);
    expect(access.mode, DeviceMode.account);
    expect(access.hasLocalData, isTrue);
    expect(access.organizationName, 'Chez Nous');
    final stores = await StoreRepository(device.db).stores();
    expect(stores.map((s) => s.id), [device.store.id], reason: 'demo removed');

    // Everything is queued, establishment first.
    final queued = await OutboxRepository(device.db).pending();
    expect(queued.first.changedTable, 'stores');
    expect(
      {for (final e in queued) e.changedTable},
      containsAll([
        'stores',
        'categories',
        'units',
        'items',
        'stock_movements',
        'employees',
        'employee_credentials',
      ]),
    );
    expect(
      queued.where((e) => e.storeId != device.store.id),
      isEmpty,
      reason: 'nothing of the demo is sent',
    );

    // One pass sends it all, and nothing is refused.
    final result = await SyncRunner(db: device.db, backend: server).run();
    expect(result.outcome, SyncOutcome.done);
    expect(result.rejected, 0);
    expect(await OutboxRepository(device.db).pendingCount(), 0);
    expect(server.serverRows.containsKey('stores|${device.store.id}'), isTrue);
    expect(
      server.serverRows.keys.where((k) => k.contains(StoreIds.sablon)),
      isEmpty,
    );

    // The owner's PIN still opens the app.
    final login = await CredentialRepository(
      device.db,
    ).authenticate('PIN-LEA', '4321');
    expect(login.outcome, LoginOutcome.success);
  });

  test(
    'an empty account can receive the data of an existing sign-in',
    () async {
      final device = await demoPlusOwn();
      final organization = server.addOrganization('Chez Nous');
      server.addUser(
        'lea@chez-nous.be',
        'motdepasse',
        organizationId: organization,
      );
      final container = await containerFor(device.db);
      final controller = container.read(deviceAccessProvider.notifier);

      final summary = await controller.signIn('lea@chez-nous.be', 'motdepasse');
      expect(await controller.localData(), LocalDataKind.own);
      expect(await controller.accountHasData(), isFalse);

      await controller.adoptLocalData(summary);
      expect(container.read(deviceAccessProvider).hasLocalData, isTrue);
      expect(await OutboxRepository(device.db).pendingCount(), greaterThan(0));
    },
  );

  test(
    'when the account has data, the device\'s is backed up, then replaced',
    () async {
      // Another tablet already filled the account.
      final organization = server.addOrganization('Chez Nous');
      server.addUser(
        'lea@chez-nous.be',
        'motdepasse',
        organizationId: organization,
      );
      await server.signIn(email: 'lea@chez-nous.be', password: 'motdepasse');
      final other = openEmptyDatabase();
      await server.registerDevice(await DeviceRepository(other).deviceId());
      await StoreRepository(other).createStore(
        name: 'Chez Nous (serveur)',
        addressLine: '',
        postalCode: '',
        city: '',
        phone: '',
      );
      await SyncRunner(db: other, backend: server).run();
      await server.signOut();

      final device = await demoPlusOwn();
      final container = await containerFor(device.db);
      final controller = container.read(deviceAccessProvider.notifier);
      final summary = await controller.signIn('lea@chez-nous.be', 'motdepasse');
      expect(await controller.accountHasData(), isTrue);

      final file = await controller.backupAndFinish(summary);

      // The backup holds the device's data, the demo included.
      final backup =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final storeNames = [
        for (final row in (backup['tables'] as Map)['stores'] as List)
          (row as Map)['name'],
      ];
      expect(storeNames, contains('Chez Nous'));
      expect(storeNames, contains('Brasserie du Sablon'));

      // The device is wiped and waits for the account's data.
      expect(await StoreRepository(device.db).stores(), isEmpty);
      expect(container.read(deviceAccessProvider).mode, DeviceMode.account);

      await SyncRunner(db: device.db, backend: server).run();
      expect(
        (await StoreRepository(device.db).stores()).single.name,
        'Chez Nous (serveur)',
      );
    },
  );
}

class _NoPhotos extends EmployeePhotoStore {
  @override
  Future<void> deleteFor(String employeeId) async {}
}
