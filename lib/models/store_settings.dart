/// The tunable settings for one store.
///
/// A real record rather than a bag of static globals: it maps 1:1 onto the
/// `settings` row a store gets in Phase 2's storage, it is per-store (an owner
/// runs several), and the pointage break allowance needs somewhere to live
/// that a manager can edit. Read through `StoreRepository.settings(storeId)`,
/// written through `StoreRepository.updateStoreSettings`.
///
/// Immutable, no logic — same contract as every other model. A brand-new
/// store gets a default row from `AccountMutations.createStore`; the default
/// itself is the `*.default*` constant in `core/utils/`.
class StoreSettings {
  const StoreSettings({
    required this.storeId,
    required this.maxBreakMinutes,
    required this.stalePartialOrderDays,
    // Defaulted rather than required: they have the same defaults in the
    // schema, and every caller that builds a settings record by hand — the
    // seed, the fallback for a missing row — means "whatever the schema says".
    this.notifyLowStock = true,
    this.notifyPriceChange = true,
    this.notifyLargeAdjustment = true,
    this.notifyDeliveries = false,
    this.notifyBusyDays = true,
    this.businessDayAutoOpenMinutes = 300,
  });

  final String storeId;

  /// A single break segment running longer than this is flagged as a
  /// "pause dépassée" — see `hasLateBreak` in `core/utils/attendance_status.dart`.
  final int maxBreakMinutes;

  /// From when in the day (minutes after midnight) the first Pointer opens
  /// the journée de service by itself; before it, no journée opens on its own.
  /// Zero: any time. Defaults to 05:00, as in the schema.
  final int businessDayAutoOpenMinutes;

  /// How many days a `partial` commande may sit before the dashboard flags it.
  final int stalePartialOrderDays;

  /// Which events may write into the notification feed.
  ///
  /// Read by the notification engine before it composes anything, so a
  /// preference switched off means the notification is never created — not
  /// created and then hidden, which would still sit unread on the bell.
  final bool notifyLowStock;
  final bool notifyPriceChange;
  final bool notifyLargeAdjustment;
  final bool notifyDeliveries;

  /// The reminder before a busy period on the calendar.
  final bool notifyBusyDays;
}
