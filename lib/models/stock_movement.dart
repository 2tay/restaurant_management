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
    this.unitCost,
    this.averageCostAfter,
    this.orderId,
    this.receiptId,
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

  /// The cost per unit this movement applied, in EUR.
  ///
  /// On a stock in it is the price paid — the same figure as [unitPrice], kept
  /// separately because [unitPrice] is what the supplier charged and this is
  /// what entered the stock; they are the same number today and there is no
  /// reason to make a future carriage or duty charge a schema change.
  ///
  /// On a stock out or an adjustment it is the item's average cost at that
  /// moment, which makes `|quantity| × unitCost` the money value of what left —
  /// cost of goods sold on a sale, and the euros in the bin on a waste line.
  final double? unitCost;

  /// The item's average cost once this movement had been applied.
  ///
  /// Recorded so the average is **verifiable**. Anyone can read down an item's
  /// history and watch the cost move from 8.00 to 8.67 on the day of a
  /// delivery, and see exactly which delivery did it.
  ///
  /// The same reasoning as an adjustment carrying both counts rather than only
  /// their difference: two numbers explain themselves, one does not. A cost
  /// that changes on its own is a number nobody trusts and everybody works
  /// around.
  final double? averageCostAfter;

  /// The commande this delivery was received against, when there was one.
  ///
  /// Null for a manual stock-in — somebody ran to the market and bought 5 kg of
  /// tomatoes with no order behind it. That path stays open on purpose; two
  /// ways in, one movement log.
  final String? orderId;

  /// The receipt that generated this movement.
  ///
  /// Together with [orderId] this is what makes the chain traceable in both
  /// directions: current quantity → movement → receipt → order → supplier.
  final String? receiptId;

  final String? note;
}
