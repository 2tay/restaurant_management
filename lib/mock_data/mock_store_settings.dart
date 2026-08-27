import '../core/utils/attendance_status.dart';
import '../core/utils/order_status.dart';
import '../models/store_settings.dart';
import 'mock_stores.dart';

/// One settings row per store — the pointage hours, the break allowance, and
/// the stale-order threshold.
///
/// Brasserie du Sablon runs a long evening service, so it closes at 23:00 and
/// gives a slightly longer break; the two others keep the daytime defaults.
/// A store created in-session gets a default row from
/// `AccountMutations.createStore`.
StoreSettings _defaults(String storeId) => StoreSettings(
  storeId: storeId,
  openMinutes: AttendanceRules.defaultOpenMinutes,
  closeMinutes: AttendanceRules.defaultCloseMinutes,
  maxBreakMinutes: AttendanceRules.defaultMaxBreakMinutes,
  stalePartialOrderDays: OrderRules.defaultStalePartialDays,
);

final List<StoreSettings> mockStoreSettings = [
  const StoreSettings(
    storeId: StoreIds.sablon,
    openMinutes: 9 * 60,
    closeMinutes: 23 * 60,
    maxBreakMinutes: 45,
    stalePartialOrderDays: OrderRules.defaultStalePartialDays,
  ),
  _defaults(StoreIds.liege),
  _defaults(StoreIds.saintGilles),
];

/// The row for a store, or a synthesised default when there is none — nothing
/// in the app should ever produce a store without settings, but a missing row
/// is cheaper to treat as "defaults" than to assert against.
StoreSettings storeSettingsOrDefault(String storeId) {
  for (final settings in mockStoreSettings) {
    if (settings.storeId == storeId) return settings;
  }
  return _defaults(storeId);
}
