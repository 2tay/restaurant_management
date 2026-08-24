import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../dev/theme_gallery_page.dart';
import '../features/alerts/presentation/pages/low_stock_alerts_page.dart';
import '../features/alerts/presentation/pages/notifications_page.dart';
import '../features/dashboard/presentation/pages/store_dashboard_page.dart';
import '../features/employees/presentation/pages/add_edit_employee_page.dart';
import '../features/employees/presentation/pages/employee_detail_page.dart';
import '../features/employees/presentation/pages/employees_list_page.dart';
import '../features/employees/presentation/pages/link_team_access_page.dart';
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
import '../features/team/presentation/pages/add_edit_member_page.dart';
import '../features/team/presentation/pages/roles_permissions_page.dart';
import '../features/team/presentation/pages/team_list_page.dart';
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
import '../mock_data/mock_data.dart';
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

final GoRouter appRouter = GoRouter(
  // Phase 1 has no authentication, so the app opens on the login screen and
  // every button simply navigates onward. There is no redirect guard here on
  // purpose — adding one would be the start of the auth logic the brief defers.
  initialLocation: Routes.login,
  debugLogDiagnostics: false,
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
      builder: (context, state, child) {
        // Falls back to the first store rather than throwing, so a stale link
        // or a hot reload mid-navigation shows the app instead of a red screen.
        final store = MockQueries.storeByIdOrFirst(
          state.pathParameters['storeId'],
        );
        return AppScaffold(store: store, child: child);
      },
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

        // --- Team ------------------------------------------------------------
        //
        // `new` and `roles` precede `:memberId` for the same ordering reason as
        // the inventory routes.
        GoRoute(
          path: Routes.team,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: TeamListPage(storeId: _storeId(state)),
          ),
        ),
        GoRoute(
          path: Routes.addTeamMember,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: AddEditMemberPage(storeId: _storeId(state)),
          ),
        ),
        GoRoute(
          path: Routes.roles,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: RolesPermissionsPage(storeId: _storeId(state)),
          ),
        ),
        GoRoute(
          path: Routes.editTeamMember,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: AddEditMemberPage(
              storeId: _storeId(state),
              memberId: state.pathParameters['memberId'],
            ),
          ),
        ),

        // --- Employees ---------------------------------------------------------
        //
        // `new` and `timeclock` are declared before `:employeeId` for the
        // same ordering reason as the inventory routes — otherwise both
        // literal segments would be read as an employee id.
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
        GoRoute(
          path: Routes.linkTeamAccess,
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: LinkTeamAccessPage(
              storeId: _storeId(state),
              employeeId: state.pathParameters['employeeId']!,
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
