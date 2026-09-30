import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// A change the server refused, as the sync page shows it.
class RejectedChange {
  const RejectedChange({
    required this.id,
    required this.table,
    required this.reason,
    required this.rejectedAt,
    this.message,
  });

  final int id;

  /// The SQL name of the table the change was for.
  final String table;

  /// The server's reason code: `deleted`, `already_paid`, …
  final String reason;
  final String? message;
  final DateTime rejectedAt;
}

/// The changes the server refused (SYNC_PLAN.md, Phase 5). Filled by
/// `OutboxRepository.reject`; the sync page lists them and a person dismisses
/// each one once read.
class SyncErrorRepository {
  const SyncErrorRepository(this._db);

  final AppDatabase _db;

  /// Newest first, for the sync page.
  Stream<List<RejectedChange>> watchRejected() => watchAll().map(
    (rows) => [
      for (final row in rows)
        RejectedChange(
          id: row.id,
          table: row.changedTable,
          reason: row.reason,
          message: row.message,
          rejectedAt: row.rejectedAt.toLocal(),
        ),
    ],
  );

  /// Newest first.
  Stream<List<SyncErrorRow>> watchAll() =>
      (_db.select(_db.syncErrors)..orderBy([
            (e) =>
                OrderingTerm(expression: e.rejectedAt, mode: OrderingMode.desc),
            (e) => OrderingTerm(expression: e.id, mode: OrderingMode.desc),
          ]))
          .watch();

  Future<List<SyncErrorRow>> all() => (_db.select(
    _db.syncErrors,
  )..orderBy([(e) => OrderingTerm(expression: e.id)])).get();

  Future<int> dismiss(int id) =>
      (_db.delete(_db.syncErrors)..where((e) => e.id.equals(id))).go();

  Future<int> clear() => _db.delete(_db.syncErrors).go();
}
