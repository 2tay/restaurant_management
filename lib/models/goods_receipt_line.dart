/// One line of one delivery: what was ordered, what actually turned up, and
/// what it actually cost.
///
/// Keeping [quantityOrdered] on the receipt rather than reading it back off the
/// order is deliberate. The order can be received again later and its own
/// figures move; the receipt has to keep saying what was outstanding *on the
/// day*, or the discrepancy record quietly rewrites itself.
class GoodsReceiptLine {
  const GoodsReceiptLine({
    required this.id,
    required this.itemId,
    required this.quantityOrdered,
    required this.quantityReceived,
    required this.actualUnitPrice,
    this.closedShort = false,
    this.wasUnordered = false,
    this.note,
  });

  final String id;
  final String itemId;

  /// What was still outstanding on this line when the delivery arrived. Zero
  /// for an unordered line.
  final double quantityOrdered;

  final double quantityReceived;

  /// The price on the delivery note. Where it differs from the ordered price,
  /// confirming the receipt writes a price-history entry and updates the
  /// supplier's current price — which is how price history stays current
  /// without anyone maintaining it by hand.
  final double actualUnitPrice;

  /// Short delivery, and the receiver decided the balance is not coming.
  final bool closedShort;

  /// The driver brought something that was not on the order.
  ///
  /// Allowed, because refusing it would just send staff to the manual stock-in
  /// screen and lose the connection to the delivery. But it is flagged on the
  /// line and in the receipt: an unordered item arriving is exactly the kind of
  /// thing that should never be invisible.
  final bool wasUnordered;

  /// Free text — "2 cageots abîmés, repris par le chauffeur".
  final String? note;
}
