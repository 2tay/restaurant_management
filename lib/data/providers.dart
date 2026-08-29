import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database/app_database.dart';
import 'repositories/demo_repository.dart';

/// The database, and the single point at which it is injected.
///
/// It has no default: `main()` overrides it with the opened file, and every test
/// overrides it with `AppDatabase.memory()`. A provider that could quietly build
/// its own would let a test run against the developer's real data, and would let
/// a forgotten override ship.
///
/// Stage 8 fills this file out with a provider per repository and a
/// `StreamProvider.family` per screen-level query. Only what stage 2 actually
/// needs is here.
final Provider<AppDatabase> databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError(
    'databaseProvider has no default. Override it in ProviderScope with the '
    'database from openAppDatabase(), or with AppDatabase.memory() in a test.',
  );
});

final Provider<DemoRepository> demoRepositoryProvider =
    Provider<DemoRepository>((ref) => DemoRepository(ref.watch(databaseProvider)));
