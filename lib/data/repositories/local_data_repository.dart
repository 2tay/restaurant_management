import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import '../database/meta_keys.dart';
import '../database/sync_tables.dart';
import '../seed/dataset/stores.dart';
import 'sync_quiet.dart';

/// What a device holds before it first connects to an account.
enum LocalDataKind {
  /// Nothing: a fresh install.
  none,

  /// Only the demo restaurant.
  demo,

  /// Establishments the restaurant created itself.
  own,
}

/// The data already on a device when it first connects to an account
/// (SYNC_PLAN.md, Phase 9).
///
/// A restaurant may have used the app offline before accounts existed. Its
/// data must not be wiped like the demo: it is either sent to the new account
/// ([queueEverything]), or saved to a backup file ([exportBackup]) when the
/// account already has data of its own.
class LocalDataRepository {
  const LocalDataRepository(this._db);

  final AppDatabase _db;

  /// The demo's establishment ids. Every row of the demo belongs to one.
  static final Set<String> demoStoreIds = {
    for (final store in mockStores) store.id,
  };

  /// Whether the device holds nothing, only the demo, or its own data.
  ///
  /// The demo is known by its establishments: a live establishment that is
  /// not one of [demoStoreIds] was created by the restaurant. Data typed into
  /// the demo establishments themselves still counts as the demo; the screens
  /// say so before anything is erased.
  Future<LocalDataKind> kind() async {
    final stores =
        await (_db.selectOnly(_db.stores)
              ..addColumns([_db.stores.id])
              ..where(_db.stores.deletedAt.isNull()))
            .map((row) => row.read(_db.stores.id)!)
            .get();
    if (stores.isEmpty) return LocalDataKind.none;
    return stores.every(demoStoreIds.contains)
        ? LocalDataKind.demo
        : LocalDataKind.own;
  }

  /// The names of the restaurant's own establishments, for the screen that
  /// asks what to do with them.
  Future<List<String>> ownStoreNames() async {
    final rows =
        await (_db.select(_db.stores)
              ..where((s) => s.deletedAt.isNull() & s.id.isNotIn(demoStoreIds)))
            .get();
    return [for (final row in rows) row.name];
  }

  /// Removes the demo establishments and everything in them, keeping the
  /// restaurant's own. Real deletes, quietly: the demo was never meant for a
  /// server. Children first, so no foreign key is left dangling.
  Future<void> removeDemo() {
    return SyncQuiet.run(_db, () async {
      final ids = demoStoreIds.toList();
      final marks = List.filled(ids.length, '?').join(', ');
      final args = [for (final id in ids) Variable<String>(id)];
      for (final table in SyncTables.synced.toList().reversed) {
        final column = table == 'stores' ? 'id' : 'store_id';
        await _db.customUpdate(
          'DELETE FROM $table WHERE $column IN ($marks)',
          variables: args,
          updates: {_db.allTables.firstWhere((t) => t.actualTableName == table)},
          updateKind: UpdateKind.delete,
        );
      }
      await (_db.delete(
        _db.meta,
      )..where((m) => m.key.equals(MetaKeys.seededAt))).go();
      await _db.delete(_db.outbox).go();
      await _db.delete(_db.photoUploads).go();
    });
  }

  /// Queues every row and every photo on the device for the server: what
  /// "Envoyer mes données" does. Rows go in the order of
  /// [SyncTables.synced], parents first, so the server receives an
  /// establishment before its articles and an article before its movements.
  ///
  /// Each row is "touched" (`updated_at` set to itself): the `*_touch`
  /// trigger stamps it and the outbox trigger queues it, exactly as a real
  /// change would.
  Future<int> queueEverything() async {
    await _db.transaction(() async {
      for (final table in SyncTables.synced) {
        await _db.customStatement(
          'UPDATE $table SET updated_at = updated_at',
        );
      }
      await _db.customStatement(r'''
        INSERT OR IGNORE INTO photo_uploads
          (kind, store_id, file_name, operation, queued_at)
        SELECT 'items', store_id, image_path, 'upload',
               (SELECT now FROM sync_clock)
          FROM items
         WHERE image_path IS NOT NULL AND deleted_at IS NULL
           AND instr(image_path, '/') = 0 AND instr(image_path, '\') = 0
      ''');
      await _db.customStatement(r'''
        INSERT OR IGNORE INTO photo_uploads
          (kind, store_id, file_name, operation, queued_at)
        SELECT 'employees', store_id, photo_asset, 'upload',
               (SELECT now FROM sync_clock)
          FROM employees
         WHERE photo_asset IS NOT NULL AND deleted_at IS NULL
           AND instr(photo_asset, '/') = 0 AND instr(photo_asset, '\') = 0
      ''');
    });
    final count = await (_db.selectOnly(
      _db.outbox,
    )..addColumns([_db.outbox.id.count()])).map((r) => r.read(_db.outbox.id.count())).getSingle();
    return count ?? 0;
  }

  /// Writes every synced table to a JSON file in [directory], before the
  /// device's data is replaced by the account's. Returns the file.
  ///
  /// A safety net, not a sync format: plain rows, table by table, readable
  /// by anyone who needs to recover a figure.
  Future<File> exportBackup(Directory directory) async {
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in SyncTables.synced) {
      final rows = await _db.customSelect('SELECT * FROM $table').get();
      tables[table] = [for (final row in rows) row.data];
    }
    final at = clock.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${at.year}${two(at.month)}${two(at.day)}-${two(at.hour)}${two(at.minute)}${two(at.second)}';
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, 'sauvegarde-$stamp.json'));
    await file.writeAsString(
      const JsonEncoder.withIndent(' ').convert({
        'createdAt': at.toIso8601String(),
        'tables': tables,
      }),
    );
    return file;
  }
}
