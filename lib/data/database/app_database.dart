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
import 'tables/catalog.dart';
import 'tables/employees.dart';
import 'tables/items.dart';
import 'tables/movements.dart';
import 'tables/orders.dart';
import 'tables/payroll.dart';
import 'tables/receipts.dart';
import 'tables/stores.dart';
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
  ],
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
  int get schemaVersion => 8;

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
          employeesCin,
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
      // v8, but replaying the real history here rather than skipping it keeps
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

      // v5 → v6: the Fixe / Extra contract type is gone — every employee is
      // now paid an hourly rate, `employees.pay` read the same way for
      // everyone. `contract_type` is dropped rather than kept and ignored.
      // Guarded `from >= 2` for the same reason the v3 → v4 block above is:
      // the `from < 2` branch's `createTable(employees)` already builds the
      // table from the *current* Dart definition, which has no such column.
      if (from >= 2 && from < 6) {
        await m.dropColumn(employees, 'contract_type');
      }

      // v6 → v7: a day can now hold several Pointer → Fin de journée cycles,
      // not just one — `attendances` no longer carries its own clock-in/out,
      // that moves onto a new child table, `attendance_sessions`, and
      // `attendance_pauses` now belongs to a session rather than to the day
      // directly (the same nesting `PurchaseOrderLine` needed under
      // `PurchaseOrder`). Guarded `from >= 2` for the reason every block above
      // is: a v1 install's `createTable` calls already build the current
      // shape.
      if (from >= 2 && from < 7) {
        await m.createTable(attendanceSessions);
        await m.create(attendanceSessionsAttendance);

        // Every existing day becomes its first (and so far only) session.
        await customStatement('''
          INSERT INTO attendance_sessions
            (id, attendance_id, position, clock_in_at, clock_out_at)
          SELECT id || '-session-0', id, 0, clock_in_at, clock_out_at
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
          INSERT INTO attendance_pauses (id, session_id, position, start_at, end_at)
          SELECT id, attendance_id || '-session-0', position, start_at, end_at
          FROM attendance_pauses_old
        ''');
        await customStatement('DROP TABLE attendance_pauses_old');

        await m.dropColumn(attendances, 'clock_in_at');
        await m.dropColumn(attendances, 'clock_out_at');
      }

      // v7 → v8: no more fixed hours, per employee or per store, and no more
      // heures supplémentaires — every hour actually worked is paid at the
      // flat rate, and only the break allowance is still measured against
      // anything. Guarded `from >= 2` for the usual reason: a `from < 2`
      // install's `createTable` calls already build the current
      // (schedule-less) shape.
      if (from >= 2 && from < 8) {
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
}
