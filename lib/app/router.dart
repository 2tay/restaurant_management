import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers.dart';
import '../dev/theme_gallery_page.dart';
import '../features/alerts/presentation/pages/low_stock_alerts_page.dart';
import '../features/alerts/presentation/pages/notifications_page.dart';
import '../features/dashboard/presentation/pages/store_dashboard_page.dart';
import '../features/employees/presentation/pages/add_edit_employee_page.dart';
import '../features/employees/presentation/pages/attendance_history_page.dart';
import '../features/employees/presentation/pages/employee_detail_page.dart';
import '../features/employees/presentation/pages/employees_list_page.dart';
import '../features/employees/presentation/pages/payroll_history_page.dart';
import '../features/employees/presentation/pages/timeclock_board_page.dart';
import '../features/reports/presentation/pages/price_comparison_report_page.dart';
import '../features/reports/presentation/pages/reports_dashboard_page.dart';
import '../features/reports/presentation/pages/stock_valuation_report_page.dart';
import '../features/reports/presentation/pages/usage_report_page.dart';
import '../features/search/presentation/pages/global_search_page.dart';
import '../features/settings/presentation/pages/account_settings_page.dart';
import '../features/settings/presentation/pages/notification_preferences_page.dart';
import '../features/settings/presentation/pages/store_settings_page.dart';
import '../features/settings/presentation/pages/sync_status_page.dart';
import '../features/auth/presentation/pages/forgot_password_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/onboarding_page.dart';
import '../features/catalog/presentation/pages/categories_page.dart';
import '../features/catalog/presentation/pages/units_page.dart';
import '../features/inventory/presentation/pages/add_edit_item_page.dart';
import '../features/inventory/presentation/pages/inventory_list_page.dart';
import '../features/inventory/presentation/pages/item_detail_page.dart';
import '../features/inventory/presentation/pages/item_price_history_page.dart';
import '../features/inventory/presentation/pages/link_supplier_to_item_page.dart';
import '../features/orders/presentation/pages/create_order_page.dart';
import '../features/orders/presentation/pages/edit_order_page.dart';
import '../features/orders/presentation/pages/order_detail_page.dart';
import '../features/orders/presentation/pages/orders_list_page.dart';
import '../features/orders/presentation/pages/receipt_detail_page.dart';
import '../features/orders/presentation/pages/receive_order_page.dart';
import '../features/stores/presentation/pages/add_store_page.dart';
import '../features/stock_movement/presentation/pages/stock_adjustment_page.dart';
import '../features/stock_movement/presentation/pages/stock_history_page.dart';
import '../features/stock_movement/presentation/pages/stock_in_page.dart';
import '../features/stock_movement/presentation/pages/stock_out_page.dart';
import '../features/stores/presentation/pages/store_selector_page.dart';
import '../features/suppliers/presentation/pages/add_edit_supplier_page.dart';
import '../features/suppliers/presentation/pages/supplier_detail_page.dart';
import '../features/suppliers/presentation/pages/supplier_pricing_page.dart';
import '../features/suppliers/presentation/pages/suppliers_list_page.dart';
import '../core/utils/permissions.dart';
import '../data/current_employee.dart';
import '../models/models.dart';
import '../shared/widgets/app_scaffold.dart';
import 'page_transitions.dart';
import 'routes.dart';

/// The application router.
///
/// Two route groups:
///
/// - **Outside the shell** — login, password reset, onboarding and the store
///   selector. These have no navigation rail, because there is no store context
///   to navigate within yet.
/// - **Inside the [ShellRoute]** — everything store-scoped, under
///   `/store/:storeId/`. The shell resolves the store once and hands it to
///   [AppScaffold], so the rail and top bar persist across navigations.
///

/// Pulls the store id out of a store-scoped route.
///
/// The `!` is safe: every route using this sits under `/store/:storeId/`, so
/// go_router cannot match it without the parameter present.
String _storeId(GoRouterState state) => state.pathParameters['storeId']!;

/// The screens reachable without a session.
const Set<String> _authRoutes = {
  Routes.login,
  Routes.forgotPassword,
  Routes.onboarding,
};

/// The capability a location requires, or null when it is open to any
/// signed-in non-staff user. Store settings is deliberately absent — its route
/// stays open and only the "Enregistrer" button is gated, so a manager is not
/// bounced out of the settings section.
Capability? _capabilityFor(String location) {
  if (location == Routes.addStore) return Capability.createStore;
  if (location.contains('/employees/timeclock')) {
    return Capability.viewTimeclock;
  }
  if (location.contains('/employees/attendance-history')) {
    return Capability.viewAttendanceHistory;
  }
  if (location.contains('/employees/payroll')) {
    return Capability.managePayroll;
  }
  if (location.contains('/employees')) return Capability.manageEmployees;
  return null;
}

/// The auth + permission guard (Phase 6).
///
/// - no session → every route but [_authRoutes] redirects to the login
/// - a `staff` session (which the app never actually issues) → back to login
/// - a session on an auth screen → home (the grid for the owner, their store
///   dashboard for a manager)
/// - a store the user does not belong to, or a section the role cannot hold
///   → home
String? _guard(BuildContext context, GoRouterState state) {
  final location = state.matchedLocation;

  // Read synchronously — `currentEmployeeSnapshot` is resolved before the first
  // frame (`main()` awaits `hydrate()`; the widget-test fixtures seed it) and
  // kept in step with `currentEmployeeProvider` by its notifier.
  final employee = currentEmployeeSnapshot;

  if (employee == null) {
    return _authRoutes.contains(location) ? null : Routes.login;
  }

  // Staff have no active app access — they should never hold a session.
  if (employee.role == EmployeeRole.staff) {
    return location == Routes.login ? null : Routes.login;
  }

  final spansStores = can(employee.role, Capability.spanAllStores);

  // Where a signed-in user lands when they have no valid store target: the
  // owner picks from the grid, everyone else goes straight to their store.
  final home = spansStores
      ? Routes.stores
      : Routes.toDashboard(employee.storeId);

  // On an auth screen, or on the store grid without the right to span stores.
  if (_authRoutes.contains(location)) return home;
  if (location == Routes.stores && !spansStores) return home;

  // A store-scoped route for a store this user does not belong to.
  final storeId = state.pathParameters['storeId'];
  if (storeId != null && !canAccessStore(employee, storeId)) return home;

  // A section the role cannot hold.
  final needed = _capabilityFor(location);
  if (needed != null && !can(employee.role, needed)) return home;

  return null;
}

final GoRouter appRouter = GoRouter(
  initialLocation: Routes.login,
  debugLogDiagnostics: false,
  redirect: _guard,
  routes: [
    // -------------------------------------------------------------------------
    // Auth and store selection — no shell
    // -------------------------------------------------------------------------
    GoRoute(path: Routes.login, builder: (context, state) => const LoginPage()),
    GoRoute(
      path: Routes.forgotPassword,
      builder: (context, state) => const ForgotPasswordPage(),
    ),
    GoRoute(
      path: Routes.onboarding,
      builder: (context, state) => const OnboardingPage(),
    ),
    GoRoute(
      path: Routes.stores,
      builder: (context, state) => const StoreSelectorPage(),
    ),
    GoRoute(
      path: Routes.addStore,
      builder: (context, state) => const AddStorePage(),
    ),

    // Development only. Reachable at /dev/gallery, linked from nothing —
    // it is a reference for whoever is building screens, not a feature.
    GoRoute(
      path: Routes.devGallery,
      builder: (context, state) => const ThemeGalleryPage(),
    ),

    // -------------------------------------------------------------------------
    // Store-scoped — inside the shell
    // -------------------------------------------------------------------------
    ShellRoute(
      builder: (context, state, child) =>
          _StoreShell(storeId: state.pathParameters['storeId'], child: child),
      routes: [
        GoRoute(
          path: Routes.dashboard,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: StoreDashboardPage(storeId: _storeId(state)),
          ),
        ),

        // --- Inventory -------------------------------------------------------
        //
        // `new` is declared before `:itemId` because go_router matches in
        // order — otherwise "new" would be read as an item id.
        GoRoute(
          path: Routes.inventory,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: InventoryListPage(storeId: _storeId(state)),
          ),
        ),
        GoRoute(
          path: Routes.addItem,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: AddEditItemPage(storeId: _storeId(state)),
          ),
        ),
        GoRoute(
          path: Routes.itemDetail,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: ItemDetailPage(
              storeId: _storeId(state),
              itemId: state.pathParameters['itemId']!,
            ),
          ),
        ),
        GoRoute(
          path: Routes.editItem,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: AddEditItemPage(
              storeId: _storeId(state),
              itemId: state.pathParameters['itemId'],
            ),
          ),
        ),
        GoRoute(
          path: Routes.linkSupplier,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: LinkSupplierToItemPage(
              storeId: _storeId(state),
              itemId: state.pathParameters['itemId']!,
            ),
          ),
        ),
        GoRoute(
          path: Routes.itemPriceHistory,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: ItemPriceHistoryPage(
              storeId: _storeId(state),
              itemId: state.pathParameters['itemId']!,
              supplierId: state.pathParameters['supplierId']!,
            ),
          ),
        ),

        // --- Catalog ---------------------------------------------------------
        GoRoute(
          path: Routes.categories,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: CategoriesPage(storeId: _storeId(state)),
          ),
        ),
        GoRoute(
          path: Routes.units,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: UnitsPage(storeId: _storeId(state)),
          ),
        ),

        // --- Stock movement --------------------------------------------------
        GoRoute(
          path: Routes.movements,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: StockHistoryPage(storeId: _storeId(state)),
          ),
        ),
        GoRoute(
          path: Routes.stockIn,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: StockInPage(storeId: _storeId(state)),
          ),
        ),
        GoRoute(
          path: Routes.stockOut,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: StockOutPage(storeId: _storeId(state)),
          ),
        ),
        GoRoute(
          path: Routes.stockAdjustment,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: StockAdjustmentPage(storeId: _storeId(state)),
          ),
        ),

        // --- Alerts ----------------------------------------------------------
        GoRoute(
          path: Routes.alerts,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: LowStockAlertsPage(storeId: _storeId(state)),
          ),
        ),
        GoRoute(
          path: Routes.notifications,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: NotificationsPage(storeId: _storeId(state)),
          ),
        ),

        // --- Orders ----------------------------------------------------------
        //
        // `new` and `receipts` are declared before `:orderId` for the same
        // ordering reason as the inventory routes: go_router matches in order,
        // so a literal segment has to come first or it is read as an id.
        GoRoute(
          path: Routes.orders,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: OrdersListPage(storeId: _storeId(state)),
          ),
        ),
        GoRoute(
          path: Routes.newOrder,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            // Arriving from the low stock alerts screen carries the supplier
            // and a request to pre-fill their low items, so the manager lands
            // on a filled order rather than a blank one.
            child: CreateOrderPage(
              storeId: _storeId(state),
              initialSupplierId: state.uri.queryParameters['supplier'],
              prefillSuggested: state.uri.queryParameters['prefill'] == '1',
            ),
          ),
        ),
        GoRoute(
          path: Routes.receiptDetail,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: ReceiptDetailPage(
              storeId: _storeId(state),
              receiptId: state.pathParameters['receiptId']!,
            ),
          ),
        ),
        GoRoute(
          path: Routes.orderDetail,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: OrderDetailPage(
              storeId: _storeId(state),
              orderId: state.pathParameters['orderId']!,
            ),
          ),
        ),
        GoRoute(
          path: Routes.editOrder,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: EditOrderPage(
              storeId: _storeId(state),
              orderId: state.pathParameters['orderId']!,
            ),
          ),
        ),
        GoRoute(
          path: Routes.receiveOrder,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: ReceiveOrderPage(
              storeId: _storeId(state),
              orderId: state.pathParameters['orderId']!,
            ),
          ),
        ),

        // --- Suppliers -------------------------------------------------------
        GoRoute(
          path: Routes.suppliers,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: SuppliersListPage(storeId: _storeId(state)),
          ),
        ),
        GoRoute(
          path: Routes.addSupplier,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: AddEditSupplierPage(storeId: _storeId(state)),
          ),
        ),
        GoRoute(
          path: Routes.supplierDetail,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: SupplierDetailPage(
              storeId: _storeId(state),
              supplierId: state.pathParameters['supplierId']!,
            ),
          ),
        ),
        GoRoute(
          path: Routes.editSupplier,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: AddEditSupplierPage(
              storeId: _storeId(state),
              supplierId: state.pathParameters['supplierId'],
            ),
          ),
        ),
        GoRoute(
          path: Routes.supplierPricing,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: SupplierPricingPage(
              storeId: _storeId(state),
              supplierId: state.pathParameters['supplierId']!,
            ),
          ),
        ),

        // --- Reports ---------------------------------------------------------
        GoRoute(
          path: Routes.reports,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: ReportsDashboardPage(storeId: _storeId(state)),
          ),
        ),
        GoRoute(
          path: Routes.valuationReport,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: StockValuationReportPage(storeId: _storeId(state)),
          ),
        ),
        GoRoute(
          path: Routes.comparisonReport,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: PriceComparisonReportPage(storeId: _storeId(state)),
          ),
        ),
        GoRoute(
          path: Routes.usageReport,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: UsageReportPage(storeId: _storeId(state)),
          ),
        ),

        // --- Gestion Employée -----------------------------------------------
        //
        // `new` and the section literals (`timeclock`, `attendance-history`,
        // `payroll`) precede `:employeeId` for the same ordering reason as the
        // inventory routes. The pointage, attendance-history and payroll
        // screens are placeholders until Phases 3–5 — see
        // `.claude/phase_gestion_employee.md`.
        GoRoute(
          path: Routes.employees,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: EmployeesListPage(storeId: _storeId(state)),
          ),
        ),
        GoRoute(
          path: Routes.addEmployee,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: AddEditEmployeePage(storeId: _storeId(state)),
          ),
        ),
        GoRoute(
          path: Routes.timeclock,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: TimeclockBoardPage(storeId: _storeId(state)),
          ),
        ),
        GoRoute(
          path: Routes.attendanceHistory,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: AttendanceHistoryPage(storeId: _storeId(state)),
          ),
        ),
        GoRoute(
          path: Routes.payroll,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: PayrollHistoryPage(storeId: _storeId(state)),
          ),
        ),
        GoRoute(
          path: Routes.employeeDetail,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: EmployeeDetailPage(
              storeId: _storeId(state),
              employeeId: state.pathParameters['employeeId']!,
            ),
          ),
        ),
        GoRoute(
          path: Routes.editEmployee,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: AddEditEmployeePage(
              storeId: _storeId(state),
              employeeId: state.pathParameters['employeeId'],
            ),
          ),
        ),

        // --- Settings --------------------------------------------------------
        GoRoute(
          path: Routes.storeSettings,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: StoreSettingsPage(storeId: _storeId(state)),
          ),
        ),
        GoRoute(
          path: Routes.accountSettings,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: AccountSettingsPage(storeId: _storeId(state)),
          ),
        ),
        GoRoute(
          path: Routes.notificationSettings,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: NotificationPreferencesPage(storeId: _storeId(state)),
          ),
        ),
        GoRoute(
          path: Routes.syncStatus,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: SyncStatusPage(storeId: _storeId(state)),
          ),
        ),

        // --- Global search ---------------------------------------------------
        GoRoute(
          path: Routes.search,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: GlobalSearchPage(storeId: _storeId(state)),
          ),
        ),
      ],
    ),
  ],

  // A 404 in a demo is worse than a 404 in production — there is nobody to file
  // a bug, only a client watching. Offer a way back.
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Page introuvable',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(state.uri.path, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go(Routes.stores),
            child: const Text('Retour aux établissements'),
          ),
        ],
      ),
    ),
  ),
);

/// Resolves the establishment the shell is showing, and holds the chrome
/// steady while it does.
///
/// Phase 1 read the store synchronously from a compiled-in list, which is why
/// the `ShellRoute` builder could return [AppScaffold] directly. A query takes
/// a frame, so this is the one place in the app where a loading state gates
/// every store-scoped screen at once — and the reason [AppScaffoldSkeleton]
/// draws the rail and top bar rather than nothing.
///
/// Falls back to the first establishment for an id that does not resolve, so a
/// stale bookmark or a hot reload mid-navigation shows the app rather than a
/// red screen. That was true in Phase 1 too; what is new is that "no
/// establishment at all" is now a real answer, handled by [AppScaffoldNoStore].
class _StoreShell extends ConsumerWidget {
  const _StoreShell({required this.storeId, required this.child});

  final String? storeId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(currentStoreProvider(storeId))
        .when(
          skipLoadingOnReload: true,
          data: (store) => store == null
              ? const AppScaffoldNoStore()
              : AppScaffold(store: store, child: child),
          loading: () => const AppScaffoldSkeleton(),
          // The chrome cannot render without an establishment, so a failed
          // query lands here rather than on the page inside it. No retry: the
          // stream is still live, and it will deliver if the database recovers.
          error: (error, stackTrace) => const AppScaffoldNoStore(),
        );
  }
}
