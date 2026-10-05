// Receiving changes (SYNC_PLAN.md, Phase 6).
//
// Two devices of one restaurant share one fake server: what A does, B
// receives, and the other way round. Each device is its own in-memory
// database; `SyncRunner` is one pass (send, then receive).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/device_access.dart';
import 'package:stock_inventory/data/providers.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/models/models.dart';
import 'package:stock_inventory/services/auth_service.dart';
import 'package:stock_inventory/services/sync_service.dart';

import '../support/db_fixture.dart';
import '../support/fake_account_backend.dart';

void main() {
  late FakeAccountBackend server;
  late String organization;

  setUp(() async {
    server = FakeAccountBackend();
    organization = server.addOrganization('Brasserie');
    server.addUser(
      'owner@resto.be',
      'motdepasse',
      organizationId: organization,
    );
    await server.signIn(email: 'owner@resto.be', password: 'motdepasse');
  });

  /// A registered account device with an empty database.
  Future<AppDatabase> newDevice() async {
    final db = openEmptyDatabase();
    await server.registerDevice(await DeviceRepository(db).deviceId());
    await DeviceAccessRepository(db).writeAccount(
      email: 'owner@resto.be',
      organizationId: organization,
      organizationName: 'Brasserie',
      role: 'owner',
    );
    return db;
  }

  Future<SyncRunResult> sync(AppDatabase db, {int pageSize = 500}) async {
    final result = await SyncRunner(
      db: db,
      backend: server,
      pageSize: pageSize,
    ).run();
    expect(result.outcome, isNot(SyncOutcome.failed), reason: result.detail);
    return result;
  }

  /// Device A's first day: an establishment, its owner, a category, a unit.
  Future<({Store store, Employee owner, Category category, UnitOfMeasure unit})>
  firstDay(AppDatabase a) async {
    final store = await StoreRepository(a).createStore(
      name: 'Brasserie',
      addressLine: '',
      postalCode: '',
      city: 'Namur',
      phone: '081',
    );
    final owner = (await EmployeeRepository(a).create(
      storeId: store.id,
      firstName: 'Léa',
      lastName: 'Martin',
      pin: 'LM-2026',
      phone: '081',
      email: 'owner@resto.be',
      role: EmployeeRole.owner,
      pay: 0,
    ))!;
    final category = (await CatalogRepository(
      a,
    ).createCategory(storeId: store.id, name: 'Légumes'))!;
    final unit = (await CatalogRepository(
      a,
    ).createUnit(storeId: store.id, name: 'Kilogramme', abbreviation: 'kg'))!;
    return (store: store, owner: owner, category: category, unit: unit);
  }

  test('what A creates, B receives, without queueing it back', () async {
    final a = await newDevice();
    final b = await newDevice();
    final day = await firstDay(a);
    await sync(a);

    final result = await sync(b);

    expect(result.received, greaterThanOrEqualTo(4));
    expect((await StoreRepository(b).stores()).single.id, day.store.id);
    expect(
      (await CatalogRepository(b).categories(day.store.id)).single.name,
      'Légumes',
    );
    expect(await OutboxRepository(b).pendingCount(), 0);

    // Nothing new the second time: B asks after its cursor.
    expect((await sync(b)).received, 0);

    // The owner's email + PIN work on B.
    final login = await CredentialRepository(b).authenticate('owner@resto.be', 'LM-2026');
    expect(login.outcome, LoginOutcome.success);
  });

  test('a screen watching B sees what A adds, without a restart', () async {
    final a = await newDevice();
    final b = await newDevice();
    final day = await firstDay(a);
    await sync(a);
    await sync(b);

    final seen = <List<String>>[];
    final subscription =
        (b.select(b.categories)..where((c) => c.storeId.equals(day.store.id)))
            .watch()
            .listen((rows) => seen.add([for (final r in rows) r.name]..sort()));
    addTearDown(subscription.cancel);
    await pumpEventQueue();
    expect(seen.last, ['Légumes']);

    await CatalogRepository(
      a,
    ).createCategory(storeId: day.store.id, name: 'Fruits');
    await sync(a);
    await sync(b);
    await pumpEventQueue();

    expect(seen.last, ['Fruits', 'Légumes']);
  });

  test('a received row keeps the server\'s change stamp', () async {
    final a = await newDevice();
    final b = await newDevice();
    final day = await firstDay(a);
    await sync(a);
    await sync(b);

    Future<DateTime> stampOn(AppDatabase db) async => (await (db.select(
      db.categories,
    )..where((c) => c.id.equals(day.category.id))).getSingle()).updatedAt;
    expect(await stampOn(b), await stampOn(a));
  });

  test('what A deletes disappears from B', () async {
    final a = await newDevice();
    final b = await newDevice();
    final day = await firstDay(a);
    await sync(a);
    await sync(b);

    await CatalogRepository(a).deleteCategory(day.category.id);
    await sync(a);
    await sync(b);

    expect(await CatalogRepository(b).categories(day.store.id), isEmpty);
  });

  test('A\'s own rows coming back do not duplicate anything', () async {
    final a = await newDevice();
    await firstDay(a);
    await sync(a);
    await sync(a);
    expect(await StoreRepository(a).stores(), hasLength(1));
    expect(await OutboxRepository(a).pendingCount(), 0);
  });

  test('two tablets adding 5 kg offline both end at +10 kg', () async {
    final a = await newDevice();
    final b = await newDevice();
    final day = await firstDay(a);
    final item = (await ItemRepository(a).create(
      storeId: day.store.id,
      name: 'Tomates',
      categoryId: day.category.id,
      unitId: day.unit.id,
      lowStockThreshold: 1,
      quantity: 10,
      openingUnitCost: 2,
    ))!;
    await sync(a);
    await sync(b);
    expect((await ItemRepository(b).item(item.id))!.quantity, 10);

    // Both offline, each receives a delivery of 5 kg.
    await MovementRepository(a).recordStockIn(
      storeId: day.store.id,
      itemId: item.id,
      quantity: 5,
      unitPrice: 2,
    );
    await MovementRepository(b).recordStockIn(
      storeId: day.store.id,
      itemId: item.id,
      quantity: 5,
      unitPrice: 4,
    );

    await sync(a);
    await sync(b);
    await sync(a);

    final onA = (await ItemRepository(a).item(item.id))!;
    final onB = (await ItemRepository(b).item(item.id))!;
    expect(onA.quantity, 20);
    expect(onB.quantity, 20);
    expect(onA.averageCost, closeTo(onB.averageCost!, 1e-9));
    expect(
      await OutboxRepository(a).pendingCount(),
      0,
      reason: 'the rebuild is quiet',
    );
  });

  test('an unsent local change is not overwritten', () async {
    final b = await newDevice();
    final a = await newDevice();
    final day = await firstDay(a);
    await sync(a);
    await sync(b);

    // B renames, but has not sent it yet.
    await CatalogRepository(b).renameCategory(day.category.id, 'Légumes de B');
    // A page arrives with another version of the same row.
    await SyncApplier(b).apply(
      day.store.id,
      PullPage(
        changes: [
          PulledChange(
            seq: 999,
            table: 'categories',
            row: {
              'id': day.category.id,
              'store_id': day.store.id,
              'name': 'Légumes de A',
              'updated_at': '2026-09-30T10:00:00+00:00',
              'deleted_at': null,
            },
          ),
        ],
        nextAfter: 999,
        hasMore: false,
      ),
    );

    expect(
      (await CatalogRepository(b).category(day.category.id))!.name,
      'Légumes de B',
    );
  });

  test('an interrupted download resumes where it stopped', () async {
    final a = await newDevice();
    final b = await newDevice();
    final day = await firstDay(a);
    for (var i = 0; i < 25; i++) {
      await CatalogRepository(
        a,
      ).createCategory(storeId: day.store.id, name: 'Cat $i');
    }
    await sync(a);

    server.failPullAfterPages = 2;
    final first = await SyncRunner(db: b, backend: server, pageSize: 10).run();
    expect(first.outcome, SyncOutcome.offline);
    final kept = (await CatalogRepository(b).categories(day.store.id)).length;
    expect(kept, greaterThan(0), reason: 'the pages that arrived are kept');

    await sync(b, pageSize: 10);
    expect(await CatalogRepository(b).categories(day.store.id), hasLength(26));
    // The resumed pull started after the saved cursor, not from zero.
    final resumed = server.pulls.skip(2).first;
    expect(resumed.$2, greaterThan(0));
  });

  test('a busy day is matched by its store and date', () async {
    final a = await newDevice();
    final b = await newDevice();
    final day = await firstDay(a);
    await CalendarRepository(
      a,
    ).toggleDate(day.store.id, DateTime(2026, 12, 24));
    await sync(a);
    await sync(b);
    expect(
      (await CalendarRepository(b).calendar(day.store.id)).dates,
      contains(DateTime(2026, 12, 24)),
    );
  });

  group('the controller', () {
    test('a device waiting for its data gets it, and stops waiting', () async {
      final a = await newDevice();
      await firstDay(a);
      await sync(a);

      final b = await newDevice();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(b),
          accountBackendProvider.overrideWithValue(server),
          networkChangesProvider.overrideWithValue(const Stream.empty()),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(() => seedDeviceAccessSnapshot(DeviceAccess.demo));
      await container.read(deviceAccessProvider.notifier).hydrate();
      expect(container.read(deviceAccessProvider).hasLocalData, isFalse);

      container.listen(syncControllerProvider, (_, _) {});
      await pumpEventQueue();
      await container.read(syncControllerProvider.notifier).syncNow();

      expect(container.read(deviceAccessProvider).hasLocalData, isTrue);
    });

    test(
      'data that arrived before anyone listened still ends the wait',
      () async {
        final a = await newDevice();
        await firstDay(a);
        await sync(a);

        final b = await newDevice();
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(b),
            accountBackendProvider.overrideWithValue(server),
            networkChangesProvider.overrideWithValue(const Stream.empty()),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(() => seedDeviceAccessSnapshot(DeviceAccess.demo));
        await container.read(deviceAccessProvider.notifier).hydrate();
        expect(container.read(deviceAccessProvider).hasLocalData, isFalse);

        // The download happens without the controller hearing of it.
        await sync(b);

        container.listen(syncControllerProvider, (_, _) {});
        await pumpEventQueue();
        final pass = await container
            .read(syncControllerProvider.notifier)
            .syncNow();

        expect(pass.received, 0);
        expect(container.read(deviceAccessProvider).hasLocalData, isTrue);
      },
    );

    test(
      'another device\'s change arrives on its own, live',
      () async {
        final a = await newDevice();
        final day = await firstDay(a);
        await sync(a);

        final b = await newDevice();
        await sync(b);
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(b),
            accountBackendProvider.overrideWithValue(server),
            networkChangesProvider.overrideWithValue(const Stream.empty()),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(() => seedDeviceAccessSnapshot(DeviceAccess.demo));
        await container.read(deviceAccessProvider.notifier).hydrate();
        container.listen(syncControllerProvider, (_, _) {});
        // Let the start pass finish and the live subscription open.
        await Future<void>.delayed(const Duration(milliseconds: 500));

        await CatalogRepository(
          a,
        ).renameCategory(day.category.id, 'Légumes frais');
        await sync(a);
        await Future<void>.delayed(const Duration(seconds: 2));

        expect(
          (await CatalogRepository(b).category(day.category.id))!.name,
          'Légumes frais',
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}
