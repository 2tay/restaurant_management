// Sending the outbox (SYNC_PLAN.md, Phase 5).
//
// `SyncRunner` is one pass, tested directly. `SyncController` decides when
// passes run; its tests use real time for the one timing check.
//
// The server is `FakeAccountBackend`; test/integration/ sends to the real one.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/database/meta_keys.dart';
import 'package:stock_inventory/data/device_access.dart';
import 'package:stock_inventory/data/providers.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart'
    show CategoryIds, ItemIds, StoreIds, SupplierIds;
import 'package:stock_inventory/models/models.dart';
import 'package:stock_inventory/services/auth_service.dart';
import 'package:stock_inventory/services/sync_service.dart';

import '../support/db_fixture.dart';
import '../support/fake_account_backend.dart';

void main() {
  late AppDatabase db;
  late FakeAccountBackend server;
  late OutboxRepository outbox;

  /// A seeded database acting as an account device registered with [server].
  Future<void> accountDevice() async {
    db = await openSeededDatabase();
    outbox = OutboxRepository(db);
    server = FakeAccountBackend();
    final organization = server.addOrganization('Brasserie');
    server.addUser(
      'owner@resto.be',
      'motdepasse',
      organizationId: organization,
    );
    await server.signIn(email: 'owner@resto.be', password: 'motdepasse');
    await server.registerDevice(await DeviceRepository(db).deviceId());
    await DeviceAccessRepository(db).writeAccount(
      email: 'owner@resto.be',
      organizationId: organization,
      organizationName: 'Brasserie',
      role: 'owner',
    );
  }

  SyncRunner runner() => SyncRunner(db: db, backend: server);

  Future<Category> newCategory(String name) async => (await CatalogRepository(
    db,
  ).createCategory(storeId: StoreIds.sablon, name: name))!;

  group('one pass', () {
    setUp(accountDevice);

    test('sends the queue and empties it', () async {
      final category = await newCategory('Épices');
      await CatalogRepository(
        db,
      ).renameCategory(CategoryIds.legumes, 'Légumes bio');

      final result = await runner().run();

      expect(result.outcome, SyncOutcome.done);
      expect(result.accepted, 2);
      expect(await outbox.pendingCount(), 0);
      expect(server.serverRows['categories|${category.id}']?['name'], 'Épices');
      expect(
        server.serverRows['categories|${CategoryIds.legumes}']?['name'],
        'Légumes bio',
      );
    });

    test('sends a parent before its children', () async {
      final order = await OrderRepository(db).createDraft(
        storeId: StoreIds.sablon,
        supplierId: SupplierIds.grossisteCentral,
        lines: const [
          PurchaseOrderLine(
            id: 'x',
            itemId: ItemIds.tomates,
            quantityOrdered: 2,
            unitPrice: 1,
          ),
        ],
      );
      final sent = <String>[];
      server.rejectWhen = (change) {
        sent.add(change['table']! as String);
        return null;
      };

      await runner().run();

      expect(
        sent.indexOf('purchase_orders'),
        lessThan(sent.indexOf('purchase_order_lines')),
      );
      expect(
        server.serverRows.containsKey('purchase_orders|${order.id}'),
        isTrue,
      );
    });

    test('sends in batches of 100', () async {
      for (var i = 0; i < 250; i++) {
        await newCategory('Catégorie $i');
      }
      await runner().run();
      expect(server.batchSizes, [100, 100, 50]);
      expect(await outbox.pendingCount(), 0);
    });

    test('keeps everything when the server cannot be reached', () async {
      await newCategory('Épices');
      server.failNext = const AccountException(AccountErrorCode.network);

      final result = await runner().run();

      expect(result.outcome, SyncOutcome.offline);
      final pending = await outbox.pending();
      expect(pending, hasLength(1));
      expect(pending.single.attempts, 1);
      expect(pending.single.lastError, contains('network'));
    });

    test(
      'moves a refused change to the error list and sends the rest',
      () async {
        final refused = await newCategory('Refusée');
        final accepted = await newCategory('Acceptée');
        server.rejectWhen = (change) =>
            change['row_key'] == refused.id ? 'deleted' : null;

        final result = await runner().run();

        expect(result.outcome, SyncOutcome.done);
        expect(result.rejected, 1);
        expect(await outbox.pendingCount(), 0);
        expect(
          server.serverRows.containsKey('categories|${accepted.id}'),
          isTrue,
        );
        final errors = await SyncErrorRepository(db).all();
        expect(errors.single.rowKey, refused.id);
        expect(errors.single.reason, 'deleted');
      },
    );

    test(
      'a row edited while it travels stays queued with its new version',
      () async {
        final category = await newCategory('Avant');
        server.duringPush = () async {
          server.duringPush = null;
          await CatalogRepository(db).renameCategory(category.id, 'Après');
        };

        final result = await runner().run();

        expect(result.outcome, SyncOutcome.done);
        expect(
          server.serverRows['categories|${category.id}']?['name'],
          'Avant',
        );
        final pending = await outbox.pending();
        expect(pending, hasLength(1));
        expect(pending.single.payload, contains('Après'));

        // The next pass sends it.
        await runner().run();
        expect(
          server.serverRows['categories|${category.id}']?['name'],
          'Après',
        );
        expect(await outbox.pendingCount(), 0);
      },
    );

    test('stops when the owner removed this device', () async {
      await newCategory('Épices');
      await server.removeDevice(await DeviceRepository(db).deviceId());

      final result = await runner().run();

      expect(result.outcome, SyncOutcome.deviceRemoved);
      expect(await outbox.pendingCount(), 1, reason: 'nothing is lost');
      expect(await SyncErrorRepository(db).all(), isEmpty);
    });

    test('stops when the session expired', () async {
      await newCategory('Épices');
      server.failNext = const AccountException(AccountErrorCode.sessionExpired);
      final result = await runner().run();
      expect(result.outcome, SyncOutcome.sessionExpired);
      expect(await outbox.pendingCount(), 1);
    });
  });

  group('the controller', () {
    Future<ProviderContainer> containerFor({required bool account}) async {
      if (account) {
        await accountDevice();
      } else {
        db = await openSeededDatabase();
        outbox = OutboxRepository(db);
        server = FakeAccountBackend();
      }
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          accountBackendProvider.overrideWithValue(server),
          networkChangesProvider.overrideWithValue(const Stream.empty()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(deviceAccessProvider.notifier).hydrate();
      addTearDown(() => seedDeviceAccessSnapshot(DeviceAccess.demo));
      container.listen(syncControllerProvider, (_, _) {});
      await pumpEventQueue();
      return container;
    }

    test('does nothing in the demo', () async {
      final container = await containerFor(account: false);
      await newCategory('Démo');

      await container.read(syncControllerProvider.notifier).syncNow();

      expect(
        container.read(syncControllerProvider).status,
        SyncStatus.disabled,
      );
      expect(server.batchSizes, isEmpty);
      expect(await outbox.pendingCount(), 1);
    });

    test('a manual pass records when it last sent', () async {
      final container = await containerFor(account: true);
      await newCategory('Épices');

      final result = await container
          .read(syncControllerProvider.notifier)
          .syncNow();

      expect(result.outcome, SyncOutcome.done);
      final state = container.read(syncControllerProvider);
      expect(state.status, SyncStatus.idle);
      expect(state.lastSyncAt, isNotNull);
      final saved = await (db.select(
        db.meta,
      )..where((m) => m.key.equals(MetaKeys.lastSyncAt))).getSingleOrNull();
      expect(saved, isNotNull, reason: 'kept across restarts');
    });

    test('says offline when the server cannot be reached', () async {
      final container = await containerFor(account: true);
      await newCategory('Épices');
      server.failNext = const AccountException(AccountErrorCode.network);

      await container.read(syncControllerProvider.notifier).syncNow();

      expect(container.read(syncControllerProvider).status, SyncStatus.offline);
    });

    test('says why it stopped when the device was removed', () async {
      final container = await containerFor(account: true);
      await newCategory('Épices');
      await server.removeDevice(await DeviceRepository(db).deviceId());

      await container.read(syncControllerProvider.notifier).syncNow();

      final state = container.read(syncControllerProvider);
      expect(state.status, SyncStatus.error);
      expect(state.problem, SyncOutcome.deviceRemoved);
    });

    test(
      'sends a local change on its own, a few seconds later',
      () async {
        await containerFor(account: true);
        // The pass the controller runs on start has emptied the queue.
        await Future<void>.delayed(const Duration(milliseconds: 200));
        final category = await newCategory('Automatique');

        await Future<void>.delayed(
          SyncController.changeDelay + const Duration(seconds: 1),
        );

        expect(
          server.serverRows.containsKey('categories|${category.id}'),
          isTrue,
        );
        expect(await outbox.pendingCount(), 0);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}
