import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/meta_keys.dart';
import 'new_id.dart';

/// This installation's identity (SYNC_PLAN.md, Phase 1, step 10).
///
/// One id per install, made the first time the database is opened and kept
/// for as long as the database lives. The server will use it to know which
/// device sent a change, and settings will use it to list or remove a lost
/// device. It lives in `meta`, which never syncs, and it survives a demo reset.
class DeviceRepository {
  const DeviceRepository(this._db);

  final AppDatabase _db;

  /// The device id, created on first use.
  ///
  /// Insert-or-ignore then read, in one transaction: two callers racing on a
  /// fresh install both end up with the one id that was written first.
  Future<String> deviceId() {
    return _db.transaction(() async {
      await _db
          .into(_db.meta)
          .insert(
            MetaCompanion.insert(key: MetaKeys.deviceId, value: newId()),
            mode: InsertMode.insertOrIgnore,
          );
      final row = await (_db.select(
        _db.meta,
      )..where((m) => m.key.equals(MetaKeys.deviceId))).getSingle();
      return row.value;
    });
  }
}
