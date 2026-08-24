/// One item on a commande.
///
/// Carries both what was ordered and what has arrived so far, because an order
/// can be received across several deliveries. The difference between them is
/// the outstanding quantity, which is what the "already on order" indicator
/// counts and what the receiving screen pre-fills.
class PurchaseOrderLine {
  const PurchaseOrderLine({
    required this.id,
    required this.itemId,
    required this.quantityOrdered,
    required this.unitPrice,
    this.quantityReceived = 0,
    this.closedShort = false,
  });

  final String id;
  final String itemId;

  final double quantityOrdered;

  /// Accumulates across receipts. Starts at zero.
  final double quantityReceived;

  /// Per unit, in EUR. Auto-filled from the supplier's current price when the
  /// line is added, then editable — negotiation happens, and the ordered price
  /// is what the supplier agreed to, not what is on file.
  final double unitPrice;

  /// The receiver accepted a short delivery and closed the line.
  ///
  /// The shortfall is deliberately **not** written back into
  /// [quantityOrdered]. Ordered 10, received 8, closed short: the line still
  /// says 10 were ordered. Rewriting it to 8 would erase the only record that
  /// this supplier under-delivered, which is exactly the figure an owner needs.
  final bool closedShort;

  /// See the note on `PurchaseOrder.copyWith` — a constructor convenience, not
  /// business logic.
  PurchaseOrderLine copyWith({
    double? quantityOrdered,
    double? quantityReceived,
    double? unitPrice,
    bool? closedShort,
  }) {
    return PurchaseOrderLine(
      id: id,
      itemId: itemId,
      quantityOrdered: quantityOrdered ?? this.quantityOrdered,
      quantityReceived: quantityReceived ?? this.quantityReceived,
      unitPrice: unitPrice ?? this.unitPrice,
      closedShort: closedShort ?? this.closedShort,
    );
  }
}
