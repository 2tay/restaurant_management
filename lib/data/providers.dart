import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'database/app_database.dart';
import 'repositories/repositories.dart';

/// The database, and the single point at which it is injected.
///
/// It has no default: `main()` overrides it with the opened file, and every test
/// overrides it with `AppDatabase.memory()`. A provider that could quietly build
/// its own would let a test run against the developer's real data, and would let
/// a forgotten override ship.
///
/// Everything below is built from it: the repositories, and one provider per
/// screen-level query.
final Provider<AppDatabase> databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError(
    'databaseProvider has no default. Override it in ProviderScope with the '
    'database from openAppDatabase(), or with AppDatabase.memory() in a test.',
  );
});

/// One provider per repository. They hold no state of their own — a repository
/// is a set of queries over the database — so they are plain `Provider`s built
/// from [databaseProvider] and nothing else.

final Provider<StoreRepository> storeRepositoryProvider =
    Provider<StoreRepository>((ref) => StoreRepository(ref.watch(databaseProvider)));

final Provider<CatalogRepository> catalogRepositoryProvider =
    Provider<CatalogRepository>(
      (ref) => CatalogRepository(ref.watch(databaseProvider)),
    );

final Provider<ItemRepository> itemRepositoryProvider =
    Provider<ItemRepository>((ref) => ItemRepository(ref.watch(databaseProvider)));

final Provider<SupplierRepository> supplierRepositoryProvider =
    Provider<SupplierRepository>(
      (ref) => SupplierRepository(ref.watch(databaseProvider)),
    );

final Provider<MovementRepository> movementRepositoryProvider =
    Provider<MovementRepository>(
      (ref) => MovementRepository(ref.watch(databaseProvider)),
    );

final Provider<OrderRepository> orderRepositoryProvider =
    Provider<OrderRepository>(
      (ref) => OrderRepository(ref.watch(databaseProvider)),
    );

final Provider<AccountRepository> accountRepositoryProvider =
    Provider<AccountRepository>(
      (ref) => AccountRepository(ref.watch(databaseProvider)),
    );

final Provider<ReportRepository> reportRepositoryProvider =
    Provider<ReportRepository>(
      (ref) => ReportRepository(ref.watch(databaseProvider)),
    );

final Provider<DemoRepository> demoRepositoryProvider =
    Provider<DemoRepository>((ref) => DemoRepository(ref.watch(databaseProvider)));

// =============================================================================
// Screen-level queries
// =============================================================================
//
// One provider per query a screen actually makes, keyed the way that screen
// keys it. They exist so a widget names what it needs — `itemsProvider(...)` —
// instead of holding a repository and remembering to re-run a method whenever
// something might have changed.
//
// **They are streams because drift's `watch()` is a stream.** A write anywhere
// in the app re-runs every query whose tables it touched, and the screens that
// were watching rebuild themselves. That is what replaces
// `mockDataRevisionProvider`: the database says what changed, so nothing needs
// a global "something happened" counter and no screen can forget to read it.
//
// The rule for what belongs here: a query a *screen* makes. A lookup a *form*
// makes once, on submit — `barcodeConflict`, `deleteBlockedBy`,
// `receiveBlockedBy` — stays a `Future` on the repository and is awaited in the
// handler. Wrapping those would hold a live subscription open for an answer
// that is only wanted at one instant.
//
// Two-key queries take a **record** as their key. Records have structural
// equality, which is exactly what a family needs: `(storeId: s, itemId: i)`
// built twice is the same key, so a rebuilding screen keeps its subscription
// instead of tearing it down and opening another.

/// An establishment and one of its suppliers.
typedef StoreSupplierKey = ({String storeId, String supplierId});

/// An establishment and one of its articles.
typedef StoreItemKey = ({String storeId, String itemId});

/// An article and one supplier of it — the price history screen's key.
typedef ItemSupplierKey = ({String itemId, String supplierId});

/// The inventory list's query: an establishment, and the filters above it.
///
/// [ItemFilter] carries value equality for this reason alone. Without it a
/// rebuilding screen would construct an equal-but-not-identical filter and
/// Riverpod would read it as a different query.
typedef ItemQuery = ({String storeId, ItemFilter filter});

// --- Establishments ----------------------------------------------------------

final StreamProvider<List<Store>> storesProvider = StreamProvider<List<Store>>(
  (ref) => ref.watch(storeRepositoryProvider).watchStores(),
);

final storeProvider = StreamProvider.family<Store?, String>(
  (ref, id) => ref.watch(storeRepositoryProvider).watchStore(id),
);

/// The establishment the shell is showing, resolved from the route parameter.
///
/// Null-tolerant in both directions. A null key means "whichever is first",
/// which is how the app opens before a store has been chosen; a key that does
/// not resolve also falls back to the first, so a stale bookmark shows the app
/// rather than an error. A null *result* means there are genuinely no
/// establishments — something a database can be and the mock lists never were.
final currentStoreProvider = StreamProvider.family<Store?, String?>(
  (ref, id) => ref.watch(storeRepositoryProvider).watchStoreOrFirst(id),
);

/// How many days a partial commande may sit before the dashboard flags it.
final stalePartialOrderDaysProvider = FutureProvider.family<int, String>(
  (ref, storeId) =>
      ref.watch(storeRepositoryProvider).stalePartialOrderDays(storeId),
);

// --- Catalogue ---------------------------------------------------------------

final categoriesProvider = StreamProvider.family<List<Category>, String>(
  (ref, storeId) =>
      ref.watch(catalogRepositoryProvider).watchCategories(storeId),
);

final unitsProvider = StreamProvider.family<List<UnitOfMeasure>, String>(
  (ref, storeId) => ref.watch(catalogRepositoryProvider).watchUnits(storeId),
);

// --- Articles ----------------------------------------------------------------

/// The inventory list, and with a low-stock filter the alerts screen: worst
/// status first, then alphabetical.
final itemsProvider = StreamProvider.family<List<Item>, ItemQuery>(
  (ref, query) => ref
      .watch(itemRepositoryProvider)
      .watchItems(query.storeId, filter: query.filter),
);

/// Every article in the establishment, alphabetically — for the callers that do
/// their own ordering, where "worst first" would be noise.
final itemsByNameProvider = StreamProvider.family<List<Item>, String>(
  (ref, storeId) => ref.watch(itemRepositoryProvider).watchItemsByName(storeId),
);

final itemProvider = StreamProvider.family<Item?, String>(
  (ref, id) => ref.watch(itemRepositoryProvider).watchItem(id),
);

/// The order line picker: what this supplier sells.
final itemsSuppliedByProvider =
    StreamProvider.family<List<Item>, StoreSupplierKey>(
      (ref, key) => ref
          .watch(itemRepositoryProvider)
          .watchItemsSuppliedBy(key.storeId, key.supplierId),
    );

/// The suggestion panel: what this supplier sells that is running low.
final suggestedItemsProvider =
    StreamProvider.family<List<Item>, StoreSupplierKey>(
      (ref, key) => ref
          .watch(itemRepositoryProvider)
          .watchSuggestedItems(key.storeId, key.supplierId),
    );

// --- Suppliers and prices ----------------------------------------------------

final suppliersProvider = StreamProvider.family<List<Supplier>, String>(
  (ref, storeId) =>
      ref.watch(supplierRepositoryProvider).watchSuppliers(storeId),
);

final supplierProvider = StreamProvider.family<Supplier?, String>(
  (ref, id) => ref.watch(supplierRepositoryProvider).watchSupplier(id),
);

/// Every supplier offering this article, **cheapest first**.
final pricesForItemProvider =
    StreamProvider.family<List<SupplierPrice>, String>(
      (ref, itemId) =>
          ref.watch(supplierRepositoryProvider).watchPricesForItem(itemId),
    );

final priceHistoryProvider =
    StreamProvider.family<List<PriceHistoryEntry>, ItemSupplierKey>(
      (ref, key) => ref
          .watch(supplierRepositoryProvider)
          .watchPriceHistory(key.itemId, key.supplierId),
    );

// --- Movements ---------------------------------------------------------------

final movementsProvider = StreamProvider.family<List<StockMovement>, String>(
  (ref, storeId) =>
      ref.watch(movementRepositoryProvider).watchMovementsForStore(storeId),
);

final movementsForItemProvider =
    StreamProvider.family<List<StockMovement>, String>(
      (ref, itemId) =>
          ref.watch(movementRepositoryProvider).watchMovementsForItem(itemId),
    );

/// The dashboard's activity feed — the most recent handful.
final recentActivityProvider =
    StreamProvider.family<List<StockMovement>, String>(
      (ref, storeId) =>
          ref.watch(movementRepositoryProvider).watchRecentActivity(storeId),
    );

// --- Commandes ---------------------------------------------------------------

final ordersProvider = StreamProvider.family<List<PurchaseOrder>, String>(
  (ref, storeId) => ref.watch(orderRepositoryProvider).watchOrders(storeId),
);

final orderProvider = StreamProvider.family<PurchaseOrder?, String>(
  (ref, id) => ref.watch(orderRepositoryProvider).watchOrder(id),
);

/// Sent and partial — what is still owed to the establishment.
final openOrdersProvider = StreamProvider.family<List<PurchaseOrder>, String>(
  (ref, storeId) => ref.watch(orderRepositoryProvider).watchOpenOrders(storeId),
);

final openOrdersForItemProvider =
    StreamProvider.family<List<PurchaseOrder>, StoreItemKey>(
      (ref, key) => ref
          .watch(orderRepositoryProvider)
          .watchOpenOrdersForItem(key.storeId, key.itemId),
    );

/// How much of this article is already on its way, so nobody orders it twice.
final onOrderQuantityProvider = StreamProvider.family<double, StoreItemKey>(
  (ref, key) => ref
      .watch(orderRepositoryProvider)
      .watchOnOrderQuantity(key.storeId, key.itemId),
);

/// The deliveries against one commande, **oldest first** — the order the
/// `BR-2026-014/2` numbering derives from.
final receiptsForOrderProvider =
    StreamProvider.family<List<GoodsReceipt>, String>(
      (ref, orderId) =>
          ref.watch(orderRepositoryProvider).watchReceiptsForOrder(orderId),
    );

// --- Team and notifications --------------------------------------------------

final StreamProvider<List<TeamMember>> teamProvider =
    StreamProvider<List<TeamMember>>(
      (ref) => ref.watch(accountRepositoryProvider).watchTeam(),
    );

final teamForStoreProvider = StreamProvider.family<List<TeamMember>, String>(
  (ref, storeId) =>
      ref.watch(accountRepositoryProvider).watchTeamForStore(storeId),
);

final notificationsProvider =
    StreamProvider.family<List<NotificationItem>, String>(
      (ref, storeId) =>
          ref.watch(accountRepositoryProvider).watchNotifications(storeId),
    );

/// The number on the bell.
final unreadCountProvider = StreamProvider.family<int, String>(
  (ref, storeId) =>
      ref.watch(accountRepositoryProvider).watchUnreadCount(storeId),
);

/// Who the app thinks is using it.
///
/// The implicit actor stamped on every movement and every price change. Phase 1
/// resolved it once at library load from the first team member; it is a `meta`
/// row now. A `FutureProvider` rather than a stream because it changes when
/// somebody signs in, which is Phase 3's business — not a write this app makes
/// while it is running.
final FutureProvider<TeamMember?> currentUserProvider =
    FutureProvider<TeamMember?>(
      (ref) => ref.watch(accountRepositoryProvider).currentUser(),
    );

// --- Reports -----------------------------------------------------------------

/// The headline figure: everything in the establishment, at what it cost.
final stockValuationProvider = StreamProvider.family<double, String>(
  (ref, storeId) =>
      ref.watch(reportRepositoryProvider).watchStockValuation(storeId),
);
