/// The price one supplier charges for one item.
///
/// This is the item–supplier link, and the only place a price lives. Several
/// of these can exist for the same [itemId] with different [supplierId]s — that
/// is the whole point, and it is what the price comparison report reads.
class SupplierPrice {
  const SupplierPrice({
    required this.id,
    required this.itemId,
    required this.supplierId,
    required this.pricePerUnit,
    required this.effectiveDate,
    required this.isDefault,
  });

  final String id;
  final String itemId;
  final String supplierId;

  /// Price per one of the item's units, in EUR.
  final double pricePerUnit;

  /// When this price took effect. Superseded prices become
  /// `PriceHistoryEntry` rows.
  final DateTime effectiveDate;

  /// Marks the supplier normally used for this item. At most one per item.
  final bool isDefault;
}
