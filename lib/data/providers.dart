import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'database/app_database.dart';
import 'employee_photo_store.dart';
import 'repositories/repositories.dart';
import 'view_models/view_models.dart';

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

final Provider<SessionRepository> sessionRepositoryProvider =
    Provider<SessionRepository>(
      (ref) => SessionRepository(ref.watch(databaseProvider)),
    );

final Provider<EmployeeRepository> employeeRepositoryProvider =
    Provider<EmployeeRepository>(
      (ref) => EmployeeRepository(ref.watch(databaseProvider)),
    );

final Provider<CredentialRepository> credentialRepositoryProvider =
    Provider<CredentialRepository>(
      (ref) => CredentialRepository(ref.watch(databaseProvider)),
    );

/// The pointage clock. `DateTime.now` in the app; a test overrides it with a
/// fixed function so an employee can clock in at 07:45 and out at 17:00 without
/// wall-clock time passing.
final Provider<DateTime Function()> attendanceClockProvider =
    Provider<DateTime Function()>((ref) => DateTime.now);

final Provider<AttendanceRepository> attendanceRepositoryProvider =
    Provider<AttendanceRepository>(
      (ref) => AttendanceRepository(
        ref.watch(databaseProvider),
        clock: ref.watch(attendanceClockProvider),
      ),
    );

final Provider<PayrollRepository> payrollRepositoryProvider =
    Provider<PayrollRepository>(
      (ref) => PayrollRepository(ref.watch(databaseProvider)),
    );

/// Where a chosen employee photo file is copied and looked up. Holds no state;
/// the default reaches the OS app-support directory, a test overrides it.
final Provider<EmployeePhotoStore> employeePhotoStoreProvider =
    Provider<EmployeePhotoStore>((ref) => EmployeePhotoStore());

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

/// An establishment and a number of days back — the reports' window.
typedef StoreWindowKey = ({String storeId, int days});

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

/// The selector grid: every establishment with its article and alert counts.
final storeCardsProvider = StreamProvider<List<StoreCardView>>(
  (ref) => ref.watch(storeRepositoryProvider).watchStoreCards(),
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

/// The establishment's full settings row — pointage hours, break allowance,
/// payroll coefficients and the stale-order threshold. The store settings
/// screen edits it; the pointage KPIs and payroll read it.
final storeSettingsProvider = StreamProvider.family<StoreSettings, String>(
  (ref, storeId) => ref.watch(storeRepositoryProvider).watchSettings(storeId),
);

// --- Catalogue ---------------------------------------------------------------

final categoriesProvider = StreamProvider.family<List<Category>, String>(
  (ref, storeId) =>
      ref.watch(catalogRepositoryProvider).watchCategories(storeId),
);

/// The categories screen: each with the number of articles filed under it.
final categoryRowsProvider =
    StreamProvider.family<List<CategoryRowView>, String>(
      (ref, storeId) =>
          ref.watch(catalogRepositoryProvider).watchCategoryRows(storeId),
    );

final unitsProvider = StreamProvider.family<List<UnitOfMeasure>, String>(
  (ref, storeId) => ref.watch(catalogRepositoryProvider).watchUnits(storeId),
);

/// The units screen: each with the number of articles measured in it.
final unitRowsProvider = StreamProvider.family<List<UnitRowView>, String>(
  (ref, storeId) => ref.watch(catalogRepositoryProvider).watchUnitRows(storeId),
);

// --- Articles ----------------------------------------------------------------

/// The inventory list, and with a low-stock filter the alerts screen: worst
/// status first, then alphabetical.
final itemsProvider = StreamProvider.family<List<Item>, ItemQuery>(
  (ref, query) => ref
      .watch(itemRepositoryProvider)
      .watchItems(query.storeId, filter: query.filter),
);

/// The inventory list, with each row's category name and unit already resolved.
final itemRowsProvider = StreamProvider.family<List<ItemRowView>, ItemQuery>(
  (ref, query) => ref
      .watch(itemRepositoryProvider)
      .watchItemRows(query.storeId, filter: query.filter),
);

/// The low-stock screen: what needs attention, with the supplier who would fill
/// it and how much is already on its way.
final lowStockAlertsProvider =
    StreamProvider.family<List<LowStockAlertView>, String>(
      (ref, storeId) =>
          ref.watch(itemRepositoryProvider).watchLowStockAlerts(storeId),
    );

/// Every article in the establishment, alphabetically — for the callers that do
/// their own ordering, where "worst first" would be noise.
final itemsByNameProvider = StreamProvider.family<List<Item>, String>(
  (ref, storeId) => ref.watch(itemRepositoryProvider).watchItemsByName(storeId),
);

/// One article with its category and unit named — the detail screen's header.
final itemRowProvider = StreamProvider.family<ItemRowView?, String>(
  (ref, id) => ref.watch(itemRepositoryProvider).watchItemRow(id),
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

/// The suppliers list, with each row's article count.
final supplierRowsProvider =
    StreamProvider.family<List<SupplierRowView>, String>(
      (ref, storeId) =>
          ref.watch(supplierRepositoryProvider).watchSupplierRows(storeId),
    );

/// Everything one supplier offers, with the best price on the market alongside.
final supplierProductsProvider =
    StreamProvider.family<List<SupplierProductView>, String>(
      (ref, supplierId) => ref
          .watch(supplierRepositoryProvider)
          .watchSupplierProducts(supplierId),
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

/// Every supplier of one article, named, and what the default costs extra.
final itemPricingProvider = StreamProvider.family<ItemPricing, String>(
  (ref, itemId) => ref.watch(supplierRepositoryProvider).watchPricing(itemId),
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

/// The movement log, with each line's article, unit, supplier and commande
/// already resolved.
final movementRowsForStoreProvider =
    StreamProvider.family<List<MovementRowView>, String>(
      (ref, storeId) => ref
          .watch(movementRepositoryProvider)
          .watchMovementRowsForStore(storeId),
    );

/// The same for one article — the recent-activity strip on its detail page.
final movementRowsForItemProvider =
    StreamProvider.family<List<MovementRowView>, String>(
      (ref, itemId) => ref
          .watch(movementRepositoryProvider)
          .watchMovementRowsForItem(itemId, limit: 6),
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

/// Commandes sitting in `partial` past this establishment's threshold.
///
/// A `FutureProvider` because the rule reads a column and the clock: "stale"
/// depends on how long ago a commande went partial, and no table change makes
/// yesterday's answer wrong. It re-runs when the screen is rebuilt, which for a
/// warning measured in days is often enough.
final staleOrdersProvider =
    FutureProvider.family<List<PurchaseOrder>, String>(
      (ref, storeId) => ref.watch(orderRepositoryProvider).staleOrders(storeId),
    );

/// The commandes list, with each row's supplier named.
final orderRowsProvider = StreamProvider.family<List<OrderRowView>, String>(
  (ref, storeId) => ref.watch(orderRepositoryProvider).watchOrderRows(storeId),
);

/// Every commande ever placed with one supplier, newest first.
final ordersForSupplierProvider =
    StreamProvider.family<List<OrderRowView>, String>(
      (ref, supplierId) => ref
          .watch(orderRepositoryProvider)
          .watchOrderRowsForSupplier(supplierId),
    );

/// The open ones, named the same way.
final openOrderRowsProvider = StreamProvider.family<List<OrderRowView>, String>(
  (ref, storeId) =>
      ref.watch(orderRepositoryProvider).watchOpenOrderRows(storeId),
);

/// The commande detail screen: the document, its supplier, its lines and its
/// deliveries, as one value.
final orderDetailProvider = StreamProvider.family<OrderDetailView?, String>(
  (ref, orderId) =>
      ref.watch(orderRepositoryProvider).watchOrderDetail(orderId),
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

/// What is still owed of one article, and which commandes owe it.
final itemOnOrderProvider = StreamProvider.family<ItemOnOrder, StoreItemKey>(
  (ref, key) => ref
      .watch(orderRepositoryProvider)
      .watchItemOnOrder(key.storeId, key.itemId),
);

/// One delivery, with its reference and every line's article named.
///
/// A `FutureProvider`: a receipt never changes once it is written, so there is
/// nothing here for a stream to deliver twice.
final receiptDetailProvider =
    FutureProvider.family<ReceiptDetailView?, String>(
      (ref, receiptId) =>
          ref.watch(orderRepositoryProvider).receiptDetail(receiptId),
    );

/// The deliveries against one commande, **oldest first** — the order the
/// `BR-2026-014/2` numbering derives from.
final receiptsForOrderProvider =
    StreamProvider.family<List<GoodsReceipt>, String>(
      (ref, orderId) =>
          ref.watch(orderRepositoryProvider).watchReceiptsForOrder(orderId),
    );

// --- Notifications ----------------------------------------------------------

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

/// When the local dataset was last written wholesale — the honest version of
/// the sync screen's "last synchronised".
final seededAtProvider = StreamProvider<DateTime?>(
  (ref) => ref.watch(demoRepositoryProvider).watchSeededAt(),
);

// --- Reports -----------------------------------------------------------------

/// The valuation report, by category and by article. Both are one query each,
/// and both carry each row's share of the total.
final valuationByCategoryProvider =
    FutureProvider.family<List<ValuationRow>, String>(
      (ref, storeId) =>
          ref.watch(reportRepositoryProvider).valuationByCategory(storeId),
    );

final valuationByItemProvider =
    FutureProvider.family<List<ValuationRow>, String>(
      (ref, storeId) =>
          ref.watch(reportRepositoryProvider).valuationByItem(storeId),
    );

/// What left the establishment in the window, at what it cost.
final consumptionValueProvider = FutureProvider.family<double, StoreWindowKey>(
  (ref, key) => ref
      .watch(reportRepositoryProvider)
      .consumptionValue(key.storeId, from: _daysAgo(key.days)),
);

/// The part of that which was thrown away or spoiled.
final wasteValueProvider = FutureProvider.family<double, StoreWindowKey>(
  (ref, key) => ref
      .watch(reportRepositoryProvider)
      .wasteValue(key.storeId, from: _daysAgo(key.days)),
);

/// Weekly outbound value, oldest first — the two trend charts.
final usageTrendProvider = FutureProvider.family<List<TrendPoint>, String>(
  (ref, storeId) => ref.watch(reportRepositoryProvider).usageTrend(storeId),
);

final wasteTrendProvider = FutureProvider.family<List<TrendPoint>, String>(
  (ref, storeId) => ref.watch(reportRepositoryProvider).wasteTrend(storeId),
);

/// What a year of the current overpayment would cost — the reports dashboard's
/// headline number.
final potentialAnnualSavingProvider = FutureProvider.family<double, String>(
  (ref, storeId) =>
      ref.watch(reportRepositoryProvider).potentialAnnualSaving(storeId),
);

/// The article with the biggest gap between what the establishment pays and
/// what it could — where the price comparison report opens.
final largestOverpayItemProvider = FutureProvider.family<String?, String>(
  (ref, storeId) =>
      ref.watch(reportRepositoryProvider).largestOverpayItemId(storeId),
);

/// The headline figure: everything in the establishment, at what it cost.
final stockValuationProvider = StreamProvider.family<double, String>(
  (ref, storeId) =>
      ref.watch(reportRepositoryProvider).watchStockValuation(storeId),
);


/// A window's start, from a number of days back.
///
/// Here rather than at each call site so every report measures its window the
/// same way — from this instant, not from midnight.
DateTime _daysAgo(int days) => DateTime.now().subtract(Duration(days: days));

// --- Gestion Employée ------------------------------------------------------

/// The roster, worst-status-first then by name; the archived people included.
final employeesProvider = StreamProvider.family<List<Employee>, String>(
  (ref, storeId) =>
      ref.watch(employeeRepositoryProvider).watchEmployees(storeId),
);

/// The roster without the archived — the pointage board and the paie pickers.
final activeEmployeesProvider = StreamProvider.family<List<Employee>, String>(
  (ref, storeId) =>
      ref.watch(employeeRepositoryProvider).watchActiveEmployees(storeId),
);

/// One employee — the detail screen's header.
final employeeProvider = StreamProvider.family<Employee?, String>(
  (ref, id) => ref.watch(employeeRepositoryProvider).watchEmployee(id),
);

/// One employee's login credential, for the detail screen's security row.
final credentialForEmployeeProvider =
    FutureProvider.family<EmployeeCredential?, String>(
      (ref, employeeId) =>
          ref.watch(credentialRepositoryProvider).forEmployee(employeeId),
    );

/// One employee's attendance history — most recent day first.
final attendanceForEmployeeProvider =
    StreamProvider.family<List<Attendance>, String>(
      (ref, employeeId) => ref
          .watch(attendanceRepositoryProvider)
          .watchForEmployee(employeeId),
    );

/// Today's attendance row for one employee — the pointage board card.
final attendanceTodayProvider = StreamProvider.family<Attendance?, String>(
  (ref, employeeId) =>
      ref.watch(attendanceRepositoryProvider).watchToday(employeeId),
);

/// Every today's-row for a store, keyed by employee id — the pointage board
/// joins this against `activeEmployeesProvider`.
final attendanceBoardProvider =
    StreamProvider.family<Map<String, Attendance>, String>(
      (ref, storeId) => ref
          .watch(attendanceRepositoryProvider)
          .watchTodayForStore(storeId),
    );

/// The filter bundle for the Historique de pointage table.
typedef AttendanceLogKey = ({
  String storeId,
  DateTime? from,
  DateTime? to,
  AttendanceStatus? status,
  String? employeeId,
  int page,
});

final attendancePageProvider =
    StreamProvider.family<AttendancePage, AttendanceLogKey>(
      (ref, key) => ref.watch(attendanceRepositoryProvider).watchPage(
        key.storeId,
        from: key.from,
        to: key.to,
        status: key.status,
        employeeId: key.employeeId,
        page: key.page,
      ),
    );

/// The KPI header above the Historique de pointage table — over the whole
/// range, independent of the status and page filters.
final attendanceStatsProvider =
    FutureProvider.family<AttendanceStats, AttendanceLogKey>(
      (ref, key) => ref.watch(attendanceRepositoryProvider).stats(
        key.storeId,
        from: key.from,
        to: key.to,
        employeeId: key.employeeId,
      ),
    );

/// One employee's paid payroll periods — most recent first.
final payrollForEmployeeProvider =
    StreamProvider.family<List<PayrollPeriod>, String>(
      (ref, employeeId) =>
          ref.watch(payrollRepositoryProvider).watchForEmployee(employeeId),
    );

/// The filter bundle for the Historique de paiement day table.
typedef PayrollDaysKey = ({
  String storeId,
  String? employeeId,
  DateTime? from,
  DateTime? to,
  PaymentStatus? status,
  int page,
});

/// A `FutureProvider`: the day view is heavy and the paie flow that changes it
/// is an explicit user action, so the screen invalidates this after a `pay`
/// rather than holding a live fold open.
final payrollDaysProvider =
    FutureProvider.family<PayrollDays, PayrollDaysKey>(
      (ref, key) => ref.watch(payrollRepositoryProvider).days(
        key.storeId,
        employeeId: key.employeeId,
        from: key.from,
        to: key.to,
        status: key.status,
        page: key.page,
      ),
    );

/// The filter bundle for the paginated payroll-period list.
typedef PayrollPageKey = ({
  String storeId,
  int? withinDays,
  String? employeeQuery,
  int page,
});

final payrollPageProvider =
    FutureProvider.family<PayrollPage, PayrollPageKey>(
      (ref, key) => ref.watch(payrollRepositoryProvider).page(
        key.storeId,
        withinDays: key.withinDays,
        employeeQuery: key.employeeQuery,
        page: key.page,
      ),
    );
