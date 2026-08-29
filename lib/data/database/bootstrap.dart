import '../seed/demo_seed.dart';
import 'app_database.dart';

/// Opens the app's database, seeding it if it has never been used.
///
/// Called once from `main()`, before the first frame. The returned instance is
/// handed to `ProviderScope` as the override for `databaseProvider`, which is
/// the only way anything else gets hold of it.
///
/// A first launch finds no establishments and writes the demo dataset, so a
/// fresh install looks exactly like the Phase 1 demo did. Every launch after
/// that finds the user's own data and leaves it alone — which is the whole
/// point of this phase, and the one thing no amount of Phase 1 polish could
/// fake.
Future<AppDatabase> openAppDatabase() async {
  final AppDatabase db = AppDatabase();
  await seedIfEmpty(db);
  return db;
}

/// Writes the demo dataset if the database is empty. Returns whether it did.
///
/// "Empty" is judged on the establishments table rather than on a flag in
/// `meta`, because a store is the one thing the app cannot function without: if
/// there are none, nothing else in the database can be reached from the UI, and
/// re-seeding is the only useful thing to do. A flag would have to be kept
/// truthful; this cannot go stale.
Future<bool> seedIfEmpty(AppDatabase db) async {
  final existing = await (db.select(db.stores)..limit(1)).getSingleOrNull();
  if (existing != null) return false;

  await seedDemoData(db);
  return true;
}
