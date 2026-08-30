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
  int get schemaVersion => 2;

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
          attendancePausesAttendance,
        ]) {
          await m.create(index);
        }
        for (final column in [
          stores.openMinutes,
          stores.closeMinutes,
          stores.maxBreakMinutes,
          stores.overtimeMultiplier,
          stores.workingDaysPerMonth,
        ]) {
          await m.addColumn(stores, column);
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
}
