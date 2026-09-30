import '../database/app_database.dart';
import '../database/meta_keys.dart';

/// Runs writes that must not be queued for sending (SYNC_PLAN.md, Phase 2).
///
/// Three kinds of write change synced tables without being changes to send:
///
/// - the demo seed and the demo reset, which put the demo back as it shipped;
/// - a stock rebuild, which recomputes figures every device works out for
///   itself (`StockLedger`);
/// - later, rows received from the server (Phase 6), which must not be sent
///   straight back.
///
/// While [run] is running, `meta` holds [MetaKeys.syncQuiet] and the outbox
/// triggers stay silent. The key is written and removed inside the same
/// transaction as the writes, so if anything fails the rollback removes it
/// too: a crash cannot leave the queue switched off.
///
/// Nests: an inner [run] inside an outer one leaves the key for the outer one
/// to remove.
abstract final class SyncQuiet {
  static Future<T> run<T>(AppDatabase db, Future<T> Function() body) {
    return db.transaction(() async {
      final already = await isOn(db);
      if (!already) {
        await db
            .into(db.meta)
            .insertOnConflictUpdate(
              MetaCompanion.insert(key: MetaKeys.syncQuiet, value: '1'),
            );
      }
      try {
        return await body();
      } finally {
        if (!already) {
          await (db.delete(
            db.meta,
          )..where((m) => m.key.equals(MetaKeys.syncQuiet))).go();
        }
      }
    });
  }

  /// Runs [body] with queueing back on, inside a quiet write.
  ///
  /// For the one kind of change a quiet write makes that other devices must
  /// hear about: a conflict settled on receipt (SYNC_PLAN.md, Phase 7). The
  /// row marked deleted, the session moved to the kept day — every device has
  /// to end the same, so these go out like any change. Must run inside the
  /// transaction of the surrounding [run].
  static Future<T> loud<T>(AppDatabase db, Future<T> Function() body) async {
    final wasOn = await isOn(db);
    if (wasOn) {
      await (db.delete(
        db.meta,
      )..where((m) => m.key.equals(MetaKeys.syncQuiet))).go();
    }
    try {
      return await body();
    } finally {
      if (wasOn) {
        await db
            .into(db.meta)
            .insertOnConflictUpdate(
              MetaCompanion.insert(key: MetaKeys.syncQuiet, value: '1'),
            );
      }
    }
  }

  /// Whether queueing is switched off right now.
  static Future<bool> isOn(AppDatabase db) async =>
      await (db.select(
        db.meta,
      )..where((m) => m.key.equals(MetaKeys.syncQuiet))).getSingleOrNull() !=
      null;
}
