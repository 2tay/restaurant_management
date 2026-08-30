import '../database/app_database.dart';
import '../database/meta_keys.dart';
import '../seed/demo_seed.dart';

/// Puts the demo back exactly as it shipped.
///
/// Behind *Paramètres → Synchronisation → Réinitialiser la démonstration*. A
/// client demo gets walked several times in one sitting, and the second
/// walkthrough should not start from the first one's leftovers. In Phase 1 the
/// only alternative was a hot restart, which is not something to do in front of
/// anybody; now it is not even that, because the leftovers survive the restart.
class DemoRepository {
  const DemoRepository(this._db);

  final AppDatabase _db;

  /// Wipes every table and writes the dataset again.
  ///
  /// One transaction, so an interrupted reset cannot leave the app with no
  /// establishments — which would look identical to a corrupted install and
  /// would send the next launch through the first-run seed.
  ///
  /// Deliberately re-anchors the dataset to *now* rather than to whenever the
  /// app was first opened. A demo reset in three months should produce a
  /// commande sent three days ago, not one sent three months and three days
  /// ago.
  Future<void> resetDemo() {
    return _db.transaction(() async {
      await clearAllData(_db);
      await seedDemoData(_db);
    });
  }

  /// When the dataset in this database was written.
  ///
  /// The sync screen's "last synchronised" line. Nothing synchronises in Phase
  /// 2, and the screen says so — but the moment the local data was last written
  /// wholesale is a real fact about this installation, which is more than the
  /// invented timestamp that line carried before.
  ///
  /// Null on a database that has never been seeded.
  Stream<DateTime?> watchSeededAt() =>
      (_db.select(_db.meta)..where((m) => m.key.equals(MetaKeys.seededAt)))
          .watchSingleOrNull()
          .map((row) => row == null ? null : DateTime.tryParse(row.value));
}
