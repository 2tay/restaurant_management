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
    'notification_reads',
    'employees',
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
  };

  /// Synced tables whose parent is not a store, so they carry a copy of the
  /// store id for the server's permission checks.
  static const Set<String> withCopiedStore = {
    'supplier_prices',
    'price_history',
    'purchase_order_lines',
    'goods_receipt_lines',
    'notification_reads',
    'attendance_sessions',
    'attendance_pauses',
  };

  /// Columns that hold a calendar day, not a moment: « Karim, 3 October ».
  ///
  /// Locally a day is midnight of that day in the tablet's time zone. Sent
  /// as such, the server would keep the moment, and a tablet in another time
  /// zone would read it back at 01:00, or on 2 October at 22:00. So a day
  /// travels as midnight UTC of its date ([daySent]) and comes back as local
  /// midnight of that date ([dayReceived]), whatever the time zones.
  static const Map<String, Set<String>> dayColumns = {
    'attendances': {'date'},
    'business_days': {'date'},
    'payroll_periods': {'start_date', 'end_date'},
  };

  /// A day as the local database stores it (`2026-10-03T00:00:00.000+02:00`),
  /// as it is sent: `2026-10-03T00:00:00.000Z`. The nearest midnight, so a
  /// day received shifted before this rule existed (01:00, or 22:00 the day
  /// before) goes back on its date.
  static String daySent(String stored) {
    final local = DateTime.parse(stored).toLocal().add(const Duration(hours: 12));
    return DateTime.utc(local.year, local.month, local.day).toIso8601String();
  }

  /// A day as the server sends it, as local midnight of its date. Midnight
  /// UTC for a day sent by [daySent]; the nearest midnight for one a tablet
  /// sent with its own offset before, up to twelve hours either way.
  static DateTime dayReceived(String sent) {
    final utc = DateTime.parse(sent).toUtc().add(const Duration(hours: 12));
    return DateTime(utc.year, utc.month, utc.day);
  }
}
