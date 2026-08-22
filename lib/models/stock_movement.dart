/// Why stock left the building.
enum StockOutReason {
  /// Sold to a customer — the normal case.
  sale,

  /// Thrown away: prep offcuts, dropped, burnt.
  waste,

  /// Expired or spoiled.
  spoilage,

  /// Moved to another store in the same account.
  transfer,
}

/// The three ways stock changes.
enum StockMovementType {
  /// A delivery was received. Carries a supplier and the price paid.
  stockIn,

  /// Stock was consumed or lost. Carries a [StockOutReason].
  stockOut,

  /// A physical count disagreed with the system and the system was corrected.
  adjustment,
}

/// One change to an item's quantity.
///
/// The optional fields are populated per [type] — a delivery has a supplier and
/// a price, a usage entry has a reason, an adjustment has the two counts that
/// disagreed. Phase 2 may want three separate tables; for a UI phase one shape
/// with nullable fields keeps the history list trivial to render.
class StockMovement {
  const StockMovement({
    required this.id,
    required this.storeId,
    required this.itemId,
    required this.type,
    required this.quantity,
    required this.occurredAt,
    required this.userName,
    this.supplierId,
    this.unitPrice,
    this.reason,
    this.systemQuantity,
    this.countedQuantity,
    this.note,
  });

  final String id;
  final String storeId;
  final String itemId;
  final StockMovementType type;

  /// Signed: positive for stock in, negative for stock out. An adjustment is
  /// signed by direction of the correction.
  final double quantity;

  final DateTime occurredAt;

  /// Display name of whoever recorded it.
  final String userName;

  /// [StockMovementType.stockIn] only.
  final String? supplierId;

  /// [StockMovementType.stockIn] only — the price actually paid, which may
  /// differ from the supplier's current listed price.
  final double? unitPrice;

  /// [StockMovementType.stockOut] only.
  final StockOutReason? reason;

  /// [StockMovementType.adjustment] only — what the app believed.
  final double? systemQuantity;

  /// [StockMovementType.adjustment] only — what the physical count found.
  final double? countedQuantity;

  final String? note;
}
