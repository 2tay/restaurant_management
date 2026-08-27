/// The tunable settings for one store.
///
/// A real record rather than a bag of static globals: it maps 1:1 onto the
/// `settings` row a store gets in Phase 2's storage, it is per-store (an owner
/// runs several), and the pointage rules (opening hours, the break allowance)
/// need somewhere to live that a manager can edit. Read through
/// `MockQueries.storeSettings(storeId)`, written through
/// `AccountMutations.updateStoreSettings`.
///
/// Immutable, no logic — same contract as every other model. Times are
/// minutes since midnight so the model stays pure Dart. A brand-new store
/// gets a default row from `AccountMutations.createStore`; the defaults
/// themselves are the `*.default*` constants in `core/utils/`.
class StoreSettings {
  const StoreSettings({
    required this.storeId,
    required this.openMinutes,
    required this.closeMinutes,
    required this.maxBreakMinutes,
    required this.stalePartialOrderDays,
  });

  final String storeId;

  /// Opening / closing time, minutes since midnight. The baseline pointage
  /// lateness and overtime are measured against, for an employee with no
  /// personal schedule.
  final int openMinutes;
  final int closeMinutes;

  /// A single break segment running longer than this is flagged as a
  /// "pause dépassée" — see `hasLateBreak` in `core/utils/attendance_status.dart`.
  final int maxBreakMinutes;

  /// How many days a `partial` commande may sit before the dashboard flags it.
  final int stalePartialOrderDays;
}
