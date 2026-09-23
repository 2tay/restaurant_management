/// The tunable settings for one store.
///
/// A real record rather than a bag of static globals: it maps 1:1 onto the
/// `settings` row a store gets in Phase 2's storage, it is per-store (an owner
/// runs several), and the pointage break allowance needs somewhere to live
/// that a manager can edit. Read through `MockQueries.storeSettings(storeId)`,
/// written through `AccountMutations.updateStoreSettings`.
///
/// Immutable, no logic — same contract as every other model. A brand-new
/// store gets a default row from `AccountMutations.createStore`; the default
/// itself is the `*.default*` constant in `core/utils/`.
class StoreSettings {
  const StoreSettings({
    required this.storeId,
    required this.maxBreakMinutes,
    required this.stalePartialOrderDays,
  });

  final String storeId;

  /// A single break segment running longer than this is flagged as a
  /// "pause dépassée" — see `hasLateBreak` in `core/utils/attendance_status.dart`.
  final int maxBreakMinutes;

  /// How many days a `partial` commande may sit before the dashboard flags it.
  final int stalePartialOrderDays;
}
