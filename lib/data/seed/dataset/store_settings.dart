import '../../../core/utils/attendance_status.dart';
import '../../../core/utils/order_status.dart';
import '../../../models/store_settings.dart';
import 'stores.dart';

/// One settings row per store — the break allowance and the stale-order
/// threshold.
///
/// Brasserie du Sablon gives a longer break than the default, so per-store
/// settings are demoable. The two other stores take every default. A store
/// created in-session gets a default row from `AccountMutations.createStore`.
StoreSettings _defaults(String storeId) => StoreSettings(
  storeId: storeId,
  maxBreakMinutes: AttendanceRules.defaultMaxBreakMinutes,
  stalePartialOrderDays: OrderRules.defaultStalePartialDays,
);

final List<StoreSettings> mockStoreSettings = [
  const StoreSettings(
    storeId: StoreIds.sablon,
    maxBreakMinutes: 45,
    stalePartialOrderDays: OrderRules.defaultStalePartialDays,
  ),
  _defaults(StoreIds.liege),
  _defaults(StoreIds.saintGilles),
  // TestCalcul gives a 60-min break allowance so a normal one-hour lunch is
  // not flagged "pause dépassée".
  const StoreSettings(
    storeId: StoreIds.testCalcul,
    maxBreakMinutes: 60,
    stalePartialOrderDays: OrderRules.defaultStalePartialDays,
  ),
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
