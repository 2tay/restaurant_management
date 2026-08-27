import '../../core/utils/attendance_status.dart';
import '../../core/utils/order_status.dart';
import '../../core/utils/payroll_math.dart';
import '../../models/models.dart';
import '../mock_notifications.dart';
import '../mock_queries.dart';
import '../mock_store_settings.dart';
import '../mock_stores.dart';
import 'mock_write.dart';

/// Writes against the things that are about the account rather than the stock:
/// the stores themselves, and the notification feed.
///
/// Grouped into one file because neither is big enough to justify its own, and
/// they share a shape — small records with no dependants to cascade to. If
/// either grows a real relationship, it should move out.
///
/// They are here at all for coherence. Once creating an article sticks, a store
/// that silently does not is more confusing than either behaviour would be on
/// its own.
///
/// The team-member writes that used to live here went with the Équipe module in
/// the Gestion Employée rebuild (see `.claude/phase_gestion_employee.md`,
/// Phase 1); they come back, reshaped onto `Employee`, in Phase 2.
abstract final class AccountMutations {
  // ---------------------------------------------------------------------------
  // Stores
  // ---------------------------------------------------------------------------

  /// Opens a new location.
  ///
  /// It starts with no categories, units, items or suppliers, which is correct
  /// rather than lazy: those are per-store by design, and a new shop's
  /// catalogue is not the old shop's. Every empty state in the app is what the
  /// user sees next.
  static Store createStore({
    required String name,
    required String addressLine,
    required String postalCode,
    required String city,
    required String phone,
  }) {
    final store = Store(
      id: MockWrite.id('store'),
      name: name.trim(),
      addressLine: addressLine.trim(),
      postalCode: postalCode.trim(),
      city: city.trim(),
      phone: phone.trim(),
      createdAt: DateTime.now(),
    );

    mockStores.add(store);
    mockStoreSettings.add(
      StoreSettings(
        storeId: store.id,
        openMinutes: AttendanceRules.defaultOpenMinutes,
        closeMinutes: AttendanceRules.defaultCloseMinutes,
        maxBreakMinutes: AttendanceRules.defaultMaxBreakMinutes,
        overtimeMultiplier: PayrollRules.defaultOvertimeMultiplier,
        workingDaysPerMonth: PayrollRules.defaultWorkingDaysPerMonth,
        stalePartialOrderDays: OrderRules.defaultStalePartialDays,
      ),
    );
    MockWrite.changed();
    return store;
  }

  /// Edits a store's settings — opening hours, break allowance, payroll
  /// coefficients, stale-order threshold. Values left null keep their current
  /// value; a nonsense value (negative, a time outside 0–1439, a multiplier
  /// below 1) is ignored rather than refused, the same forgiving stance the
  /// settings screen takes.
  static StoreSettings updateStoreSettings(
    String storeId, {
    int? openMinutes,
    int? closeMinutes,
    int? maxBreakMinutes,
    double? overtimeMultiplier,
    int? workingDaysPerMonth,
    int? stalePartialOrderDays,
  }) {
    final existing = MockQueries.storeSettings(storeId);
    bool validTime(int? m) => m != null && m >= 0 && m < 24 * 60;
    bool validCount(int? n) => n != null && n > 0;

    final updated = StoreSettings(
      storeId: storeId,
      openMinutes: validTime(openMinutes)
          ? openMinutes!
          : existing.openMinutes,
      closeMinutes: validTime(closeMinutes)
          ? closeMinutes!
          : existing.closeMinutes,
      maxBreakMinutes: validCount(maxBreakMinutes)
          ? maxBreakMinutes!
          : existing.maxBreakMinutes,
      overtimeMultiplier:
          overtimeMultiplier != null && overtimeMultiplier >= 1
          ? overtimeMultiplier
          : existing.overtimeMultiplier,
      workingDaysPerMonth: validCount(workingDaysPerMonth)
          ? workingDaysPerMonth!
          : existing.workingDaysPerMonth,
      stalePartialOrderDays: validCount(stalePartialOrderDays)
          ? stalePartialOrderDays!
          : existing.stalePartialOrderDays,
    );

    final index = mockStoreSettings.indexWhere((s) => s.storeId == storeId);
    if (index == -1) {
      mockStoreSettings.add(updated);
    } else {
      mockStoreSettings[index] = updated;
    }
    MockWrite.changed();
    return updated;
  }

  static Store? updateStore(
    String id, {
    String? name,
    String? addressLine,
    String? postalCode,
    String? city,
    String? phone,
  }) {
    final index = mockStores.indexWhere((store) => store.id == id);
    if (index == -1) return null;

    final existing = mockStores[index];
    final updated = Store(
      id: existing.id,
      name: name?.trim() ?? existing.name,
      addressLine: addressLine?.trim() ?? existing.addressLine,
      postalCode: postalCode?.trim() ?? existing.postalCode,
      city: city?.trim() ?? existing.city,
      phone: phone?.trim() ?? existing.phone,
      createdAt: existing.createdAt,
      imageAsset: existing.imageAsset,
    );

    mockStores[index] = updated;
    MockWrite.changed();
    return updated;
  }

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  /// Marks one notification read. No-op if it already was.
  static bool markRead(String id) {
    final index = mockNotifications.indexWhere((n) => n.id == id);
    if (index == -1) return false;

    final existing = mockNotifications[index];
    if (existing.isRead) return false;

    mockNotifications[index] = _asRead(existing);
    MockWrite.changed();
    return true;
  }

  /// Marks everything in a store read. Returns how many changed.
  ///
  /// Returning the count lets the screen say "7 notifications marquées comme
  /// lues" rather than a bare acknowledgement, and lets it stay quiet when
  /// there was nothing to do.
  static int markAllRead(String storeId) {
    var changed = 0;

    for (var i = 0; i < mockNotifications.length; i++) {
      final notification = mockNotifications[i];
      if (notification.storeId != storeId || notification.isRead) continue;
      mockNotifications[i] = _asRead(notification);
      changed++;
    }

    if (changed > 0) MockWrite.changed();
    return changed;
  }

  static NotificationItem _asRead(NotificationItem notification) {
    return NotificationItem(
      id: notification.id,
      storeId: notification.storeId,
      kind: notification.kind,
      title: notification.title,
      body: notification.body,
      createdAt: notification.createdAt,
      isRead: true,
      relatedItemId: notification.relatedItemId,
      relatedSupplierId: notification.relatedSupplierId,
    );
  }
}
