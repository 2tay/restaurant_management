import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

// The enums the schema stores. They look unused here because the code that uses
// them is in the generated part below, which shares this file's imports — drop
// one and `app_database.g.dart` stops compiling, while `flutter analyze` stays
// clean, because generated files are excluded from it.
import '../../models/attendance.dart';
import '../../models/employee.dart';
import '../../models/notification_item.dart';
import '../../models/payroll_period.dart';
import '../../models/purchase_order.dart';
import '../../models/stock_movement.dart';
import 'tables/account.dart';
import 'tables/attendance.dart';
import 'tables/busy_dates.dart';
import 'tables/business_days.dart';
import 'tables/catalog.dart';
import 'tables/employees.dart';
import 'tables/items.dart';
import 'tables/movements.dart';
import 'tables/orders.dart';
import 'tables/outbox.dart';
import 'tables/photo_uploads.dart';
import 'tables/payroll.dart';
import 'tables/receipts.dart';
import 'tables/stores.dart';
import 'tables/sync_columns.dart';
import 'tables/sync_errors.dart';
import 'tables/suppliers.dart';

part 'app_database.g.dart';

/// The local database.
///
/// Nothing outside `lib/data/` touches this class. Screens talk to
/// repositories, repositories talk to this, and `tool/ux_audit.py` fails the
/// build if a file under `lib/features/` reaches past that.
///
/// The stock side: establishments, catalogue, articles, suppliers, the movement
/// log, commandes and their receipts, plus [Notifications] and [Meta].
/// [PurchaseOrders] and [GoodsReceipts] split their embedded line lists into
/// child tables.
///
/// The **Gestion Employée** module joined at schema version 2 (Phase 2 employé):
/// [Employees], [Attendances] with [AttendancePauses], and [PayrollPeriods].
/// Their login credentials, a table of its own from v2, left at v22: a
/// Gérant signs in with their email and PIN. The pointage / paie half of
/// `StoreSettings` moved onto the [Stores] row in the same version.
/// [AttendanceSessions] joined at v11, and [BusinessDays] — the journées de
/// service the pointage board works in — at v14.
@DriftDatabase(
  tables: [
    Stores,
    Meta,
    Categories,
    Units,
    Items,
    Suppliers,
    SupplierPrices,
    PriceHistory,
    StockMovements,
    PurchaseOrders,
    PurchaseOrderLines,
    GoodsReceipts,
    GoodsReceiptLines,
    Notifications,
    NotificationReads,
    Employees,
    PayrollPeriods,
    Attendances,
    AttendanceSessions,
    AttendancePauses,
    BusyDates,
    Outbox,
    SyncErrors,
    PhotoUploads,
    BusinessDays,
  ],
  include: {
    'sync_triggers.drift',
    'outbox_triggers.drift',
    'sync_indexes.drift',
    'photo_triggers.drift',
  },
)
class AppDatabase extends _$AppDatabase {
  /// The real one: a file, where the platform says application data belongs.
  AppDatabase() : super(driftDatabase(name: databaseName));

  /// A throwaway database in memory.
  ///
  /// Used by every test, and by `ProviderScope(overrides: ...)` to give a widget
  /// test its own isolated data. Fast enough that a test can seed the whole demo
  /// dataset in `setUp` without anybody noticing.
  AppDatabase.memory() : super(NativeDatabase.memory());

  /// For a caller that already has an executor — a logging wrapper, or the
  /// migration test harness.
  AppDatabase.withExecutor(super.executor);

  /// The file name, without extension. Changing it strands every existing
  /// install's data, so it does not change.
  static const String databaseName = 'stock_inventory';

  @override
  int get schemaVersion => 24;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },

    // v1 → v2 (Phase 2 employé): the Gestion Employée module joins the
    // database. Five new tables and five columns on `stores`. The column
    // defaults match the constants in `core/utils/`, so an install upgraded
    // in place reads exactly what a fresh one would.
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(employees);
        await m.createTable(payrollPeriods);
        await m.createTable(attendances);
        await m.createTable(attendanceSessions);
        await m.createTable(attendancePauses);
        // `createTable` does not carry the table's `@TableIndex` entries; they
        // are separate schema objects and must be created by hand.
        for (final index in [
          employeesStore,
          payrollPeriodsEmployee,
          payrollPeriodsStore,
          attendancesEmployeeDate,
          attendancesStoreDate,
          attendanceSessionsAttendance,
          attendancePausesSession,
        ]) {
          await m.create(index);
        }
        // The PIN and email indexes of the time, by hand: they are no longer
        // in the schema (v21 replaces them with per-store ones).
        await customStatement(
          'CREATE UNIQUE INDEX employees_pin ON employees (pin)',
        );
        await customStatement(
          'CREATE UNIQUE INDEX employees_email ON employees (email)',
        );
        await m.addColumn(stores, stores.maxBreakMinutes);
      }

      // v2 → v3: `items.maxStock`, the figure a commande tops up to. Its
      // column default is zero, which the ordering screen reads as "no ceiling
      // declared" and answers with its old threshold-based figure — so an
      // install upgraded in place keeps ordering exactly as it did until
      // somebody sets a maximum.
      if (from < 3) {
        await m.addColumn(items, items.maxStock);
      }

      // v3 → v4: `attendances` gains the three columns that freeze the
      // schedule / break allowance a day was judged against, so a later
      // change to the store hours or an employee's schedule cannot rewrite a
      // past day's retard / heures supp. / pause dépassée (both retired in
      // v12, but replaying the real history here rather than skipping it keeps
      // this block honest about what an actual v3 install went through).
      // Guarded `from >= 2` because the `from < 2` branch above already
      // creates `attendances` at the current shape — a v1 → v4 upgrade must
      // not then re-add these.
      //
      // `scheduled_start_minutes` / `scheduled_end_minutes` are added via raw
      // SQL rather than `m.addColumn`: those Dart columns no longer exist on
      // `Attendances` (dropped again in v8), so there is no typed column
      // object left to pass — only the historical column name.
      if (from >= 2 && from < 4) {
        await customStatement(
          'ALTER TABLE attendances ADD COLUMN scheduled_start_minutes INTEGER',
        );
        await customStatement(
          'ALTER TABLE attendances ADD COLUMN scheduled_end_minutes INTEGER',
        );
        await m.addColumn(attendances, attendances.maxBreakMinutes);
        // Backfill each existing day with what it resolves to right now — the
        // employee's own schedule if set, else the store's — so an upgrade
        // freezes today's behaviour rather than changing it.
        await customStatement('''
          UPDATE attendances SET
            scheduled_start_minutes = coalesce(
              (SELECT e.scheduled_start_minutes FROM employees e
                 WHERE e.id = attendances.employee_id),
              (SELECT s.open_minutes FROM stores s
                 WHERE s.id = attendances.store_id)),
            scheduled_end_minutes = coalesce(
              (SELECT e.scheduled_end_minutes FROM employees e
                 WHERE e.id = attendances.employee_id),
              (SELECT s.close_minutes FROM stores s
                 WHERE s.id = attendances.store_id)),
            max_break_minutes = (SELECT s.max_break_minutes FROM stores s
                 WHERE s.id = attendances.store_id)
        ''');
      }

      // v4 → v5: `items.imagePath`, the product photo. Nullable with no
      // default, so every existing article simply has no photo — which is
      // true, and needs no backfill.
      if (from < 5) {
        await m.addColumn(items, items.imagePath);
      }

      // v5 → v6: `stock_movements.employeeId`, who recorded the movement at
      // the shared tablet. Nullable with no default: a movement from before
      // simply names nobody by id, and still carries the `userName` it always
      // had.
      if (from < 6) {
        await m.addColumn(stockMovements, stockMovements.employeeId);
      }

      // v6 → v7: `goods_receipts.receivedByEmployeeId`, the same for a
      // delivery received against a commande. Nullable, no default, no
      // backfill: older receipts keep the name they always had.
      if (from < 7) {
        await m.addColumn(goodsReceipts, goodsReceipts.receivedByEmployeeId);
      }

      // v7 → v8: the four notification preferences on `stores`. Until now the
      // preferences screen held them in a `setState` that nothing read and
      // nothing saved; this is where they land. The column defaults are the
      // values that screen already displayed, so an install upgraded in place
      // opens on exactly the settings it appeared to have.
      if (from < 8) {
        for (final column in [
          stores.notifyLowStock,
          stores.notifyPriceChange,
          stores.notifyLargeAdjustment,
          stores.notifyDeliveries,
        ]) {
          await m.addColumn(stores, column);
        }
      }

      // v8 → v9: `items.holidayLowStockThreshold`, the minimum to hold in a
      // busy week. Nullable with no default and no backfill, because null is
      // the meaningful state: it means nobody has set one, and the figure is
      // then derived as twice the ordinary minimum rather than stored.
      if (from < 9) {
        await m.addColumn(items, items.holidayLowStockThreshold);
      }

      // v9 → v10: the Fixe / Extra contract type is gone — every employee is
      // now paid an hourly rate, `employees.pay` read the same way for
      // everyone. `contract_type` is dropped rather than kept and ignored.
      // Guarded `from >= 2` for the same reason the v3 → v4 block above is:
      // the `from < 2` branch's `createTable(employees)` already builds the
      // table from the *current* Dart definition, which has no such column.
      if (from >= 2 && from < 10) {
        await m.dropColumn(employees, 'contract_type');
      }

      // v10 → v11: a day can now hold several Pointer → Fin de journée cycles,
      // not just one — `attendances` no longer carries its own clock-in/out,
      // that moves onto a new child table, `attendance_sessions`, and
      // `attendance_pauses` now belongs to a session rather than to the day
      // directly (the same nesting `PurchaseOrderLine` needed under
      // `PurchaseOrder`). Guarded `from >= 2` for the reason every block above
      // is: a v1 install's `createTable` calls already build the current
      // shape.
      if (from >= 2 && from < 11) {
        await m.createTable(attendanceSessions);
        await m.create(attendanceSessionsAttendance);

        // Every existing day becomes its first (and so far only) session.
        // `store_id` and `updated_at` are version 15 columns. They are filled
        // here because `createTable` above builds the *current* shape, where
        // both are NOT NULL.
        await customStatement('''
          INSERT INTO attendance_sessions
            (id, store_id, attendance_id, position, clock_in_at, clock_out_at,
             updated_at)
          SELECT id || '-session-0', store_id, id, 0, clock_in_at, clock_out_at,
                 coalesce(clock_out_at, clock_in_at)
          FROM attendances WHERE clock_in_at IS NOT NULL
        ''');

        // `attendance_pauses` moves from (attendance_id, position) to
        // (session_id, position) — a shape change, not a column tweak, so the
        // table is rebuilt from the current Dart definition (via
        // `createTable`, the same path a fresh install takes) rather than
        // altered column by column, which guarantees the result matches
        // exactly rather than hoping a hand-written ALTER sequence does.
        await customStatement(
          'ALTER TABLE attendance_pauses RENAME TO attendance_pauses_old',
        );
        await customStatement('DROP INDEX attendance_pauses_attendance');
        await m.createTable(attendancePauses);
        await m.create(attendancePausesSession);
        await customStatement('''
          INSERT INTO attendance_pauses
            (id, store_id, session_id, position, start_at, end_at, updated_at)
          SELECT p.id, a.store_id, p.attendance_id || '-session-0', p.position,
                 p.start_at, p.end_at, coalesce(p.end_at, p.start_at)
          FROM attendance_pauses_old p
          JOIN attendances a ON a.id = p.attendance_id
        ''');
        await customStatement('DROP TABLE attendance_pauses_old');

        await m.dropColumn(attendances, 'clock_in_at');
        await m.dropColumn(attendances, 'clock_out_at');
      }

      // v11 → v12: no more fixed hours, per employee or per store, and no more
      // heures supplémentaires — every hour actually worked is paid at the
      // flat rate, and only the break allowance is still measured against
      // anything. Guarded `from >= 2` for the usual reason: a `from < 2`
      // install's `createTable` calls already build the current
      // (schedule-less) shape.
      if (from >= 2 && from < 12) {
        await m.dropColumn(employees, 'scheduled_start_minutes');
        await m.dropColumn(employees, 'scheduled_end_minutes');
        await m.dropColumn(attendances, 'scheduled_start_minutes');
        await m.dropColumn(attendances, 'scheduled_end_minutes');
        await m.dropColumn(stores, 'open_minutes');
        await m.dropColumn(stores, 'close_minutes');
        await m.dropColumn(stores, 'overtime_multiplier');
        await m.dropColumn(stores, 'working_days_per_month');
        await m.dropColumn(payrollPeriods, 'total_overtime_hours');
      }

      // v12 → v13: vocabulary only. What was the CIN (the login identifier, also
      // typed to confirm identity at the kiosk) is now the PIN. Renamed in
      // place so every value survives. Guarded `from >= 2` for the usual
      // reason. (The password table of the time is left as it is: v22 drops
      // it.)
      if (from >= 2 && from < 13) {
        await customStatement('DROP INDEX employees_cin');
        await m.renameColumn(employees, 'cin', employees.pin);
        await customStatement(
          'CREATE UNIQUE INDEX employees_pin ON employees (pin)',
        );
      }

      // v13 -> v14: the busy-day calendar. Three columns on `stores` (the busy
      // weekdays, how early to remind, and the notification switch) and the
      // table of one-off busy dates. Defaults, not backfills, so an upgraded
      // install starts on Friday–Sunday with a one-day reminder exactly as a
      // fresh one does.
      if (from < 14) {
        await m.addColumn(stores, stores.notifyBusyDays);
        await m.addColumn(stores, stores.busyWeekdays);
        await m.addColumn(stores, stores.busyReminderDays);
        await m.createTable(busyDates);
      }

      // v14 -> v15: ready for sync (SYNC_PLAN.md, Phase 1). See
      // [_migrateToVersion15].
      if (from < 15) {
        await _migrateToVersion15(m);
      }

      // v15 -> v16: the outbox (SYNC_PLAN.md, Phase 2) and the triggers that
      // fill it. Nothing already in the database is queued: the rows an
      // install holds before this version were never meant for a server, and
      // uploading them is a deliberate step of its own (Phase 9).
      if (from < 16) {
        await m.createTable(outbox);
        await m.create(outboxRow);
        await _createTriggers(m, (name) => name.contains('_outbox_'));
      }

      // v16 -> v17: the changes the server refused (SYNC_PLAN.md, Phase 5).
      if (from < 17) {
        await m.createTable(syncErrors);
      }

      // v17 -> v18: the `*_touch` triggers stay silent during quiet writes
      // (SYNC_PLAN.md, Phase 6), so a row received from the server keeps the
      // server's `updated_at`. Recreated from their current definition.
      if (from >= 15 && from < 18) {
        await _createTriggers(
          m,
          (name) => name.endsWith('_touch'),
          replace: true,
        );
      }

      // v18 -> v19: the three "one per" rules count live rows only
      // (SYNC_PLAN.md, Phase 7), and receive conflicts logged before now are
      // replayed through the new rules by pulling their stores again.
      if (from < 19) {
        for (final index in [
          attendancesEmployeeDate,
          supplierPricesPair,
        ]) {
          await customStatement('DROP INDEX IF EXISTS ${index.entityName}');
          await m.create(index);
        }
        if (from >= 17) {
          await customStatement('''
            DELETE FROM meta WHERE key IN (
              SELECT 'syncCursor:' || store_id FROM sync_errors
               WHERE reason = 'receive_conflict')
          ''');
          await customStatement(
            "DELETE FROM sync_errors WHERE reason = 'receive_conflict'",
          );
        }
      }

      // v19 -> v20: photos (SYNC_PLAN.md, Phase 8). See [_migrateToVersion20].
      if (from < 20) {
        await _migrateToVersion20(m);
      }

      // v20 -> v21: the journée de service and two columns from the pointage
      // audit (feat/sync-data, numbered v14–v16 there), all synced. The
      // journée table, its "one live per store and date" index and its touch
      // and outbox triggers; `stores.business_day_auto_open_minutes`, whose
      // default (05:00) is what every store read when it was a constant; and
      // `attendance_sessions.exit_set_by_employee_id`, null on every existing
      // session — nobody knows who entered those exits. The columns are added
      // only when missing: a v1/v10 `createTable` and the v15 rebuild already
      // build the current shape. The outbox triggers of those two tables are
      // recreated so their payload carries the new column.
      //
      // And the signalements (SYNC_PERSONNEL_PLAN.md, step 3): on
      // `notifications`, the employee one is about and when a manager and
      // the owner read it — null on every existing notification.
      if (from < 21) {
        await m.createTable(businessDays);
        await m.create(businessDaysStoreDate);
        await _addColumnIfMissing(m, stores, stores.businessDayAutoOpenMinutes);
        await _addColumnIfMissing(
          m,
          attendanceSessions,
          attendanceSessions.exitSetByEmployeeId,
        );
        for (final column in [
          notifications.relatedEmployeeId,
          notifications.relatedTarget,
          notifications.readByManagerAt,
          notifications.readByOwnerAt,
        ]) {
          await _addColumnIfMissing(m, notifications, column);
        }
        // Step 8 (rule E1): the CIN and the email are unique per store
        // among live rows, no longer across every row of the account.
        await customStatement('DROP INDEX IF EXISTS employees_pin');
        await customStatement('DROP INDEX IF EXISTS employees_email');
        await m.create(employeesStorePin);
        await m.create(employeesStoreEmail);
        // Step 7 (rule PA1): the trop-versé of a « paiement en double ».
        await _addColumnIfMissing(
          m,
          payrollPeriods,
          payrollPeriods.doublePaymentAmount,
        );
        // Step 4: an edit of a personnel row sends only what changed. Every
        // outbox trigger is recreated to fill `changed_columns`; an entry
        // already queued stays whole (null), as it always was.
        if (from >= 16) {
          await _addColumnIfMissing(m, outbox, outbox.changedColumns);
          await _addColumnIfMissing(m, outbox, outbox.baseValues);
        }
        await _createTriggers(m, (name) => name.startsWith('business_days_'));
        await _createTriggers(
          m,
          (name) => name.contains('_outbox_'),
          replace: true,
        );
      }

      // v21 -> v22: no more login password — a Gérant signs in with their
      // email and PIN. The password table and the sign-in state go, with
      // anything of them still waiting to be sent or logged as refused.
      if (from < 22) {
        await customStatement('DROP TABLE IF EXISTS login_states');
        await customStatement('DROP TABLE IF EXISTS employee_credentials');
        await customStatement(
          "DELETE FROM outbox WHERE changed_table = 'employee_credentials'",
        );
        await customStatement(
          "DELETE FROM sync_errors WHERE changed_table = 'employee_credentials'",
        );
      }

      // v22 -> v23: a signalement is read per person, not per role. The
      // table of who read what, with its index and its touch and outbox
      // triggers. Nothing is copied into it: the role stamps already on
      // `notifications` keep counting as read (`AccountRepository`).
      if (from < 23) {
        await m.createTable(notificationReads);
        await m.create(notificationReadsEmployee);
        await _createTriggers(
          m,
          (name) => name.startsWith('notification_reads_'),
        );
      }

      // v23 -> v24: the arrivée and départ notification switches on `stores`,
      // off by default. The stores outbox triggers are recreated so their
      // payload carries the two new columns.
      if (from < 24) {
        await _addColumnIfMissing(m, stores, stores.notifyClockIn);
        await _addColumnIfMissing(m, stores, stores.notifyClockOut);
        if (from >= 16) {
          await _createTriggers(
            m,
            (name) => name.startsWith('stores_outbox_'),
            replace: true,
          );
        }
      }
    },

    beforeOpen: (OpeningDetails details) async {
      // SQLite has foreign keys switched **off** by default, per connection.
      // Without this every `references()` in `tables/` is decorative — the
      // schema would claim constraints it does not enforce, which is worse than
      // having none. It must run outside a transaction, which is why it is here
      // and not in onCreate.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// The column names [table] has in the database right now.
  Future<Set<String>> _columnNames(TableInfo<Table, dynamic> table) async {
    final rows = await customSelect(
      'PRAGMA table_info(${table.actualTableName})',
    ).get();
    return {for (final row in rows) row.read<String>('name')};
  }

  /// Creates the schema's triggers whose name passes [wanted], from their
  /// current definition — dropping the old one first when [replace].
  ///
  /// A trigger on a table this install does not have yet is skipped: a step
  /// that creates "every `_touch` trigger" must not reach for a table a later
  /// version adds (`business_days`, v21), which creates its own.
  Future<void> _createTriggers(
    Migrator m,
    bool Function(String name) wanted, {
    bool replace = false,
  }) async {
    final tables = {
      for (final row in await customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      ).get())
        row.read<String>('name'),
    };
    final onTable = RegExp(r'\bON\s+"?(\w+)', caseSensitive: false);
    for (final trigger in allSchemaEntities.whereType<Trigger>()) {
      if (!wanted(trigger.entityName)) continue;
      final table = onTable.firstMatch(
        trigger.createStatementsByDialect.values.first,
      )?.group(1);
      if (table == null || !tables.contains(table)) continue;
      if (replace) {
        await customStatement('DROP TRIGGER IF EXISTS ${trigger.entityName}');
      }
      await m.create(trigger);
    }
  }

  /// Adds [column] to [table] unless an earlier step already built it.
  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo<Table, dynamic> table,
    GeneratedColumn<Object> column,
  ) async {
    if ((await _columnNames(table)).contains(column.name)) return;
    await m.addColumn(table, column);
  }

  /// Every synced table gains `updated_at` and `deleted_at`, the child tables
  /// gain `store_id`, and articles gain their stock baseline.
  ///
  /// Each table is rebuilt with `alterTable` rather than altered column by
  /// column: SQLite cannot `ADD COLUMN` a NOT NULL column without a constant
  /// default, and `updated_at` and `store_id` have none. drift switches foreign
  /// keys off around the rebuild, so dropping `stores` does not cascade.
  ///
  /// `updated_at` starts as the newest date the row already carries, or the
  /// upgrade time for a table with no date of its own. `store_id` is copied
  /// from the parent row. The stock baseline is the article's stock right now,
  /// and every movement already filed is marked as part of it: the history an
  /// install holds before this version is not guaranteed to add up to its
  /// stock, so a rebuild must start from what the article holds today.
  Future<void> _migrateToVersion15(Migrator m) async {
    // `updated_at` is always UTC (see `tables/sync_columns.dart`), so the
    // dates it starts from are converted: `strftime` reads drift's local
    // format, offset included, and writes the UTC one.
    final now = Variable<DateTime>(syncStampNow());

    Expression<DateTime> newest(List<Expression<DateTime>> dates) =>
        FunctionCallExpression<DateTime>('strftime', [
          const Constant('%Y-%m-%dT%H:%M:%fZ'),
          coalesce([...dates, now]),
        ]);
    Expression<T> sql<T extends Object>(String expression) =>
        CustomExpression<T>(expression);

    Future<void> rebuild(
      TableInfo<Table, dynamic> table,
      Map<GeneratedColumn<Object>, Expression<Object>> transform, {
      List<GeneratedColumn<Object>> extraColumns = const [],
    }) async {
      // A column added by a later version (v21's audit columns) is already
      // in the current shape the rebuild builds, but not yet in the old
      // table: it is new here too, and starts at its default.
      final existing = await _columnNames(table);
      final added = [
        for (final column in table.$columns)
          if (column.name == 'updated_at' && transform.containsKey(column))
            column
          else if (column.name == 'deleted_at')
            column
          else if (!existing.contains(column.name) &&
              !extraColumns.contains(column))
            column,
        ...extraColumns,
      ];
      await m.alterTable(
        // `TableMigration` is marked experimental, but it is drift's documented
        // way to rebuild a table, and the migration test checks the result.
        // ignore: experimental_member_use
        TableMigration(table, newColumns: added, columnTransformer: transform),
      );
    }

    await rebuild(stores, {
      stores.updatedAt: newest([stores.createdAt]),
    });
    await rebuild(categories, {categories.updatedAt: now});
    await rebuild(units, {units.updatedAt: now});
    await rebuild(
      items,
      {
        items.baselineQuantity: items.quantity,
        items.baselineAverageCost: items.averageCost,
      },
      extraColumns: [items.baselineQuantity, items.baselineAverageCost],
    );
    await rebuild(suppliers, {suppliers.updatedAt: now});
    await rebuild(
      supplierPrices,
      {
        supplierPrices.updatedAt: newest([supplierPrices.effectiveDate]),
        supplierPrices.storeId: sql<String>(
          '(SELECT i.store_id FROM items i '
          'WHERE i.id = supplier_prices.item_id)',
        ),
      },
      extraColumns: [supplierPrices.storeId],
    );
    await rebuild(
      priceHistory,
      {
        priceHistory.updatedAt: newest([priceHistory.changedAt]),
        priceHistory.storeId: sql<String>(
          '(SELECT i.store_id FROM items i '
          'WHERE i.id = price_history.item_id)',
        ),
      },
      extraColumns: [priceHistory.storeId],
    );
    await rebuild(
      stockMovements,
      {
        stockMovements.updatedAt: newest([stockMovements.occurredAt]),
        stockMovements.inBaseline: const Constant(true),
      },
      extraColumns: [stockMovements.inBaseline],
    );
    await rebuild(purchaseOrders, {
      purchaseOrders.updatedAt: newest([
        purchaseOrders.closedAt,
        purchaseOrders.sentAt,
        purchaseOrders.createdAt,
      ]),
    });
    await rebuild(
      purchaseOrderLines,
      {
        purchaseOrderLines.updatedAt: newest([
          sql<DateTime>(
            '(SELECT coalesce(o.closed_at, o.sent_at, o.created_at) '
            'FROM purchase_orders o '
            'WHERE o.id = purchase_order_lines.order_id)',
          ),
        ]),
        purchaseOrderLines.storeId: sql<String>(
          '(SELECT o.store_id FROM purchase_orders o '
          'WHERE o.id = purchase_order_lines.order_id)',
        ),
      },
      extraColumns: [purchaseOrderLines.storeId],
    );
    await rebuild(goodsReceipts, {
      goodsReceipts.updatedAt: newest([goodsReceipts.receivedAt]),
    });
    await rebuild(
      goodsReceiptLines,
      {
        goodsReceiptLines.updatedAt: newest([
          sql<DateTime>(
            '(SELECT r.received_at FROM goods_receipts r '
            'WHERE r.id = goods_receipt_lines.receipt_id)',
          ),
        ]),
        goodsReceiptLines.storeId: sql<String>(
          '(SELECT r.store_id FROM goods_receipts r '
          'WHERE r.id = goods_receipt_lines.receipt_id)',
        ),
      },
      extraColumns: [goodsReceiptLines.storeId],
    );
    await rebuild(notifications, {
      notifications.updatedAt: newest([notifications.createdAt]),
    });
    await rebuild(employees, {
      employees.updatedAt: newest([employees.archivedAt, employees.createdAt]),
    });
    await rebuild(payrollPeriods, {
      payrollPeriods.updatedAt: newest([
        payrollPeriods.paidAt,
        payrollPeriods.createdAt,
      ]),
    });
    await rebuild(attendances, {
      attendances.updatedAt: newest([attendances.date]),
    });
    await rebuild(
      attendanceSessions,
      {
        attendanceSessions.updatedAt: newest([
          attendanceSessions.clockOutAt,
          attendanceSessions.clockInAt,
        ]),
        attendanceSessions.storeId: sql<String>(
          '(SELECT a.store_id FROM attendances a '
          'WHERE a.id = attendance_sessions.attendance_id)',
        ),
      },
      extraColumns: [attendanceSessions.storeId],
    );
    await rebuild(
      attendancePauses,
      {
        attendancePauses.updatedAt: newest([
          attendancePauses.endAt,
          attendancePauses.startAt,
        ]),
        attendancePauses.storeId: sql<String>(
          '(SELECT a.store_id FROM attendance_sessions s '
          'JOIN attendances a ON a.id = s.attendance_id '
          'WHERE s.id = attendance_pauses.session_id)',
        ),
      },
      extraColumns: [attendancePauses.storeId],
    );
    await rebuild(busyDates, {busyDates.updatedAt: now});

    // The clock view and the `*_touch` triggers from `sync_triggers.drift`.
    // Created last: `alterTable` recreates the triggers already attached to a
    // table, and these would otherwise fire during the copies above.
    await m.create(syncClock);
    await _createTriggers(m, (name) => name.endsWith('_touch'));
  }

  /// The photo queue and its triggers, employee photos stored by file name,
  /// and every photo already on the device queued for upload.
  ///
  /// `employees.photo_asset` used to hold an absolute path on this device,
  /// which means nothing on another tablet. It becomes the bare file name,
  /// like `items.image_path`; the file stays where it is. That update is a
  /// real change, and the outbox queues it like any other.
  Future<void> _migrateToVersion20(Migrator m) async {
    await m.createTable(photoUploads);
    await m.create(photoUploadsFile);

    final photos = await customSelect(
      "SELECT id, photo_asset FROM employees WHERE photo_asset LIKE '%employee_photos%'",
    ).get();
    for (final row in photos) {
      final path = row.read<String>('photo_asset');
      // Either separator: the path was written on Windows or elsewhere.
      final name = path.split(RegExp(r'[\\/]')).last;
      await customStatement(
        'UPDATE employees SET photo_asset = ? WHERE id = ?',
        [name, row.read<String>('id')],
      );
    }

    await _createTriggers(m, (name) => name.contains('_photo_'));

    // What the device already holds goes up with the first sync.
    await customStatement(r'''
      INSERT OR IGNORE INTO photo_uploads
        (kind, store_id, file_name, operation, queued_at)
      SELECT 'items', store_id, image_path, 'upload', (SELECT now FROM sync_clock)
        FROM items
       WHERE image_path IS NOT NULL AND deleted_at IS NULL
         AND instr(image_path, '/') = 0 AND instr(image_path, '\') = 0
    ''');
    await customStatement(r'''
      INSERT OR IGNORE INTO photo_uploads
        (kind, store_id, file_name, operation, queued_at)
      SELECT 'employees', store_id, photo_asset, 'upload',
             (SELECT now FROM sync_clock)
        FROM employees
       WHERE photo_asset IS NOT NULL AND deleted_at IS NULL
         AND instr(photo_asset, '/') = 0 AND instr(photo_asset, '\') = 0
    ''');
  }
}
