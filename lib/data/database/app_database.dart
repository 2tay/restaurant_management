import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

// The enums the schema stores. They look unused here because the code that uses
// them is in the generated part below, which shares this file's imports — drop
// one and `app_database.g.dart` stops compiling, while `flutter analyze` stays
// clean, because generated files are excluded from it.
import '../../core/utils/credential_status.dart';
import '../../models/attendance.dart';
import '../../models/employee.dart';
import '../../models/notification_item.dart';
import '../../models/payroll_period.dart';
import '../../models/purchase_order.dart';
import '../../models/stock_movement.dart';
import 'tables/account.dart';
import 'tables/attendance.dart';
import 'tables/busy_dates.dart';
import 'tables/catalog.dart';
import 'tables/employees.dart';
import 'tables/items.dart';
import 'tables/movements.dart';
import 'tables/orders.dart';
import 'tables/outbox.dart';
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
/// [Employees] and their [EmployeeCredentials], [Attendances] with
/// [AttendancePauses], and [PayrollPeriods]. The pointage / paie half of
/// `StoreSettings` moved onto the [Stores] row in the same version.
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
    Employees,
    EmployeeCredentials,
    PayrollPeriods,
    Attendances,
    AttendanceSessions,
    AttendancePauses,
    BusyDates,
    Outbox,
    SyncErrors,
  ],
  include: {'sync_triggers.drift', 'outbox_triggers.drift'},
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
  int get schemaVersion => 18;

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
        await m.createTable(employeeCredentials);
        await m.createTable(payrollPeriods);
        await m.createTable(attendances);
        await m.createTable(attendanceSessions);
        await m.createTable(attendancePauses);
        // `createTable` does not carry the table's `@TableIndex` entries; they
        // are separate schema objects and must be created by hand.
        for (final index in [
          employeesStore,
          employeesPin,
          employeesEmail,
          employeeCredentialsEmployee,
          payrollPeriodsEmployee,
          payrollPeriodsStore,
          attendancesEmployeeDate,
          attendancesStoreDate,
          attendanceSessionsAttendance,
          attendancePausesSession,
        ]) {
          await m.create(index);
        }
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
      // typed to confirm identity at the kiosk) is now the PIN, and what was
      // the PIN (the 4-digit login secret) is now the password. Renamed in
      // place so every value survives, and the fake hash's `pin:` prefix
      // follows the rename (the fake hash of the time) so an existing password
      // still matches. Guarded `from >= 2` for the usual reason.
      if (from >= 2 && from < 13) {
        await customStatement('DROP INDEX employees_cin');
        await m.renameColumn(employees, 'cin', employees.pin);
        await m.create(employeesPin);
        await m.renameColumn(
          employeeCredentials,
          'pin_hash',
          employeeCredentials.passwordHash,
        );
        await customStatement('''
          UPDATE employee_credentials
          SET password_hash = 'password:' || substr(password_hash, 5)
          WHERE password_hash LIKE 'pin:%'
        ''');
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
        for (final trigger in allSchemaEntities.whereType<Trigger>()) {
          if (trigger.entityName.contains('_outbox_')) await m.create(trigger);
        }
      }

      // v16 -> v17: the changes the server refused (SYNC_PLAN.md, Phase 5).
      if (from < 17) {
        await m.createTable(syncErrors);
      }

      // v17 -> v18: the `*_touch` triggers stay silent during quiet writes
      // (SYNC_PLAN.md, Phase 6), so a row received from the server keeps the
      // server's `updated_at`. Recreated from their current definition.
      if (from >= 15 && from < 18) {
        for (final trigger in allSchemaEntities.whereType<Trigger>()) {
          if (!trigger.entityName.endsWith('_touch')) continue;
          await customStatement('DROP TRIGGER IF EXISTS ${trigger.entityName}');
          await m.create(trigger);
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
      final added = [
        for (final column in table.$columns)
          if (column.name == 'updated_at' && transform.containsKey(column))
            column
          else if (column.name == 'deleted_at')
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
    await rebuild(
      employeeCredentials,
      {
        employeeCredentials.updatedAt: now,
        employeeCredentials.storeId: sql<String>(
          '(SELECT e.store_id FROM employees e '
          'WHERE e.id = employee_credentials.employee_id)',
        ),
      },
      extraColumns: [employeeCredentials.storeId],
    );
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

    // Until now a password was stored as `password:1234`, a marker rather than
    // a hash. Credentials are about to be synced, so each is rehashed for real
    // here, from the value it already holds: nobody has to pick a new one.
    final legacy = await customSelect(
      'SELECT id, password_hash FROM employee_credentials '
      "WHERE password_hash LIKE 'password:%'",
    ).get();
    for (final row in legacy) {
      final password = row.read<String>('password_hash').substring(9);
      await customStatement(
        'UPDATE employee_credentials SET password_hash = ? WHERE id = ?',
        [passwordHashOf(password), row.read<String>('id')],
      );
    }

    // The clock view and the `*_touch` triggers from `sync_triggers.drift`.
    // Created last: `alterTable` recreates the triggers already attached to a
    // table, and these would otherwise fire during the copies above.
    await m.create(syncClock);
    for (final trigger in allSchemaEntities.whereType<Trigger>()) {
      if (trigger.entityName.endsWith('_touch')) await m.create(trigger);
    }
  }
}
