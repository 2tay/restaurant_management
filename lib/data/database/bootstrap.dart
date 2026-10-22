import '../repositories/device_repository.dart';
import 'app_database.dart';

/// Opens the app's database.
///
/// Called once from `main()`, before the first frame. The returned instance is
/// handed to `ProviderScope` as the override for `databaseProvider`, which is
/// the only way anything else gets hold of it.
///
/// A fresh install is empty and opens on the welcome screen; its data comes
/// from the restaurant's account (SYNC_PLAN.md, Phase 4).
Future<AppDatabase> openAppDatabase() async {
  final AppDatabase db = AppDatabase();
  // Made now rather than on first use, so the id exists from the install's
  // very first launch, before anything could need to report it.
  await DeviceRepository(db).deviceId();
  return db;
}
