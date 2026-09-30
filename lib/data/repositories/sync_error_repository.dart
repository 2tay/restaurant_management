import 'dart:convert';

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
    this.details = const {},
  });

  final int id;

  /// The SQL name of the table the change was for.
  final String table;

  /// The server's reason code: `deleted`, `already_paid`, …
  final String reason;
  final String? message;
  final DateTime rejectedAt;

  /// For a conflict settled on receipt (`resolved_*`): what the sentence
  /// names, like the employee and the day of a merged clock-in.
  final Map<String, Object?> details;

  /// A conflict sync settled by itself, as opposed to a change refused.
  bool get isResolution => reason.startsWith('resolved_');
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
          details: row.reason.startsWith('resolved_')
              ? _details(row.payload)
              : const {},
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

  static Map<String, Object?> _details(String payload) {
    try {
      final decoded = jsonDecode(payload);
      return decoded is Map<String, Object?> ? decoded : const {};
    } on FormatException {
      return const {};
    }
  }

  Future<int> dismiss(int id) =>
      (_db.delete(_db.syncErrors)..where((e) => e.id.equals(id))).go();

  Future<int> clear() => _db.delete(_db.syncErrors).go();
}
