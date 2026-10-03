import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

import '../../services/auth_service.dart';
import '../database/app_database.dart';
import '../database/sync_tables.dart';
import 'account_repository.dart';
import 'credential_repository.dart';
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
/// ## Conflicts settled on receipt (Phase 7)
///
/// The device has four "one per" rules the server does not: one live day
/// per employee and date, one live journée de service per store and date, one
/// live link per article and supplier, one live credential per employee. Two tablets working offline can both create "the"
/// row. When a received row meets a live local one for the same key, the
/// same rule runs on every device, so every device ends the same:
///
/// - **two days for one employee**: the day linked to a pay period is kept,
///   otherwise the one with the smaller id. The other day is marked deleted
///   and its sessions move to the kept day, untouched. Overlapping hours are
///   flagged for a manager, never trimmed (`AttendanceAnomaly.doublePointage`);
/// - **two journées for one store and date** (rule P5): the one with the
///   smaller id is kept, the other marked deleted. No pointage moves —
///   attendance rows join a journée by its date, not its id. A close is never
///   lost: when only the dropped journée was closed, the kept one takes its
///   close;
/// - **two supplier links, two credentials**: the most recently changed one
///   is kept (the larger id on a tie), the other is marked deleted.
///
/// Those resolutions are real changes: they are written with the queue on
/// ([SyncQuiet.loud]) and sent like any other, and logged in `sync_errors`
/// as `resolved_*` so the sync page can say what happened. One that a manager
/// must check is also a signalement ([AccountRepository.signal]), the same
/// on every tablet.
///
/// A received notification never makes a signalement unread again: a "read"
/// stamp this tablet holds and the incoming row lacks is kept.
///
/// A row the local database still refuses is kept out, logged as
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
          await _db.transaction(
            () => _applyRow(table, change.table, change.row, storeId),
          );
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
                  payload: jsonEncode(change.row),
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

  // ---------------------------------------------------------------------------
  // Conflicts settled on receipt (Phase 7)
  // ---------------------------------------------------------------------------

  /// Offset added to the position of a session moved into another day, so it
  /// never takes the position of one of that day's own sessions, including
  /// ones that have not arrived yet. The same on every device.
  static const int movedSessionOffset = 1000;

  Future<void> _applyRow(
    TableInfo<Table, dynamic> table,
    String name,
    Map<String, dynamic> row,
    String storeId,
  ) async {
    final live = row['deleted_at'] == null;
    switch (name) {
      case 'attendances' when live:
        return _applyAttendance(table, row, storeId);
      case 'attendance_sessions':
        return _applySession(table, row);
      case 'business_days' when live:
        return _applyBusinessDay(table, row, storeId);
      case 'notifications':
        return _applyNotification(table, row);
      case 'supplier_prices' when live:
        return _applyKeepRecent(
          table,
          row,
          storeId,
          existing: () =>
              (_db.select(_db.supplierPrices)..where(
                    (p) =>
                        p.itemId.equals(row['item_id'] as String) &
                        p.supplierId.equals(row['supplier_id'] as String) &
                        p.deletedAt.isNull() &
                        p.id.equals(row['id'] as String).not(),
                  ))
                  .map((p) => (id: p.id, updatedAt: p.updatedAt))
                  .getSingleOrNull(),
          markDeleted: (id, at) =>
              (_db.update(_db.supplierPrices)..where((p) => p.id.equals(id)))
                  .write(SupplierPricesCompanion(deletedAt: Value(at))),
          resolution: 'resolved_duplicate_link',
          afterwards: () => _ensureDefaultPrice(row['item_id'] as String),
        );
      case 'employee_credentials' when live:
        // A new password reaching this tablet clears the lockout this
        // tablet keeps for it, as a password set here does (rule C3).
        final employeeId = row['employee_id'] as String;
        final before = await (_db.select(_db.employeeCredentials)..where(
              (c) => c.employeeId.equals(employeeId) & c.deletedAt.isNull(),
            ))
            .getSingleOrNull();
        if (before != null && before.passwordHash != row['password_hash']) {
          await CredentialRepository(_db).resetAttempts(employeeId);
        }
        return _applyKeepRecent(
          table,
          row,
          storeId,
          existing: () =>
              (_db.select(_db.employeeCredentials)..where(
                    (c) =>
                        c.employeeId.equals(row['employee_id'] as String) &
                        c.deletedAt.isNull() &
                        c.id.equals(row['id'] as String).not(),
                  ))
                  .map((c) => (id: c.id, updatedAt: c.updatedAt))
                  .getSingleOrNull(),
          markDeleted: (id, at) =>
              (_db.update(_db.employeeCredentials)
                    ..where((c) => c.id.equals(id)))
                  .write(EmployeeCredentialsCompanion(deletedAt: Value(at))),
          resolution: null,
        );
      default:
        return _upsert(table, row);
    }
  }

  /// Two days for one employee and date.
  Future<void> _applyAttendance(
    TableInfo<Table, dynamic> table,
    Map<String, dynamic> row,
    String storeId,
  ) async {
    final incomingId = row['id'] as String;
    final date =
        _convert('attendances', _db.attendances.date, row['date'])! as DateTime;
    final local =
        await (_db.select(_db.attendances)..where(
              (a) =>
                  a.employeeId.equals(row['employee_id'] as String) &
                  a.date.equals(date) &
                  a.deletedAt.isNull() &
                  a.id.equals(incomingId).not(),
            ))
            .getSingleOrNull();
    if (local == null) return _upsert(table, row);

    final incomingPaid = row['payroll_period_id'] != null;
    final localPaid = local.payrollPeriodId != null;
    final keepIncoming = incomingPaid != localPaid
        ? incomingPaid
        : incomingId.compareTo(local.id) < 0;
    final now = clock.now();

    if (keepIncoming) {
      await SyncQuiet.loud(_db, () async {
        await (_db.update(_db.attendances)..where((a) => a.id.equals(local.id)))
            .write(AttendancesCompanion(deletedAt: Value(now)));
      });
      await _upsert(table, row);
      await SyncQuiet.loud(_db, () => _moveSessions(local.id, incomingId));
    } else {
      await SyncQuiet.loud(_db, () async {
        await _upsert(table, {
          ...row,
          'deleted_at': now.toUtc().toIso8601String(),
        });
        await _moveSessions(incomingId, local.id);
      });
    }

    final employeeId = row['employee_id'] as String;
    final name = await _employeeName(employeeId);
    final keptId = keepIncoming ? incomingId : local.id;
    await _logResolution(
      'resolved_double_clock_in',
      table: 'attendances',
      rowKey: keptId,
      storeId: storeId,
      details: {'employee': name, 'date': date.toIso8601String()},
    );
    // Rule P1: « signalé double pointage ».
    await SyncQuiet.loud(
      _db,
      () => AccountRepository(_db).signal(
        storeId: row['store_id'] as String,
        key: 'double_clock_in:$keptId',
        title: 'Double pointage : $name',
        body:
            'Le ${_numericDate(date)}, deux arrivées ont été pointées sur deux '
            'tablettes. Elles sont regroupées dans une seule journée : '
            'vérifiez les heures dans l\'historique.',
        employeeId: employeeId,
        at: now,
      ),
    );
  }

  /// dd/MM/yyyy, by hand: the text must not depend on locale data being
  /// loaded, and must read the same on every tablet.
  static String _numericDate(DateTime day) =>
      '${day.day.toString().padLeft(2, '0')}/'
      '${day.month.toString().padLeft(2, '0')}/${day.year}';

  /// A received notification. The read stamps of a signalement only ever
  /// move forward: one this tablet holds stays, the earlier of two wins.
  Future<void> _applyNotification(
    TableInfo<Table, dynamic> table,
    Map<String, dynamic> row,
  ) async {
    final local = await (_db.select(
      _db.notifications,
    )..where((n) => n.id.equals(row['id'] as String))).getSingleOrNull();
    if (local == null) return _upsert(table, row);

    String? earliest(DateTime? mine, Object? theirs) {
      final incoming = theirs == null
          ? null
          : DateTime.parse(theirs as String);
      final kept = switch ((mine, incoming)) {
        (null, final t) => t,
        (final m?, null) => m,
        (final m?, final t?) => t.isBefore(m) ? t : m,
      };
      return kept?.toUtc().toIso8601String();
    }

    return _upsert(table, {
      ...row,
      'is_read': local.isRead || (row['is_read'] == true),
      'read_by_manager_at': earliest(
        local.readByManagerAt,
        row['read_by_manager_at'],
      ),
      'read_by_owner_at': earliest(local.readByOwnerAt, row['read_by_owner_at']),
    });
  }

  /// Two journées for one store and date (rule P5).
  Future<void> _applyBusinessDay(
    TableInfo<Table, dynamic> table,
    Map<String, dynamic> row,
    String storeId,
  ) async {
    final incomingId = row['id'] as String;
    final date =
        _convert('business_days', _db.businessDays.date, row['date'])!
            as DateTime;
    final local =
        await (_db.select(_db.businessDays)..where(
              (d) =>
                  d.storeId.equals(row['store_id'] as String) &
                  d.date.equals(date) &
                  d.deletedAt.isNull() &
                  d.id.equals(incomingId).not(),
            ))
            .getSingleOrNull();
    if (local == null) return _upsert(table, row);

    final keepIncoming = incomingId.compareTo(local.id) < 0;
    final incomingClosedAt = _convert(
      'business_days',
      _db.businessDays.closedAt,
      row['closed_at'],
    ) as DateTime?;
    final now = clock.now();

    Future<void> close(String id, DateTime at, String? by) =>
        (_db.update(_db.businessDays)..where((d) => d.id.equals(id))).write(
          BusinessDaysCompanion(closedAt: Value(at), closedByEmployeeId: Value(by)),
        );

    if (keepIncoming) {
      await SyncQuiet.loud(_db, () async {
        await (_db.update(_db.businessDays)..where((d) => d.id.equals(local.id)))
            .write(BusinessDaysCompanion(deletedAt: Value(now)));
      });
      await _upsert(table, row);
      if (incomingClosedAt == null && local.closedAt != null) {
        await SyncQuiet.loud(
          _db,
          () => close(incomingId, local.closedAt!, local.closedByEmployeeId),
        );
      }
    } else {
      await SyncQuiet.loud(_db, () async {
        await _upsert(table, {
          ...row,
          'deleted_at': now.toUtc().toIso8601String(),
        });
        if (local.closedAt == null && incomingClosedAt != null) {
          await close(
            local.id,
            incomingClosedAt,
            row['closed_by_employee_id'] as String?,
          );
        }
      });
    }

    await _logResolution(
      'resolved_double_business_day',
      table: 'business_days',
      rowKey: keepIncoming ? incomingId : local.id,
      storeId: storeId,
      details: {'date': date.toIso8601String()},
    );
  }

  /// A session of a day that was merged away goes to the kept day.
  Future<void> _applySession(
    TableInfo<Table, dynamic> table,
    Map<String, dynamic> row,
  ) async {
    final day =
        await (_db.select(_db.attendances)
              ..where((a) => a.id.equals(row['attendance_id'] as String)))
            .getSingleOrNull();
    if (day == null || day.deletedAt == null || row['deleted_at'] != null) {
      return _upsert(table, row);
    }
    final kept =
        await (_db.select(_db.attendances)..where(
              (a) =>
                  a.employeeId.equals(day.employeeId) &
                  a.date.equals(day.date) &
                  a.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (kept == null) return _upsert(table, row);

    final position = (row['position'] as num).toInt();
    await SyncQuiet.loud(
      _db,
      () => _upsert(table, {
        ...row,
        'attendance_id': kept.id,
        'position': position >= movedSessionOffset
            ? position
            : position + movedSessionOffset,
      }),
    );
    await SyncQuiet.loud(_db, () => _refreshDayStatus(kept.id));
  }

  /// Moves every session of day [fromId] to day [toId], and gives the kept
  /// day the status its sessions now imply.
  Future<void> _moveSessions(String fromId, String toId) async {
    final sessions = await (_db.select(
      _db.attendanceSessions,
    )..where((s) => s.attendanceId.equals(fromId))).get();
    for (final session in sessions) {
      await (_db.update(
        _db.attendanceSessions,
      )..where((s) => s.id.equals(session.id))).write(
        AttendanceSessionsCompanion(
          attendanceId: Value(toId),
          position: Value(
            session.position >= movedSessionOffset
                ? session.position
                : session.position + movedSessionOffset,
          ),
        ),
      );
    }
    if (sessions.isNotEmpty) await _refreshDayStatus(toId);
  }

  /// A day with a session still open is being worked (or is on a break);
  /// otherwise it is done.
  Future<void> _refreshDayStatus(String attendanceId) async {
    final sessions =
        await (_db.select(_db.attendanceSessions)..where(
              (s) => s.attendanceId.equals(attendanceId) & s.deletedAt.isNull(),
            ))
            .get();
    final open = sessions.where((s) => s.clockOutAt == null).toList();
    final String status;
    if (open.isEmpty) {
      status = 'done';
    } else {
      final openPause =
          await (_db.select(_db.attendancePauses)..where(
                (p) =>
                    p.sessionId.isIn(open.map((s) => s.id)) &
                    p.endAt.isNull() &
                    p.deletedAt.isNull(),
              ))
              .get();
      status = openPause.isEmpty ? 'working' : 'onBreak';
    }
    await _db.customUpdate(
      'UPDATE attendances SET status = ? WHERE id = ? AND status <> ?',
      variables: [
        Variable<String>(status),
        Variable<String>(attendanceId),
        Variable<String>(status),
      ],
      updates: {_db.attendances},
    );
  }

  /// Two rows for one key where the most recent change wins: supplier links
  /// and credentials.
  Future<void> _applyKeepRecent(
    TableInfo<Table, dynamic> table,
    Map<String, dynamic> row,
    String storeId, {
    required Future<({String id, DateTime updatedAt})?> Function() existing,
    required Future<void> Function(String id, DateTime at) markDeleted,
    required String? resolution,
    Future<void> Function()? afterwards,
  }) async {
    final local = await existing();
    if (local == null) return _upsert(table, row);

    final incomingId = row['id'] as String;
    final incomingAt = DateTime.parse(row['updated_at'] as String);
    final byTime = incomingAt.compareTo(local.updatedAt);
    final keepIncoming = byTime != 0
        ? byTime > 0
        : incomingId.compareTo(local.id) > 0;
    final now = clock.now();

    if (keepIncoming) {
      await SyncQuiet.loud(_db, () => markDeleted(local.id, now));
      await _upsert(table, row);
    } else {
      await SyncQuiet.loud(
        _db,
        () => _upsert(table, {
          ...row,
          'deleted_at': now.toUtc().toIso8601String(),
        }),
      );
    }
    if (afterwards != null) await SyncQuiet.loud(_db, afterwards);
    if (resolution != null) {
      await _logResolution(
        resolution,
        table: table.actualTableName,
        rowKey: keepIncoming ? incomingId : local.id,
        storeId: storeId,
        details: const {},
      );
    }
  }

  /// An article keeps a default supplier after one of two links went.
  Future<void> _ensureDefaultPrice(String itemId) async {
    final prices =
        await (_db.select(_db.supplierPrices)
              ..where((p) => p.itemId.equals(itemId) & p.deletedAt.isNull())
              ..orderBy([
                (p) => OrderingTerm(expression: p.pricePerUnit),
                (p) => OrderingTerm(expression: p.id),
              ]))
            .get();
    if (prices.isEmpty || prices.any((p) => p.isDefault)) return;
    await (_db.update(_db.supplierPrices)
          ..where((p) => p.id.equals(prices.first.id)))
        .write(const SupplierPricesCompanion(isDefault: Value(true)));
  }

  Future<String> _employeeName(String employeeId) async {
    final employee = await (_db.select(
      _db.employees,
    )..where((e) => e.id.equals(employeeId))).getSingleOrNull();
    return employee == null ? '' : '${employee.firstName} ${employee.lastName}';
  }

  Future<void> _logResolution(
    String reason, {
    required String table,
    required String rowKey,
    required String storeId,
    required Map<String, Object?> details,
  }) => _db
      .into(_db.syncErrors)
      .insert(
        SyncErrorsCompanion.insert(
          changedTable: table,
          rowKey: rowKey,
          storeId: storeId,
          payload: jsonEncode(details),
          reason: reason,
          rejectedAt: DateTime.now().toUtc(),
        ),
      );

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
      await (_db.select(_db.outbox)
            ..where((o) => o.changedTable.equals(table) & o.rowKey.equals(key)))
          .getSingleOrNull() !=
      null;

  Future<void> _upsert(
    TableInfo<Table, dynamic> table,
    Map<String, dynamic> row,
  ) {
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
