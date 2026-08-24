/// Route paths and names.
///
/// Store-scoped routes carry the store id in the path — `/store/:storeId/...`
/// rather than holding "the current store" in a global. That makes the scoping
/// rule from the brief structural: a screen cannot render without knowing which
/// store it is for, switching stores is just a navigation, and deep links stay
/// meaningful. It also maps directly onto real routing in Phase 2.
///
/// Paths stay in English. They are internal identifiers, never shown to the
/// user, and translating them would break every link for no benefit.
abstract final class Routes {
  // --- Outside the shell (no sidebar — there is no store context yet) --------

  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String onboarding = '/onboarding';
  static const String stores = '/stores';
  static const String addStore = '/stores/add';

  /// Development only — the design-system gallery. Linked from nothing; a
  /// production build should drop this route along with `lib/dev/`.
  static const String devGallery = '/dev/gallery';

  // --- Inside the shell -----------------------------------------------------

  static const String storeBase = '/store/:storeId';

  static const String dashboard = '$storeBase/dashboard';

  static const String inventory = '$storeBase/inventory';
  static const String addItem = '$inventory/new';
  static const String itemDetail = '$inventory/:itemId';
  static const String editItem = '$itemDetail/edit';
  static const String linkSupplier = '$itemDetail/link-supplier';
  static const String itemPriceHistory =
      '$itemDetail/price-history/:supplierId';

  static const String categories = '$storeBase/catalog/categories';
  static const String units = '$storeBase/catalog/units';

  static const String movements = '$storeBase/movements';
  static const String stockIn = '$movements/in';
  static const String stockOut = '$movements/out';
  static const String stockAdjustment = '$movements/adjust';

  static const String alerts = '$storeBase/alerts';
  static const String notifications = '$storeBase/notifications';

  // Orders. `new` and `receipts` are declared before `:orderId` in the router
  // for the same reason `new` precedes `:itemId` — go_router matches in order,
  // and otherwise "new" would be read as an order id.
  static const String orders = '$storeBase/orders';
  static const String newOrder = '$orders/new';
  static const String receiptDetail = '$orders/receipts/:receiptId';
  static const String orderDetail = '$orders/:orderId';
  static const String editOrder = '$orderDetail/edit';
  static const String receiveOrder = '$orderDetail/receive';

  static const String suppliers = '$storeBase/suppliers';
  static const String addSupplier = '$suppliers/new';
  static const String supplierDetail = '$suppliers/:supplierId';
  static const String editSupplier = '$supplierDetail/edit';
  static const String supplierPricing = '$supplierDetail/pricing';

  static const String reports = '$storeBase/reports';
  static const String valuationReport = '$reports/valuation';
  static const String comparisonReport = '$reports/comparison';
  static const String usageReport = '$reports/usage';

  static const String team = '$storeBase/team';
  static const String addTeamMember = '$team/new';
  static const String roles = '$team/roles';
  static const String editTeamMember = '$team/:memberId/edit';

  // Employees. `new` is declared before `:employeeId` for the same go_router
  // ordering reason `orders` declares `new` before `:orderId` — otherwise
  // "new" and "timeclock" get read as an id. `timeclock` carries no route yet
  // (Stage 2 registers it) — the constant exists now so nothing has to change
  // when it does.
  static const String employees = '$storeBase/employees';
  static const String addEmployee = '$employees/new';
  static const String employeeDetail = '$employees/:employeeId';
  static const String editEmployee = '$employeeDetail/edit';
  static const String linkTeamAccess = '$employeeDetail/link-team';
  static const String timeclock = '$employees/timeclock';

  static const String storeSettings = '$storeBase/settings/store';
  static const String accountSettings = '$storeBase/settings/account';
  static const String notificationSettings =
      '$storeBase/settings/notifications';
  static const String syncStatus = '$storeBase/settings/sync';

  static const String search = '$storeBase/search';

  // --- Path builders --------------------------------------------------------
  //
  // Screens navigate with these rather than interpolating strings by hand, so a
  // renamed segment is a compile error in one place instead of a dead link
  // discovered during a demo.

  static String toDashboard(String storeId) => '/store/$storeId/dashboard';

  static String toInventory(String storeId) => '/store/$storeId/inventory';

  static String toAddItem(String storeId) => '/store/$storeId/inventory/new';

  static String toItem(String storeId, String itemId) =>
      '/store/$storeId/inventory/$itemId';

  static String toEditItem(String storeId, String itemId) =>
      '/store/$storeId/inventory/$itemId/edit';

  static String toLinkSupplier(String storeId, String itemId) =>
      '/store/$storeId/inventory/$itemId/link-supplier';

  static String toPriceHistory(
    String storeId,
    String itemId,
    String supplierId,
  ) => '/store/$storeId/inventory/$itemId/price-history/$supplierId';

  static String toCategories(String storeId) =>
      '/store/$storeId/catalog/categories';

  static String toUnits(String storeId) => '/store/$storeId/catalog/units';

  static String toMovements(String storeId) => '/store/$storeId/movements';

  static String toStockIn(String storeId) => '/store/$storeId/movements/in';

  static String toStockOut(String storeId) => '/store/$storeId/movements/out';

  static String toAdjustment(String storeId) =>
      '/store/$storeId/movements/adjust';

  static String toAlerts(String storeId) => '/store/$storeId/alerts';

  static String toNotifications(String storeId) =>
      '/store/$storeId/notifications';

  static String toOrders(String storeId) => '/store/$storeId/orders';

  static String toNewOrder(String storeId) => '/store/$storeId/orders/new';

  static String toOrder(String storeId, String orderId) =>
      '/store/$storeId/orders/$orderId';

  static String toEditOrder(String storeId, String orderId) =>
      '/store/$storeId/orders/$orderId/edit';

  static String toReceiveOrder(String storeId, String orderId) =>
      '/store/$storeId/orders/$orderId/receive';

  static String toReceipt(String storeId, String receiptId) =>
      '/store/$storeId/orders/receipts/$receiptId';

  static String toSuppliers(String storeId) => '/store/$storeId/suppliers';

  static String toAddSupplier(String storeId) =>
      '/store/$storeId/suppliers/new';

  static String toSupplier(String storeId, String supplierId) =>
      '/store/$storeId/suppliers/$supplierId';

  static String toEditSupplier(String storeId, String supplierId) =>
      '/store/$storeId/suppliers/$supplierId/edit';

  static String toSupplierPricing(String storeId, String supplierId) =>
      '/store/$storeId/suppliers/$supplierId/pricing';

  static String toReports(String storeId) => '/store/$storeId/reports';

  static String toValuationReport(String storeId) =>
      '/store/$storeId/reports/valuation';

  static String toComparisonReport(String storeId) =>
      '/store/$storeId/reports/comparison';

  static String toUsageReport(String storeId) =>
      '/store/$storeId/reports/usage';

  static String toTeam(String storeId) => '/store/$storeId/team';

  static String toAddTeamMember(String storeId) => '/store/$storeId/team/new';

  static String toEditTeamMember(String storeId, String memberId) =>
      '/store/$storeId/team/$memberId/edit';

  static String toRoles(String storeId) => '/store/$storeId/team/roles';

  static String toEmployees(String storeId) => '/store/$storeId/employees';

  static String toAddEmployee(String storeId) =>
      '/store/$storeId/employees/new';

  static String toEmployee(String storeId, String employeeId) =>
      '/store/$storeId/employees/$employeeId';

  static String toEditEmployee(String storeId, String employeeId) =>
      '/store/$storeId/employees/$employeeId/edit';

  static String toLinkTeamAccess(String storeId, String employeeId) =>
      '/store/$storeId/employees/$employeeId/link-team';

  static String toTimeclock(String storeId) =>
      '/store/$storeId/employees/timeclock';

  static String toStoreSettings(String storeId) =>
      '/store/$storeId/settings/store';

  static String toAccountSettings(String storeId) =>
      '/store/$storeId/settings/account';

  static String toNotificationSettings(String storeId) =>
      '/store/$storeId/settings/notifications';

  static String toSyncStatus(String storeId) => '/store/$storeId/settings/sync';

  static String toSearch(String storeId) => '/store/$storeId/search';
}
