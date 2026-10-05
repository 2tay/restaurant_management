// The device level of the app (SYNC_PLAN.md, Phase 4): demo, account, or
// nothing chosen yet, and every flow that moves between them.
//
// The server is `FakeAccountBackend`; `test/integration/` runs the real
// Supabase backend against the local stack.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/data/current_employee.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/database/meta_keys.dart';
import 'package:stock_inventory/data/device_access.dart';
import 'package:stock_inventory/data/employee_photo_store.dart';
import 'package:stock_inventory/data/providers.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/models/models.dart';
import 'package:stock_inventory/services/auth_service.dart';

import '../support/db_fixture.dart';
import '../support/fake_account_backend.dart';

void main() {
  late FakeAccountBackend server;

  setUp(() {
    server = FakeAccountBackend();
    seedCurrentEmployeeSnapshot(null);
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
        // No photo directory in a unit test.
        employeePhotoStoreProvider.overrideWithValue(_NoPhotos()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(deviceAccessProvider.notifier).hydrate();
    return container;
  }

  DeviceAccess accessOf(ProviderContainer c) => c.read(deviceAccessProvider);
  DeviceAccessController controllerOf(ProviderContainer c) =>
      c.read(deviceAccessProvider.notifier);

  group('the mode a device starts in', () {
    test('a fresh install has chosen nothing', () async {
      final c = await containerFor(openEmptyDatabase());
      expect(accessOf(c).mode, DeviceMode.none);
      expect(accessOf(c).hasLocalData, isFalse);
      expect(deviceAccessSnapshot.mode, DeviceMode.none);
    });

    test(
      'an install from before accounts is the demo it already holds',
      () async {
        final c = await containerFor(await openSeededDatabase());
        expect(accessOf(c).mode, DeviceMode.demo);
      },
    );

    test('trying the demo seeds it and remembers the choice', () async {
      final db = openEmptyDatabase();
      final c = await containerFor(db);
      await controllerOf(c).startDemo();

      expect(accessOf(c).mode, DeviceMode.demo);
      expect(accessOf(c).hasLocalData, isTrue);
      expect(await StoreRepository(db).stores(), isNotEmpty);
      expect(await OutboxRepository(db).pendingCount(), 0);
    });
  });

  group('an owner creating a restaurant', () {
    Future<(AppDatabase, ProviderContainer, Employee)> signUpAndCreate() async {
      final db = await openSeededDatabase();
      final c = await containerFor(db);
      await controllerOf(c).signUp('owner@resto.be', 'motdepasse');
      final owner = await controllerOf(c).createRestaurant(
        restaurantName: 'Chez Nous',
        city: 'Namur',
        phone: '081 00 00 00',
        firstName: 'Léa',
        lastName: 'Martin',
        pin: 'LM-2026',
      );
      return (db, c, owner);
    }

    test('ties the device to the new organization', () async {
      final (db, c, _) = await signUpAndCreate();
      final access = accessOf(c);

      expect(access.mode, DeviceMode.account);
      expect(access.hasLocalData, isTrue);
      expect(access.organizationName, 'Chez Nous');
      expect(access.accountEmail, 'owner@resto.be');
      expect(access.isOwnerAccount, isTrue);
      expect(server.registeredDevices.keys, [
        await DeviceRepository(db).deviceId(),
      ]);
    });

    test('replaces the demo with one establishment and its owner', () async {
      final (db, _, owner) = await signUpAndCreate();

      final stores = await StoreRepository(db).stores();
      expect(stores.map((s) => s.name), ['Chez Nous']);
      final employees = await EmployeeRepository(
        db,
      ).employees(stores.single.id);
      expect(employees.single.id, owner.id);
      expect(owner.role, EmployeeRole.owner);
      expect(owner.email, 'owner@resto.be');
    });

    test('signs the owner in, and their PIN works on the tablet', () async {
      final (db, c, owner) = await signUpAndCreate();
      expect(c.read(currentEmployeeProvider)?.id, owner.id);

      final login = await CredentialRepository(
        db,
      ).authenticate('owner@resto.be', 'LM-2026');
      expect(login.outcome, LoginOutcome.success);
    });

    test('queues the new establishment and owner for the first sync', () async {
      final (db, _, _) = await signUpAndCreate();
      final tables = {
        for (final entry in await OutboxRepository(db).pending())
          entry.changedTable,
      };
      expect(
        tables,
        containsAll(['stores', 'employees']),
      );
      expect(tables, isNot(contains('items')), reason: 'the demo is gone');
    });

    test('picks up an organization an interrupted attempt created', () async {
      final db = openEmptyDatabase();
      final c = await containerFor(db);
      await controllerOf(c).signUp('owner@resto.be', 'motdepasse');

      server.failNext = const AccountException(AccountErrorCode.network);
      await expectLater(
        controllerOf(c).createRestaurant(
          restaurantName: 'Chez Nous',
          city: 'Namur',
          phone: '081',
          firstName: 'Léa',
          lastName: 'Martin',
          pin: 'LM-2026',
        ),
        throwsA(isA<AccountException>()),
      );
      expect(accessOf(c).mode, DeviceMode.none, reason: 'nothing half-done');

      await server.createOrganization('Chez Nous');
      await controllerOf(c).createRestaurant(
        restaurantName: 'Chez Nous',
        city: 'Namur',
        phone: '081',
        firstName: 'Léa',
        lastName: 'Martin',
        pin: 'LM-2026',
      );
      expect(server.createOrganizationCalls, 1);
      expect(accessOf(c).mode, DeviceMode.account);
    });
  });

  group('a device joining an existing restaurant', () {
    test('a manager joins with a code and waits for the data', () async {
      final db = await openSeededDatabase();
      final c = await containerFor(db);
      final organization = server.addOrganization('Brasserie');
      final code = server.codeFor(organization);

      await controllerOf(c).signUp('manager@resto.be', 'motdepasse');
      await controllerOf(c).joinWithCode(code.toLowerCase());

      final access = accessOf(c);
      expect(access.mode, DeviceMode.account);
      expect(access.hasLocalData, isFalse, reason: 'the demo was cleared');
      expect(access.accountRole, 'manager');
      expect(access.organizationName, 'Brasserie');
      expect(await StoreRepository(db).stores(), isEmpty);
    });

    test('a wrong code changes nothing', () async {
      final db = await openSeededDatabase();
      final c = await containerFor(db);
      await controllerOf(c).signUp('manager@resto.be', 'motdepasse');

      await expectLater(
        controllerOf(c).joinWithCode('WRONG123'),
        throwsA(
          isA<AccountException>().having(
            (e) => e.code,
            'code',
            AccountErrorCode.invalidCode,
          ),
        ),
      );
      expect(accessOf(c).mode, DeviceMode.demo);
      expect(await StoreRepository(db).stores(), isNotEmpty);
    });

    test('an owner signing in on a second device', () async {
      final db = openEmptyDatabase();
      final c = await containerFor(db);
      final organization = server.addOrganization('Brasserie');
      server.addUser(
        'owner@resto.be',
        'motdepasse',
        organizationId: organization,
      );

      final summary = await controllerOf(
        c,
      ).signIn('owner@resto.be', 'motdepasse');
      expect(summary.hasOrganization, isTrue);
      await controllerOf(c).finishWithAccount(summary);

      expect(accessOf(c).isOwnerAccount, isTrue);
      expect(accessOf(c).hasLocalData, isFalse);
    });
  });

  group('signing the account out', () {
    test('wipes the device but keeps its id', () async {
      final db = await openSeededDatabase();
      final c = await containerFor(db);
      final deviceId = await DeviceRepository(db).deviceId();
      await controllerOf(c).signUp('owner@resto.be', 'motdepasse');
      await controllerOf(c).createRestaurant(
        restaurantName: 'Chez Nous',
        city: 'Namur',
        phone: '081',
        firstName: 'Léa',
        lastName: 'Martin',
        pin: 'LM-2026',
      );

      await controllerOf(c).signOutAccount();

      expect(accessOf(c).mode, DeviceMode.none);
      expect(c.read(currentEmployeeProvider), isNull);
      expect(server.currentUser, isNull);
      for (final table in ['stores', 'employees', 'items', 'stock_movements']) {
        final count = await db
            .customSelect('SELECT count(*) AS n FROM $table')
            .getSingle();
        expect(count.read<int>('n'), 0, reason: table);
      }
      expect(await OutboxRepository(db).pendingCount(), 0);
      expect(await DeviceRepository(db).deviceId(), deviceId);
      final organization = await (db.select(
        db.meta,
      )..where((m) => m.key.equals(MetaKeys.organizationId))).getSingleOrNull();
      expect(organization, isNull);
    });

    test('still wipes when the server cannot be reached', () async {
      final db = await openSeededDatabase();
      final c = await containerFor(db);
      final organization = server.addOrganization('Brasserie');
      server.addUser(
        'owner@resto.be',
        'motdepasse',
        organizationId: organization,
      );
      await controllerOf(c).finishWithAccount(
        await controllerOf(c).signIn('owner@resto.be', 'motdepasse'),
      );

      server.failNext = const AccountException(AccountErrorCode.network);
      await controllerOf(c).signOutAccount();
      expect(accessOf(c).mode, DeviceMode.none);
    });
  });
}

class _NoPhotos extends EmployeePhotoStore {
  @override
  Future<void> deleteFor(String employeeId) async {}
}
