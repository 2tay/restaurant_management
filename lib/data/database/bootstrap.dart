import '../repositories/device_repository.dart';
import '../seed/demo_seed.dart';
import 'app_database.dart';

/// Opens the app's database.
///
/// Called once from `main()`, before the first frame. The returned instance is
/// handed to `ProviderScope` as the override for `databaseProvider`, which is
/// the only way anything else gets hold of it.
///
/// It no longer seeds the demo on a first launch (SYNC_PLAN.md, Phase 4): a
/// fresh install opens on the welcome screen, where "Essayer la démo" seeds it
/// ([seedIfEmpty]) and signing in to an account starts from that account's
/// data instead.
Future<AppDatabase> openAppDatabase() async {
  final AppDatabase db = AppDatabase();
  // Made now rather than on first use, so the id exists from the install's
  // very first launch, before anything could need to report it.
  await DeviceRepository(db).deviceId();
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
