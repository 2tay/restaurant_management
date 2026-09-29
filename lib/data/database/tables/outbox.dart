import 'package:drift/drift.dart';

/// Changes waiting to be sent to the server (SYNC_PLAN.md, Phase 2).
///
/// Written only by the `*_outbox_insert` / `*_outbox_update` triggers in
/// `outbox_triggers.drift`, inside the transaction that made the change, so a
/// change and its queue entry land together or not at all. Nothing in a
/// repository writes here.
///
/// **One entry per row.** A row edited five times offline has one entry, with
/// the row as it is now: the triggers upsert on ([changedTable], [rowKey]). The
/// upsert keeps the entry's [id], the position of the row's *first* pending
/// change, so a parent created before its children is still sent before them.
///
/// There is no "delete" entry. Synced rows are never deleted, only marked
/// (`deleted_at`), and that mark travels in [payload] like any other column.
///
/// Local only: this table is never synced itself.
@DataClassName('OutboxRow')
@TableIndex(
  name: 'outbox_row',
  columns: {#changedTable, #rowKey},
  unique: true,
)
class Outbox extends Table {
  /// Send order. Auto-increment, so it follows the order changes happened in.
  IntColumn get id => integer().autoIncrement()();

  /// The SQL name of the changed table, as in `SyncTables.synced`.
  TextColumn get changedTable => text()();

  /// The changed row's id. `busy_dates` has no single id, so its key is
  /// `store_id|day`.
  TextColumn get rowKey => text()();

  /// The row's establishment, which is what the server checks access
  /// against. For a `stores` row, its own id.
  TextColumn get storeId => text()();

  /// The whole row as JSON, as it is now, minus the figures every device
  /// recomputes for itself (`items.quantity`, `items.average_cost`).
  TextColumn get payload => text()();

  /// When the row last changed while pending, in UTC, from the same clock
  /// view as the `updated_at` stamps.
  DateTimeColumn get queuedAt => dateTime()();

  /// Failed sends so far, and why the last one failed (Phase 5).
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
}
