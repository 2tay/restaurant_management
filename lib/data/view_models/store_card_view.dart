import '../../models/store.dart';

/// One establishment as the selector grid draws it.
///
/// The card shows how many articles the establishment holds and how many of
/// them need attention, which is the reason the app opens on a grid rather than
/// dropping somebody into the store they used last: an owner with three
/// locations can see which one needs them before choosing.
///
/// Both numbers were `MockQueries` calls inside the card's `build`, which is a
/// full scan of every article in the account per card per rebuild. They are two
/// counting queries now, and the card is handed the answers.
class StoreCardView {
  const StoreCardView({
    required this.store,
    required this.itemCount,
    required this.lowStockCount,
  });

  final Store store;

  /// Zero marks a brand new establishment, which the card badges as such.
  final int itemCount;

  /// At or below the threshold — the same rule as the alerts screen, so the
  /// badge here and the count there cannot disagree.
  final int lowStockCount;
}
