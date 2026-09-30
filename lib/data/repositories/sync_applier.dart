import 'package:drift/drift.dart';

import '../../services/auth_service.dart';
import '../database/app_database.dart';
import '../database/sync_tables.dart';
import 'stock_ledger.dart';
import 'sync_quiet.dart';

/// Writes rows received from the server into the local database
/// (SYNC_PLAN.md, Phase 6).
///
/// One page at a time, in one transaction:
///
/// - **quiet** ([SyncQuiet]): a received row is not a change to send back;
/// - **foreign keys checked at the end of the page**: a child can arrive
///   before a row it points to (an attendance linked to a pay period);
/// - **a row with an unsent local change is skipped**: the local change is
///   newer, it goes out next, and the server decides;
/// - **the article's stock figures are never overwritten**: the server does
///   not hold them, and [StockLedger] recomputes them after the page;
/// - **the store's cursor is saved with the rows**, so a crash can neither
///   skip nor repeat a change.
///
/// A row the local database refuses for another reason (a unique rule that
/// only the server does not have, like two tablets clocking the same employee
/// in on the same day) is kept out, logged in `sync_errors` as
/// `receive_conflict`, and the page goes on.
class SyncApplier {
  SyncApplier(this._db);

  final AppDatabase _db;

  /// `meta` key of a store's cursor.
  static String cursorKey(String storeId) => 'syncCursor:$storeId';

  /// Columns the server never sends, and a local insert must still fill.
  static const Map<String, Map<String, Object?>> _localOnly = {
    'items': {'quantity': 0.0, 'average_cost': null},
  };

  Future<int> cursorOf(String storeId) async {
    final row = await (_db.select(
      _db.meta,
    )..where((m) => m.key.equals(cursorKey(storeId)))).getSingleOrNull();
    return int.tryParse(row?.value ?? '') ?? 0;
  }

  /// Applies [page] for [storeId]. Returns how many rows were written.
  Future<int> apply(String storeId, PullPage page) async {
    final rebuild = <String>{};
    var written = 0;

    await SyncQuiet.run(_db, () async {
      await _db.customStatement('PRAGMA defer_foreign_keys = ON');

      for (final change in page.changes) {
        final table = _tables[change.table];
        if (table == null || !SyncTables.synced.contains(change.table)) {
          continue;
        }
        final key = _rowKey(change.table, change.row);
        if (key == null || await _hasPendingChange(change.table, key)) {
          continue;
        }

        try {
          // A savepoint per row: a row refused locally rolls back alone.
          await _db.transaction(() => _upsert(table, change.row));
          written++;
          if (change.table == 'stock_movements') {
            rebuild.add(change.row['item_id'] as String);
          } else if (change.table == 'items') {
            rebuild.add(change.row['id'] as String);
          }
        } catch (error) {
          await _db
              .into(_db.syncErrors)
              .insert(
                SyncErrorsCompanion.insert(
                  changedTable: change.table,
                  rowKey: key,
                  storeId: storeId,
                  payload: change.row.toString(),
                  reason: 'receive_conflict',
                  message: Value(error.toString()),
                  rejectedAt: DateTime.now().toUtc(),
                ),
              );
        }
      }

      await _db
          .into(_db.meta)
          .insertOnConflictUpdate(
            MetaCompanion.insert(
              key: cursorKey(storeId),
              value: '${page.nextAfter}',
            ),
          );
    });

    if (rebuild.isNotEmpty) await StockLedger(_db).rebuildItems(rebuild);
    return written;
  }

  late final Map<String, TableInfo<Table, dynamic>> _tables = {
    for (final table in _db.allTables) table.actualTableName: table,
  };

  static String? _rowKey(String table, Map<String, dynamic> row) =>
      table == 'busy_dates'
      ? (row['store_id'] == null || row['day'] == null
            ? null
            : '${row['store_id']}|${row['day']}')
      : row['id'] as String?;

  Future<bool> _hasPendingChange(String table, String key) async =>
      await (_db.select(_db.outbox)..where(
            (o) => o.changedTable.equals(table) & o.rowKey.equals(key),
          ))
          .getSingleOrNull() !=
      null;

  Future<void> _upsert(TableInfo<Table, dynamic> table, Map<String, dynamic> row) {
    final name = table.actualTableName;
    final localOnly = _localOnly[name] ?? const {};
    final keys = {for (final column in table.primaryKey) column.name};

    final columns = <String>[];
    final values = <Object?>[];
    for (final column in table.$columns) {
      final String columnName = column.name;
      if (row.containsKey(columnName)) {
        columns.add(columnName);
        values.add(_convert(name, column, row[columnName]));
      } else if (localOnly.containsKey(columnName)) {
        columns.add(columnName);
        values.add(_convert(name, column, localOnly[columnName]));
      }
    }

    final updates = [
      for (final column in columns)
        if (!keys.contains(column) && !localOnly.containsKey(column))
          '"$column" = excluded."$column"',
    ];

    return _db.customStatement(
      'INSERT INTO "$name" (${columns.map((c) => '"$c"').join(', ')}) '
      'VALUES (${List.filled(columns.length, '?').join(', ')}) '
      'ON CONFLICT (${keys.map((k) => '"$k"').join(', ')}) '
      '${updates.isEmpty ? 'DO NOTHING' : 'DO UPDATE SET ${updates.join(', ')}'}',
      [
        // As drift would bind them: booleans as 0 / 1, dates in the app's
        // text format (`store_date_time_values_as_text`).
        for (final value in values)
          value == null ? null : _db.typeMapping.mapToSqlVariable(value),
      ],
    );
  }

  /// A server JSON value, as the local column stores it.
  ///
  /// Dates come back as `timestamptz` text (`…+00:00`). They are stored the
  /// way the app writes them: local time with its offset, so a date anchored
  /// to a day (an attendance at midnight) stays on that day. The sync stamp
  /// `updated_at` stays UTC, like every stamp the triggers write
  /// (`tables/sync_columns.dart`).
  static Object? _convert(
    String table,
    GeneratedColumn<Object> column,
    Object? value,
  ) {
    if (value == null) return null;
    switch (column.type) {
      case DriftSqlType.bool:
        return value is bool
            ? value
            : (value is num ? value != 0 : value == 'true');
      case DriftSqlType.dateTime:
        final parsed = DateTime.parse(value as String);
        final isStamp = column.name == 'updated_at' && table != 'items';
        return isStamp ? parsed.toUtc() : parsed.toLocal();
      case DriftSqlType.int:
        return (value as num).toInt();
      case DriftSqlType.double:
        return (value as num).toDouble();
      default:
        return value.toString();
    }
  }
}
