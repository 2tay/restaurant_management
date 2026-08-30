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
  // TestCalcul runs a long 08:00–22:00 day (the "heure configurée par
  // l'entreprise" the fixed employee inherits) and a 60-min break allowance so
  // a normal one-hour lunch is not flagged "pause dépassée". Overtime premium
  // and the monthly-to-daily divisor stay on the defaults (×1.25, ÷26).
  const StoreSettings(
    storeId: StoreIds.testCalcul,
    openMinutes: 8 * 60,
    closeMinutes: 22 * 60,
    maxBreakMinutes: 60,
    overtimeMultiplier: PayrollRules.defaultOvertimeMultiplier,
    workingDaysPerMonth: PayrollRules.defaultWorkingDaysPerMonth,
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
