// `Category` here is Flutter's diagnostics annotation, not ours.
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../mock_categories.dart';
import '../mock_employees.dart';
import '../mock_goods_receipts.dart';
import '../mock_items.dart';
import '../mock_notifications.dart';
import '../mock_price_history.dart';
import '../mock_purchase_orders.dart';
import '../mock_settings.dart';
import '../mock_stock_movements.dart';
import '../mock_stores.dart';
import '../mock_supplier_prices.dart';
import '../mock_suppliers.dart';
import '../mock_units.dart';

/// The plumbing every mutation shares: new ids, the change signal, and the
/// snapshot that lets a demo be run twice.
///
/// The mutations themselves live in siblings of this file, one per aggregate —
/// items, catalogue, suppliers, movements, orders. They are split that way
/// because Phase 2 replaces each with a repository, and a one-to-one seam is
/// easier to walk across than one 900-line class.
///
/// **This is not a data layer.** No storage, no network, no repositories. These
/// are list edits held in memory for as long as the app is open. What matters
/// is that the rules are here and correct, because Phase 2 reimplements exactly
/// these against real local-first storage.
abstract final class MockWrite {
  // ---------------------------------------------------------------------------
  // Change notification
  // ---------------------------------------------------------------------------

  /// Bumped after every write.
  ///
  /// Screens read the mock lists directly at build time, so without a signal a
  /// page already on screen keeps showing what it read before the mutation —
  /// most visibly when a receiving screen pops back to an order detail that
  /// still says nothing has arrived.
  ///
  /// A revision counter rather than fine-grained events: with a dataset this
  /// size, "something changed, look again" is both correct and cheaper to
  /// reason about than a dependency graph. Phase 2 replaces it with whatever
  /// change stream the storage layer exposes.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Writes applied since the last [captureSeed] or [reset].
  ///
  /// Drives whether the reset action has anything to do. Separate from
  /// [revision], which must keep climbing across a reset so that screens
  /// listening to it redraw when the data goes back.
  static int _writes = 0;

  /// True once anything in the demo has been changed.
  static bool get hasChanges => _writes > 0;

  /// Called by every mutation after it has finished editing the lists.
  static void changed() {
    _writes++;
    revision.value++;
  }

  // ---------------------------------------------------------------------------
  // Ids
  // ---------------------------------------------------------------------------

  static int _sequence = 0;

  /// A new id for a record created during this session.
  ///
  /// Prefixed and obviously generated — `item-new-7` next to `item-tomates` —
  /// so anything created during a demo is identifiable in a debug dump.
  static String id(String prefix) {
    _sequence++;
    return '$prefix-new-$_sequence';
  }

  // ---------------------------------------------------------------------------
  // Snapshot and reset
  // ---------------------------------------------------------------------------

  static _Seed? _seed;

  /// Captures the pristine dataset. Called once from `main()`, before anything
  /// can have been edited.
  ///
  /// The models are immutable, so copying the lists is a true deep snapshot —
  /// no element can change underneath it. That is the same trick the test
  /// suite uses to isolate one test's writes from the next, so the mechanism
  /// is exercised on every run rather than only when somebody taps reset.
  ///
  /// Idempotent: calling it again does nothing, so a test that calls it in
  /// `setUp` cannot accidentally re-baseline a dirty dataset.
  static void captureSeed() {
    _seed ??= _Seed.capture();
  }

  /// Puts the demo back exactly as it shipped.
  ///
  /// A client demo gets walked several times in one sitting, and the second
  /// walkthrough should not start from the first one's leftovers. Without this
  /// the only way back is a hot restart, which is not something to do in front
  /// of anybody.
  static void reset() {
    final seed = _seed;
    assert(
      seed != null,
      'MockWrite.reset() before captureSeed() would restore whatever the data '
      'happened to look like at first write. Call captureSeed() from main().',
    );
    if (seed == null) return;

    seed.restore();
    MockSettings.reset();
    _writes = 0;
    revision.value++;
  }

  /// Test-only: forgets the snapshot so a fresh one can be taken.
  @visibleForTesting
  static void debugClearSeed() {
    _seed = null;
    _writes = 0;
  }
}

/// A copy of every list a mutation can touch.
///
/// Listed explicitly rather than discovered, so adding a new mutable mock list
/// without adding it here is a compile-time-visible omission rather than a
/// silent hole in the reset.
class _Seed {
  const _Seed({
    required this.categories,
    required this.units,
    required this.items,
    required this.suppliers,
    required this.supplierPrices,
    required this.priceHistory,
    required this.movements,
    required this.orders,
    required this.receipts,
    required this.notifications,
    required this.stores,
    required this.employees,
  });

  factory _Seed.capture() => _Seed(
    categories: List.of(mockCategories),
    units: List.of(mockUnits),
    items: List.of(mockItems),
    suppliers: List.of(mockSuppliers),
    supplierPrices: List.of(mockSupplierPrices),
    priceHistory: List.of(mockPriceHistory),
    movements: List.of(mockStockMovements),
    orders: List.of(mockPurchaseOrders),
    receipts: List.of(mockGoodsReceipts),
    notifications: List.of(mockNotifications),
    stores: List.of(mockStores),
    employees: List.of(mockEmployees),
  );

  final List<Category> categories;
  final List<UnitOfMeasure> units;
  final List<Item> items;
  final List<Supplier> suppliers;
  final List<SupplierPrice> supplierPrices;
  final List<PriceHistoryEntry> priceHistory;
  final List<StockMovement> movements;
  final List<PurchaseOrder> orders;
  final List<GoodsReceipt> receipts;
  final List<NotificationItem> notifications;
  final List<Store> stores;
  final List<Employee> employees;

  void restore() {
    _replace(mockCategories, categories);
    _replace(mockUnits, units);
    _replace(mockItems, items);
    _replace(mockSuppliers, suppliers);
    _replace(mockSupplierPrices, supplierPrices);
    _replace(mockPriceHistory, priceHistory);
    _replace(mockStockMovements, movements);
    _replace(mockPurchaseOrders, orders);
    _replace(mockGoodsReceipts, receipts);
    _replace(mockNotifications, notifications);
    _replace(mockStores, stores);
    _replace(mockEmployees, employees);
  }

  /// Refills the live list in place rather than reassigning it — the mock lists
  /// are top-level finals that screens and queries hold references to.
  static void _replace<T>(List<T> live, List<T> seed) {
    live
      ..clear()
      ..addAll(seed);
  }
}

/// Exposes [MockWrite.revision] to the widget tree.
///
/// Screens that show anything a write can change watch this, so a change made
/// on one screen is visible on the one underneath it.
class MockDataRevision extends Notifier<int> {
  @override
  int build() {
    void listener() => state = MockWrite.revision.value;
    MockWrite.revision.addListener(listener);
    ref.onDispose(() => MockWrite.revision.removeListener(listener));
    return MockWrite.revision.value;
  }
}

final mockDataRevisionProvider = NotifierProvider<MockDataRevision, int>(
  MockDataRevision.new,
);
