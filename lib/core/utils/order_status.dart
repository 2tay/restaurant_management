import '../../models/models.dart';

/// Derivations over commandes and receipts.
///
/// The same role `stock_status.dart` plays for items: figures the UI needs that
/// fall out of the data rather than being stored on it. Kept out of the models
/// so those stay plain data for Phase 2 to persist untouched, and kept out of
/// the screens so eight of them cannot each invent their own arithmetic.

/// Thresholds the business rules are written against.
///
/// Named rather than inlined because both are the kind of number somebody will
/// want to argue about later, and an argument about a constant is much easier
/// than an argument about a number buried in a widget.
abstract final class OrderRules {
  /// A unit price moving by more than this at receiving time asks the receiver
  /// to confirm. Below it, the change is recorded silently.
  ///
  /// 15% is chosen to catch the two cases worth interrupting for — a genuine
  /// increase the owner must know about, and a typo — while letting the normal
  /// drift of fresh-produce pricing through without a dialog every delivery.
  static const double significantPriceChange = 0.15;

  /// How long a `partial` order may sit before the dashboard flags it.
  ///
  /// The default for the store setting of the same name. This is the real
  /// protection against orders left open forever, independent of what anyone
  /// tapped at receiving time.
  static const int defaultStalePartialDays = 7;
}

// -----------------------------------------------------------------------------
// Lines
// -----------------------------------------------------------------------------

/// Quantity × unit price.
double lineTotal(PurchaseOrderLine line) =>
    line.quantityOrdered * line.unitPrice;

/// What is still expected on this line.
///
/// Zero once the line is complete, and zero once it has been closed short —
/// a closed-short line is not coming, so it must stop counting towards "on
/// order" or the double-order indicator starts lying.
double lineOutstanding(PurchaseOrderLine line) {
  if (line.closedShort) return 0;
  final remaining = line.quantityOrdered - line.quantityReceived;
  return remaining > 0 ? remaining : 0;
}

/// How much never arrived, on a line the receiver closed short.
///
/// The figure that answers "which suppliers under-deliver?". Zero unless the
/// line was actually closed short.
double lineShortfall(PurchaseOrderLine line) {
  if (!line.closedShort) return 0;
  final missing = line.quantityOrdered - line.quantityReceived;
  return missing > 0 ? missing : 0;
}

/// True once nothing more is expected — complete, over-delivered, or closed.
bool lineIsSettled(PurchaseOrderLine line) =>
    line.closedShort || line.quantityReceived >= line.quantityOrdered;

// -----------------------------------------------------------------------------
// Orders
// -----------------------------------------------------------------------------

/// The commitment: what the whole order is worth at its ordered prices.
double orderTotal(PurchaseOrder order) {
  var total = 0.0;
  for (final line in order.lines) {
    total += lineTotal(line);
  }
  return total;
}

/// Quantity still expected across the order.
double orderOutstanding(PurchaseOrder order) {
  var total = 0.0;
  for (final line in order.lines) {
    total += lineOutstanding(line);
  }
  return total;
}

/// Sent or partial: the supplier has the document and goods may still arrive.
///
/// This is the definition "on order" counts against, so it is written once.
bool orderIsOpen(PurchaseOrder order) =>
    order.status == PurchaseOrderStatus.sent ||
    order.status == PurchaseOrderStatus.partial;

/// Drafts are the only editable orders. Once sent, the supplier holds a copy,
/// and an order that disagrees with the document in their inbox is worse than
/// no order at all.
bool orderIsEditable(PurchaseOrder order) =>
    order.status == PurchaseOrderStatus.draft;

/// Receiving is possible while anything is outstanding.
bool orderCanReceive(PurchaseOrder order) =>
    orderIsOpen(order) && order.lines.any((line) => !lineIsSettled(line));

/// A sent order may be cancelled only while nothing has been received.
///
/// Once goods are through the door, cancelling would orphan the stock movement
/// they created. Closing the order short is the correct exit at that point.
bool orderCanCancel(PurchaseOrder order) =>
    order.status == PurchaseOrderStatus.sent &&
    order.lines.every((line) => line.quantityReceived == 0);

/// The status an order should hold given the state of its lines.
///
/// Called after every receipt. Kept here rather than inside the mutation so
/// the transition table is one readable function instead of a chain of ifs
/// scattered through a confirm handler.
PurchaseOrderStatus statusAfterReceipt(List<PurchaseOrderLine> lines) {
  final allSettled = lines.every(lineIsSettled);
  if (allSettled) return PurchaseOrderStatus.received;
  return PurchaseOrderStatus.partial;
}

/// Days an order has been sitting in `partial`.
///
/// Counts from when it was sent rather than from the last receipt: an order
/// half-delivered three weeks ago and topped up yesterday is still an order
/// that has been open three weeks.
int daysOpen(PurchaseOrder order, {DateTime? now}) {
  final from = order.sentAt ?? order.createdAt;
  return (now ?? DateTime.now()).difference(from).inDays;
}

/// Partial for longer than the store's threshold.
bool orderIsStale(PurchaseOrder order, int thresholdDays, {DateTime? now}) =>
    order.status == PurchaseOrderStatus.partial &&
    daysOpen(order, now: now) > thresholdDays;

// -----------------------------------------------------------------------------
// Receipts
// -----------------------------------------------------------------------------

/// What a delivery was worth at the prices actually charged.
double receiptValue(GoodsReceipt receipt) {
  var total = 0.0;
  for (final line in receipt.lines) {
    total += line.quantityReceived * line.actualUnitPrice;
  }
  return total;
}

/// How a received quantity compares to what was ordered.
enum ReceiptLineOutcome {
  /// Exactly what was ordered.
  complete,

  /// Less than ordered.
  short,

  /// More than ordered — allowed, but it affects cost, so it is flagged.
  over,

  /// Not on the order at all.
  unordered,
}

ReceiptLineOutcome outcomeOf({
  required double ordered,
  required double received,
  required bool wasUnordered,
}) {
  if (wasUnordered) return ReceiptLineOutcome.unordered;
  if (received < ordered) return ReceiptLineOutcome.short;
  if (received > ordered) return ReceiptLineOutcome.over;
  return ReceiptLineOutcome.complete;
}

/// Anything the owner would want to look at twice.
bool isDiscrepancy(ReceiptLineOutcome outcome) =>
    outcome != ReceiptLineOutcome.complete;

/// True when a price moved far enough to be worth confirming.
///
/// Guards against a zero baseline: an item with no price on file has no
/// percentage to move by, and dividing by it would flag every first delivery.
bool priceMovedSignificantly(double oldPrice, double newPrice) {
  if (oldPrice <= 0) return false;
  return (newPrice - oldPrice).abs() / oldPrice > OrderRules.significantPriceChange;
}
