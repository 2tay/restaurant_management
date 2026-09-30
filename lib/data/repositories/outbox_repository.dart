import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// The queue of changes waiting to be sent (SYNC_PLAN.md, Phase 2).
///
/// The triggers in `outbox_triggers.drift` fill it; the sync service
/// (Phase 5) empties it as the server answers, through [removeIfUnchanged],
/// [reject] and [recordFailure]. [clear] exists for the demo reset and the
/// account sign-out.
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

  /// Empties the queue. The demo reset and the account sign-out call this.
  Future<int> clear() => _db.delete(_db.outbox).go();

  /// Removes an entry the server accepted, **unless the row changed while it
  /// was being sent**. A change during the send updated the entry in place
  /// (same id, new payload and time); that newer version has not reached the
  /// server, so it stays queued. Returns whether the entry was removed.
  Future<bool> removeIfUnchanged(OutboxRow sent) async {
    final removed =
        await (_db.delete(_db.outbox)..where(
              (o) =>
                  o.id.equals(sent.id) &
                  o.queuedAt.equals(sent.queuedAt) &
                  o.payload.equals(sent.payload),
            ))
            .go();
    return removed > 0;
  }

  /// Moves an entry the server refused to `sync_errors`, with the server's
  /// reason, and out of the queue so it no longer blocks it. A version changed
  /// during the send stays queued, and will get its own answer.
  Future<void> reject(
    OutboxRow sent, {
    required String reason,
    String? message,
  }) {
    return _db.transaction(() async {
      await _db
          .into(_db.syncErrors)
          .insert(
            SyncErrorsCompanion.insert(
              changedTable: sent.changedTable,
              rowKey: sent.rowKey,
              storeId: sent.storeId,
              payload: sent.payload,
              reason: reason,
              message: Value(message),
              rejectedAt: DateTime.now().toUtc(),
            ),
          );
      await removeIfUnchanged(sent);
    });
  }

  /// Counts one more failed attempt on each entry, with why.
  Future<void> recordFailure(Iterable<OutboxRow> sent, String error) async {
    final ids = [for (final entry in sent) entry.id];
    if (ids.isEmpty) return;
    await _db.customUpdate(
      'UPDATE outbox SET attempts = attempts + 1, last_error = ? '
      'WHERE id IN (${List.filled(ids.length, '?').join(', ')})',
      variables: [
        Variable<String>(error),
        for (final id in ids) Variable<int>(id),
      ],
      updates: {_db.outbox},
    );
  }

  (JoinedSelectStatement<$OutboxTable, OutboxRow>, int Function(TypedResult))
  _countQuery() {
    final count = _db.outbox.id.count();
    final query = _db.selectOnly(_db.outbox)..addColumns([count]);
    return (query, (TypedResult row) => row.read(count) ?? 0);
  }
}
