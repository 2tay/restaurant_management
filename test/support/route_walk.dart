// The list of every navigable route, with real ids substituted for path
// parameters.
//
// Lifted out of `router_test.dart` when `responsive_test.dart` needed the same
// walk at six more window sizes. Two copies of this list would drift the moment
// a route was added, and the copy that was not updated would go on passing.

import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';

/// One walkable destination. [inShell] is false for the auth and
/// store-selection screens, which render outside `AppScaffold` because there is
/// no store context yet.
typedef WalkableRoute = ({String label, String path, bool inShell});

List<WalkableRoute> allRoutes() {
  const store = StoreIds.sablon;
  final item = mockItems.first.id;
  final supplier = mockSuppliers.first.id;
  final employee = mockEmployees.first.id;
  final archivedEmployee = mockEmployees
      .firstWhere((e) => e.archivedAt != null)
      .id;

  // A draft and a partially received order, because the detail screen renders
  // a different action row for each status and only one of them can be wrong
  // at a time.
  const draftOrder = OrderIds.draftMaraicher;
  const openOrder = OrderIds.partialBoucherie;
  const receipt = ReceiptIds.cremerieFinal;

  return [
    (label: 'login', path: Routes.login, inShell: false),
    (label: 'forgot password', path: Routes.forgotPassword, inShell: false),
    (label: 'onboarding', path: Routes.onboarding, inShell: false),
    (label: 'store selector', path: Routes.stores, inShell: false),
    (label: 'add store', path: Routes.addStore, inShell: false),

    (label: 'dashboard', path: Routes.toDashboard(store), inShell: true),

    (label: 'inventory', path: Routes.toInventory(store), inShell: true),
    (label: 'add item', path: Routes.toAddItem(store), inShell: true),
    (label: 'item detail', path: Routes.toItem(store, item), inShell: true),
    (label: 'edit item', path: Routes.toEditItem(store, item), inShell: true),
    (
      label: 'link supplier',
      path: Routes.toLinkSupplier(store, item),
      inShell: true,
    ),
    (
      label: 'price history',
      path: Routes.toPriceHistory(store, item, supplier),
      inShell: true,
    ),

    (label: 'categories', path: Routes.toCategories(store), inShell: true),
    (label: 'units', path: Routes.toUnits(store), inShell: true),

    (label: 'movements', path: Routes.toMovements(store), inShell: true),
    (label: 'stock in', path: Routes.toStockIn(store), inShell: true),
    (label: 'stock out', path: Routes.toStockOut(store), inShell: true),
    (label: 'adjustment', path: Routes.toAdjustment(store), inShell: true),

    (label: 'alerts', path: Routes.toAlerts(store), inShell: true),
    (
      label: 'notifications',
      path: Routes.toNotifications(store),
      inShell: true,
    ),

    (label: 'orders', path: Routes.toOrders(store), inShell: true),
    (label: 'new order', path: Routes.toNewOrder(store), inShell: true),
    (
      label: 'order detail (draft)',
      path: Routes.toOrder(store, draftOrder),
      inShell: true,
    ),
    (
      label: 'order detail (partial)',
      path: Routes.toOrder(store, openOrder),
      inShell: true,
    ),
    (
      label: 'edit order',
      path: Routes.toEditOrder(store, draftOrder),
      inShell: true,
    ),
    (
      label: 'receive order',
      path: Routes.toReceiveOrder(store, openOrder),
      inShell: true,
    ),
    (
      label: 'receipt detail',
      path: Routes.toReceipt(store, receipt),
      inShell: true,
    ),

    (label: 'suppliers', path: Routes.toSuppliers(store), inShell: true),
    (label: 'add supplier', path: Routes.toAddSupplier(store), inShell: true),
    (
      label: 'supplier detail',
      path: Routes.toSupplier(store, supplier),
      inShell: true,
    ),
    (
      label: 'edit supplier',
      path: Routes.toEditSupplier(store, supplier),
      inShell: true,
    ),
    (
      label: 'supplier pricing',
      path: Routes.toSupplierPricing(store, supplier),
      inShell: true,
    ),

    (label: 'reports', path: Routes.toReports(store), inShell: true),
    (
      label: 'valuation report',
      path: Routes.toValuationReport(store),
      inShell: true,
    ),
    (
      label: 'comparison report',
      path: Routes.toComparisonReport(store),
      inShell: true,
    ),
    (label: 'usage report', path: Routes.toUsageReport(store), inShell: true),

    (label: 'employees', path: Routes.toEmployees(store), inShell: true),
    (label: 'add employee', path: Routes.toAddEmployee(store), inShell: true),
    (label: 'timeclock', path: Routes.toTimeclock(store), inShell: true),
    (
      label: 'attendance history',
      path: Routes.toAttendanceHistory(store),
      inShell: true,
    ),
    (label: 'payroll', path: Routes.toPayroll(store), inShell: true),
    (
      label: 'employee detail',
      path: Routes.toEmployee(store, employee),
      inShell: true,
    ),
    (
      label: 'archived employee detail',
      path: Routes.toEmployee(store, archivedEmployee),
      inShell: true,
    ),
    (
      label: 'edit employee',
      path: Routes.toEditEmployee(store, employee),
      inShell: true,
    ),

    (
      label: 'store settings',
      path: Routes.toStoreSettings(store),
      inShell: true,
    ),
    (
      label: 'account settings',
      path: Routes.toAccountSettings(store),
      inShell: true,
    ),
    (
      label: 'notification settings',
      path: Routes.toNotificationSettings(store),
      inShell: true,
    ),
    (label: 'sync status', path: Routes.toSyncStatus(store), inShell: true),

    (label: 'search', path: Routes.toSearch(store), inShell: true),
  ];
}
