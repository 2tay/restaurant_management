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
import 'tables/business_days.dart';
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
    Employees,
    EmployeeCredentials,
    PayrollPeriods,
    Attendances,
    AttendanceSessions,
    AttendancePauses,
    BusinessDays,
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
  int get schemaVersion => 16;

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
      // follows the rename (see `fakePasswordHash`) so an existing password
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

      // v13 → v14: the journée de service. A new table and nothing else —
      // attendance rows join it on their date, so no existing row moves, and
      // no journée is backfilled: the past needs none, and the board opens
      // today's on the first Pointer. Not guarded `from >= 2`: the `from < 2`
      // branch does not create this table.
      if (from < 14) {
        await m.createTable(businessDays);
        await m.create(businessDaysStoreDate);
      }

      // v14 → v15: the time of day a journée de service may open by itself,
      // per store. The column default (05:00) is what every store read
      // before, when it was a constant — an upgraded install behaves exactly
      // as it did. `stores` exists from v1, so no `from >= 2` guard.
      if (from < 15) {
        await m.addColumn(stores, stores.businessDayAutoOpenMinutes);
      }

      // v15 → v16: `attendance_sessions.exit_set_by_employee_id`, who entered
      // an exit in the employee's place. Null on every existing session —
      // nobody knows who did, and a null reads "clocked out themselves" or
      // "from before". Guarded `from >= 11`: an older install's `createTable`
      // calls (v1 → v2, v10 → v11) already build the current shape.
      if (from >= 11 && from < 16) {
        await m.addColumn(
          attendanceSessions,
          attendanceSessions.exitSetByEmployeeId,
        );
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
