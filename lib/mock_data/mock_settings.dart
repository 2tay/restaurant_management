import '../core/utils/order_status.dart';

/// Store preferences the user can change from Settings.
///
/// Held here rather than on [Store] because these are settings, not facts about
/// the shop, and because nothing persists in this phase — changing one lasts as
/// long as the app is open, which is enough to demo the effect on the dashboard.
///
/// Phase 2 moves this into the stores table. Deliberately a tiny mutable holder
/// rather than a provider: it is read from three screens and written from one,
/// and wiring state management around a single integer would be the wrong kind
/// of thoroughness.
abstract final class MockSettings {
  /// How many days a `partial` commande may sit before the dashboard flags it.
  ///
  /// The defence against orders left half-open forever. Without it the "on
  /// order" quantity stays permanently inflated by goods that were never
  /// coming, and the double-order indicator quietly starts lying.
  static int stalePartialOrderDays = OrderRules.defaultStalePartialDays;

  /// Restores the defaults. Used by tests so one test changing a setting cannot
  /// change the outcome of another.
  static void reset() {
    stalePartialOrderDays = OrderRules.defaultStalePartialDays;
  }
}
