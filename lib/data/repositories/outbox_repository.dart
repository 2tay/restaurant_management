import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// The queue of changes waiting to be sent (SYNC_PLAN.md, Phase 2).
///
/// Read-only for the app: the triggers in `outbox_triggers.drift` fill it,
/// and the sync service (Phase 5) will empty it as the server accepts each
/// change. [clear] exists for the demo reset, which puts the demo back as it
/// shipped, with nothing waiting.
class OutboxRepository {
  const OutboxRepository(this._db);

  final AppDatabase _db;

  /// How many rows have a change waiting. What the offline banner shows.
  Stream<int> watchPendingCount() {
    final (query, read) = _countQuery();
    return query.watchSingle().map(read);
  }

  Future<int> pendingCount() {
    final (query, read) = _countQuery();
    return query.getSingle().then(read);
  }

  /// The waiting changes in send order: the order each row first changed.
  Future<List<OutboxRow>> pending({int? limit}) {
    final query = _db.select(_db.outbox)
      ..orderBy([(o) => OrderingTerm(expression: o.id)]);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  /// Empties the queue. Only the demo reset calls this.
  Future<int> clear() => _db.delete(_db.outbox).go();

  (JoinedSelectStatement<$OutboxTable, OutboxRow>, int Function(TypedResult))
  _countQuery() {
    final count = _db.outbox.id.count();
    final query = _db.selectOnly(_db.outbox)..addColumns([count]);
    return (query, (TypedResult row) => row.read(count) ?? 0);
  }
}
