import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/meta_keys.dart';
import '../images/product_images.dart';
import '../seed/demo_seed.dart';
import 'outbox_repository.dart';

/// What this installation is (SYNC_PLAN.md, Phase 4).
enum DeviceMode {
  /// A fresh install: nothing chosen yet. The app opens on the welcome
  /// screen.
  none,

  /// The demo dataset, fully offline, never synced.
  demo,

  /// Signed in to a restaurant's account. Its data is (or will be) synced.
  account,
}

/// The installation's mode, and the account it belongs to when it has one.
///
/// Stored in `meta` and read before the first frame, so the router knows it
/// synchronously and the app knows its restaurant with no network.
class DeviceAccess {
  const DeviceAccess({
    required this.mode,
    required this.hasLocalData,
    this.accountEmail,
    this.organizationId,
    this.organizationName,
    this.accountRole,
  });

  /// What a test that pumps the app without hydrating sees: the demo, with
  /// its data, exactly as every screen test has always run.
  static const DeviceAccess demo = DeviceAccess(
    mode: DeviceMode.demo,
    hasLocalData: true,
  );

  final DeviceMode mode;

  /// Whether at least one establishment exists locally. An account device
  /// that joined a restaurant has none until the first sync brings them.
  final bool hasLocalData;

  final String? accountEmail;
  final String? organizationId;
  final String? organizationName;

  /// `owner` or `manager`.
  final String? accountRole;

  bool get isAccount => mode == DeviceMode.account;
  bool get isOwnerAccount => isAccount && accountRole == 'owner';
}

/// Reads and writes [DeviceAccess] in `meta`, and wipes the device.
class DeviceAccessRepository {
  const DeviceAccessRepository(this._db);

  final AppDatabase _db;

  Future<DeviceAccess> read() async {
    final meta = {
      for (final row in await _db.select(_db.meta).get()) row.key: row.value,
    };
    final hasData = await _hasLocalData();

    final DeviceMode mode = switch (meta[MetaKeys.deviceMode]) {
      'account' => DeviceMode.account,
      'demo' => DeviceMode.demo,
      // Installs from before Phase 4 hold the demo the first launch seeded.
      _ => hasData ? DeviceMode.demo : DeviceMode.none,
    };

    return DeviceAccess(
      mode: mode,
      hasLocalData: hasData,
      accountEmail: meta[MetaKeys.accountEmail],
      organizationId: meta[MetaKeys.organizationId],
      organizationName: meta[MetaKeys.organizationName],
      accountRole: meta[MetaKeys.accountRole],
    );
  }

  Future<void> writeDemo() => _put({MetaKeys.deviceMode: 'demo'});

  Future<void> writeAccount({
    required String email,
    required String organizationId,
    required String organizationName,
    required String role,
  }) => _put({
    MetaKeys.deviceMode: 'account',
    MetaKeys.accountEmail: email,
    MetaKeys.organizationId: organizationId,
    MetaKeys.organizationName: organizationName,
    MetaKeys.accountRole: role,
  });

  /// Empties the device: every row, the queue of unsent changes, the product
  /// photos, and every `meta` key but the device id. What an account sign-out
  /// does, so a lost or handed-over tablet keeps nothing of the restaurant.
  ///
  /// [deleteEmployeePhotos] removes one employee's photo files; it is passed
  /// in because the photo store lives in a provider.
  Future<void> wipe({
    Future<void> Function(String employeeId)? deleteEmployeePhotos,
  }) async {
    final images =
        await (_db.selectOnly(_db.items)
              ..addColumns([_db.items.imagePath])
              ..where(_db.items.imagePath.isNotNull()))
            .map((row) => row.read(_db.items.imagePath))
            .get();
    final employeeIds =
        await (_db.selectOnly(_db.employees)..addColumns([_db.employees.id]))
            .map((row) => row.read(_db.employees.id)!)
            .get();

    await _db.transaction(() async {
      await clearAllData(_db);
      await OutboxRepository(_db).clear();
      await _db.delete(_db.syncErrors).go();
    });

    // Files after the rows, and never fatal: a photo that cannot be deleted
    // is not worth leaving the device half-wiped.
    for (final name in images) {
      try {
        await ProductImages.delete(name);
      } catch (_) {}
    }
    if (deleteEmployeePhotos != null) {
      for (final id in employeeIds) {
        try {
          await deleteEmployeePhotos(id);
        } catch (_) {}
      }
    }
  }

  Future<bool> _hasLocalData() async =>
      await (_db.select(_db.stores)
            ..where((s) => s.deletedAt.isNull())
            ..limit(1))
          .getSingleOrNull() !=
      null;

  Future<void> _put(Map<String, String> values) => _db.batch((batch) {
    for (final entry in values.entries) {
      batch.insert(
        _db.meta,
        MetaCompanion.insert(key: entry.key, value: entry.value),
        mode: InsertMode.insertOrReplace,
      );
    }
  });
}
