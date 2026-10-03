/// Which tables sync between devices, and which stay on this one
/// (SYNC_PLAN.md, Phase 1, step 1).
///
/// Every table in the schema is in exactly one of these two sets, and
/// `test/db/sync_tables_test.dart` fails the build when a new table is in
/// neither. A table left out would never sync, silently.
///
/// A synced table carries `updated_at` and `deleted_at` (`tables/
/// sync_columns.dart`), has a `*_touch` trigger in `sync_triggers.drift`, and
/// is never deleted from by the app — see `repositories/soft_delete.dart`.
abstract final class SyncTables {
  /// Business data shared by every device of a restaurant. SQL names.
  static const Set<String> synced = {
    'stores',
    'categories',
    'units',
    'items',
    'suppliers',
    'supplier_prices',
    'price_history',
    'stock_movements',
    'purchase_orders',
    'purchase_order_lines',
    'goods_receipts',
    'goods_receipt_lines',
    'notifications',
    'employees',
    'employee_credentials',
    'payroll_periods',
    'attendances',
    'attendance_sessions',
    'attendance_pauses',
    'busy_dates',
    'business_days',
  };

  /// Facts about this installation: who is signed in on this tablet, the
  /// device id, the queue of changes to send, the changes the server refused,
  /// and later the sync cursors. Never sent anywhere.
  static const Set<String> local = {
    'meta',
    'outbox',
    'sync_errors',
    'photo_uploads',
    // Each tablet's own sign-in attempts and lockout (step 5, rule C3).
    'login_states',
  };

  /// Synced tables whose parent is not a store, so they carry a copy of the
  /// store id for the server's permission checks.
  static const Set<String> withCopiedStore = {
    'supplier_prices',
    'price_history',
    'purchase_order_lines',
    'goods_receipt_lines',
    'employee_credentials',
    'attendance_sessions',
    'attendance_pauses',
  };
}
