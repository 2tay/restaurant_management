import 'package:drift/drift.dart';

/// Changes the server refused (SYNC_PLAN.md, Phase 5).
///
/// When `push_changes` rejects an outbox entry — the row was deleted on the
/// server, a pay period is already paid, a commande's status cannot move back
/// — sending it again would only be refused again, and it would block the
/// queue behind it. So the entry moves here, with the server's reason, and
/// leaves the outbox. The sync page lists these in words, and a person
/// dismisses them once read.
///
/// Local only: never synced.
@DataClassName('SyncErrorRow')
class SyncErrors extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The outbox entry, as it was sent.
  TextColumn get changedTable => text()();
  TextColumn get rowKey => text()();
  TextColumn get storeId => text()();
  TextColumn get payload => text()();

  /// The server's reason code (`deleted`, `already_paid`, …; see
  /// `supabase/migrations/…_push_changes.sql`), and its message for `invalid`.
  TextColumn get reason => text()();
  TextColumn get message => text().nullable()();

  DateTimeColumn get rejectedAt => dateTime()();
}
