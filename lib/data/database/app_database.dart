import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

// The enums the schema stores. They look unused here because the code that uses
// them is in the generated part below, which shares this file's imports — drop
// one and `app_database.g.dart` stops compiling, while `flutter analyze` stays
// clean, because generated files are excluded from it.
import '../../models/notification_item.dart';
import '../../models/purchase_order.dart';
import '../../models/stock_movement.dart';
import '../../models/team_member.dart';
import 'tables/account.dart';
import 'tables/catalog.dart';
import 'tables/items.dart';
import 'tables/movements.dart';
import 'tables/orders.dart';
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
/// Sixteen tables: the fourteen persisted models, two of which
/// ([PurchaseOrders], [GoodsReceipts]) split their embedded line lists into
/// child tables, plus [TeamMemberStores] for the many-to-many the model holds
/// as a `List<String>`, plus [Meta] for the two facts that belong to the
/// database rather than to any establishment.
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
    TeamMembers,
    TeamMemberStores,
    Notifications,
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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },

    // Nothing to do at version 1, and the strategy is written out anyway rather
    // than left to the default. Phase 3 adds columns; by then this database has
    // a restaurant's real stock in it and there is no second chance to decide
    // how upgrades work.
    onUpgrade: (Migrator m, int from, int to) async {},

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
