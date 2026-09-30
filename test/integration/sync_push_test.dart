// Sending the outbox to a running Supabase (SYNC_PLAN.md, Phase 5).
//
// The whole path with nothing faked: an owner signs up and creates a
// restaurant through the app's own flow, which queues the first
// establishment and the owner; one pass sends them; the server's
// `pull_changes` hands them back. Then an edit, a delete that another device
// cannot undo, and the rows a server refuses.
//
//   supabase start
//   flutter test test/integration --dart-define-from-file=config/local.json

import 'package:drift/drift.dart' show Value;
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

  SupabaseClient clientFor() => SupabaseClient(
    Env.supabaseUrl,
    Env.supabasePublishableKey,
    authOptions: const AuthClientOptions(
      autoRefreshToken: false,
      authFlowType: AuthFlowType.implicit,
    ),
  );

  test(
    'a new restaurant reaches the server and comes back from it',
    () async {
      final run = DateTime.now().microsecondsSinceEpoch;
      final client = clientFor();
      final backend = SupabaseAccountBackend(client);
      final AppDatabase db = openEmptyDatabase();

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

      await controller.signUp('owner-$run@example.test', 'motdepasse-local');
      await controller.createRestaurant(
        restaurantName: 'Resto $run',
        city: 'Namur',
        phone: '081',
        firstName: 'Léa',
        lastName: 'Martin',
        pin: 'PIN-$run',
        password: '4321',
      );
      final store = (await StoreRepository(db).stores()).single;

      // Everything the flow queued goes up in one pass.
      var result = await SyncRunner(db: db, backend: backend).run();
      expect(result.outcome, SyncOutcome.done, reason: result.detail);
      expect(result.rejected, 0);
      expect(await OutboxRepository(db).pendingCount(), 0);

      Future<List<Map<String, dynamic>>> pulled() async {
        final answer =
            await client.rpc(
                  'pull_changes',
                  params: {'p_store_id': store.id, 'p_after': 0},
                )
                as Map<String, dynamic>;
        return (answer['changes'] as List).cast<Map<String, dynamic>>();
      }

      var changes = await pulled();
      Set<String> tables() => {for (final c in changes) c['table'] as String};
      expect(
        tables(),
        containsAll(['stores', 'employees', 'employee_credentials']),
      );
      final storeRow = changes.firstWhere((c) => c['table'] == 'stores')['row'];
      expect(storeRow['name'], 'Resto $run');

      // An edit and a new category follow.
      final catalog = CatalogRepository(db);
      final category = (await catalog.createCategory(
        storeId: store.id,
        name: 'Légumes',
      ))!;
      result = await SyncRunner(db: db, backend: backend).run();
      expect(result.accepted, 1);

      await catalog.deleteCategory(category.id);
      result = await SyncRunner(db: db, backend: backend).run();
      expect(result.accepted, 1);
      changes = await pulled();
      final categoryRow = changes.firstWhere(
        (c) => c['table'] == 'categories' && c['row']['id'] == category.id,
      )['row'];
      expect(
        categoryRow['deleted_at'],
        isNotNull,
        reason: 'the delete travelled',
      );

      // A device that still had the category, un-deleting it offline, is
      // refused: delete wins. Simulated by editing the row back here.
      await (db.update(db.categories)..where((c) => c.id.equals(category.id)))
          .write(const CategoriesCompanion(deletedAt: Value(null)));
      result = await SyncRunner(db: db, backend: backend).run();
      expect(result.rejected, 1);
      final errors = await SyncErrorRepository(db).all();
      expect(errors.single.reason, 'deleted');
      expect(await OutboxRepository(db).pendingCount(), 0);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _NoPhotos extends EmployeePhotoStore {
  @override
  Future<void> deleteFor(String employeeId) async {}
}
