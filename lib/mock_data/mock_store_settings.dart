import '../core/utils/attendance_status.dart';
import '../core/utils/order_status.dart';
import '../core/utils/payroll_math.dart';
import '../models/store_settings.dart';
import 'mock_stores.dart';

/// One settings row per store — the pointage hours, the break allowance, the
/// payroll coefficients, and the stale-order threshold.
///
/// Brasserie du Sablon keeps the 08:00–17:00 day (its late / overtime
/// walkthrough states are seeded against that) but gives a longer break and a
/// higher overtime premium, so per-store settings are demoable. The two other
/// stores take every default. A store created in-session gets a default row
/// from `AccountMutations.createStore`.
StoreSettings _defaults(String storeId) => StoreSettings(
  storeId: storeId,
  openMinutes: AttendanceRules.defaultOpenMinutes,
  closeMinutes: AttendanceRules.defaultCloseMinutes,
  maxBreakMinutes: AttendanceRules.defaultMaxBreakMinutes,
  overtimeMultiplier: PayrollRules.defaultOvertimeMultiplier,
  workingDaysPerMonth: PayrollRules.defaultWorkingDaysPerMonth,
  stalePartialOrderDays: OrderRules.defaultStalePartialDays,
);

final List<StoreSettings> mockStoreSettings = [
  const StoreSettings(
    storeId: StoreIds.sablon,
    openMinutes: AttendanceRules.defaultOpenMinutes,
    closeMinutes: AttendanceRules.defaultCloseMinutes,
    maxBreakMinutes: 45,
    overtimeMultiplier: 1.5,
    workingDaysPerMonth: PayrollRules.defaultWorkingDaysPerMonth,
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
