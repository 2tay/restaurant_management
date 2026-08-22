/// One recorded change to a supplier's price for an item.
///
/// Scoped to the item–supplier *pair*, not to the item: "what has Metro charged
/// us for chicken breast over the last six months" is the question the price
/// history screen answers.
class PriceHistoryEntry {
  const PriceHistoryEntry({
    required this.id,
    required this.itemId,
    required this.supplierId,
    required this.oldPrice,
    required this.newPrice,
    required this.changedAt,
    required this.changedByName,
  });

  final String id;
  final String itemId;
  final String supplierId;
  final double oldPrice;
  final double newPrice;
  final DateTime changedAt;

  /// Display name of whoever made the change.
  final String changedByName;
}
