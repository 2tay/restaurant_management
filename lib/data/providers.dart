import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database/app_database.dart';
import 'repositories/repositories.dart';

/// The database, and the single point at which it is injected.
///
/// It has no default: `main()` overrides it with the opened file, and every test
/// overrides it with `AppDatabase.memory()`. A provider that could quietly build
/// its own would let a test run against the developer's real data, and would let
/// a forgotten override ship.
///
/// Stage 8 adds the `StreamProvider.family` layer, one per screen-level query.
/// What is here is the database and the repositories over it.
final Provider<AppDatabase> databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError(
    'databaseProvider has no default. Override it in ProviderScope with the '
    'database from openAppDatabase(), or with AppDatabase.memory() in a test.',
  );
});

/// One provider per repository. They hold no state of their own — a repository
/// is a set of queries over the database — so they are plain `Provider`s built
/// from [databaseProvider] and nothing else.

final Provider<StoreRepository> storeRepositoryProvider =
    Provider<StoreRepository>((ref) => StoreRepository(ref.watch(databaseProvider)));

final Provider<CatalogRepository> catalogRepositoryProvider =
    Provider<CatalogRepository>(
      (ref) => CatalogRepository(ref.watch(databaseProvider)),
    );

final Provider<ItemRepository> itemRepositoryProvider =
    Provider<ItemRepository>((ref) => ItemRepository(ref.watch(databaseProvider)));

final Provider<SupplierRepository> supplierRepositoryProvider =
    Provider<SupplierRepository>(
      (ref) => SupplierRepository(ref.watch(databaseProvider)),
    );

final Provider<MovementRepository> movementRepositoryProvider =
    Provider<MovementRepository>(
      (ref) => MovementRepository(ref.watch(databaseProvider)),
    );

final Provider<OrderRepository> orderRepositoryProvider =
    Provider<OrderRepository>(
      (ref) => OrderRepository(ref.watch(databaseProvider)),
    );

final Provider<AccountRepository> accountRepositoryProvider =
    Provider<AccountRepository>(
      (ref) => AccountRepository(ref.watch(databaseProvider)),
    );

final Provider<ReportRepository> reportRepositoryProvider =
    Provider<ReportRepository>(
      (ref) => ReportRepository(ref.watch(databaseProvider)),
    );

final Provider<DemoRepository> demoRepositoryProvider =
    Provider<DemoRepository>((ref) => DemoRepository(ref.watch(databaseProvider)));

final Provider<SessionRepository> sessionRepositoryProvider =
    Provider<SessionRepository>(
      (ref) => SessionRepository(ref.watch(databaseProvider)),
    );
