/// What the stock on hand actually cost.
///
/// The same role `stock_status.dart` and `order_status.dart` play: rules that
/// fall out of the data, kept out of the models so those stay plain data, and
/// kept out of the mutations so the arithmetic can be tested without writing to
/// anything.
///
/// ## The rule these functions exist to enforce
///
/// A purchase price and a stock cost are two different numbers answering two
/// questions that point in opposite directions in time:
///
/// * `SupplierPrice.pricePerUnit` — what the **next** unit will cost. Drives
///   ordering, the comparison report, and the overpay figure.
/// * `Item.averageCost` — what the units **already on the shelf** were paid
///   for. Drives the valuation, the cost of what was consumed, and the value of
///   what was wasted.
///
/// Using the purchase price for the second job is what made the valuation
/// revalue last week's stock at this morning's delivery price — 100 kg bought
/// at 8 € plus 50 kg at 10 € reported as 150 × 10 = 1 500 € rather than the
/// 1 300 € actually spent.
///
/// ## The method: weighted average (CUMP)
///
/// One cost per item, remixed when stock comes in, untouched when it goes out.
/// FIFO cost layers would be more precise, but a kitchen buys interchangeable
/// goods by the kilo with no lot tracking, so the precision buys nothing and
/// costs a layer table plus a painful correction path.
library;

/// How close two costs have to be to count as the same.
///
/// The convention the price code already uses, so a cost and a price are
/// compared the same way.
const double costEpsilon = 0.001;

/// The average cost after a delivery joins the stock on hand.
///
/// The whole fix in five lines: the stock already held keeps the cost it was
/// bought at, and only the arriving units come in at [inUnitPrice].
///
/// ```
/// 100 kg at 8.00  +  50 kg at 10.00
///   = (100 × 8.00 + 50 × 10.00) / 150
///   = 1 300 / 150
///   = 8.6667 per kg          — and the stock is worth 1 300, not 1 500
/// ```
///
/// Two situations skip the average and adopt [inUnitPrice] outright:
///
/// * **Nothing on hand.** There is nothing to average against, and the
///   arithmetic already agrees — `(0 + Q × P) / Q` is `P`.
/// * **Negative stock.** The app allows stock to go below zero on purpose, and
///   it means an earlier delivery was never recorded, so the baseline is
///   already known to be wrong. Averaging against it would spread that error
///   into the corrected figure instead of ending it. It can also produce a
///   *negative* average, which is not a number anyone can act on.
double costAfterStockIn({
  required double oldQuantity,
  required double? oldAverageCost,
  required double inQuantity,
  required double inUnitPrice,
}) {
  if (oldQuantity <= 0 || oldAverageCost == null) return inUnitPrice;

  final newQuantity = oldQuantity + inQuantity;
  if (newQuantity <= 0) return inUnitPrice;

  final oldValue = oldQuantity * oldAverageCost;
  final inValue = inQuantity * inUnitPrice;
  return (oldValue + inValue) / newQuantity;
}

/// The average cost after stock leaves. Unchanged, always.
///
/// A function rather than an omission, because "stock out does not move the
/// cost" is the property the whole method rests on, and a rule stated in code
/// survives where a rule implied by absent code does not.
///
/// Selling, wasting or spoiling stock cannot change what the stock still in the
/// fridge cost you. What it does produce is a number that did not exist before:
/// `|quantity| × averageCost` is the money that left with it.
double? costAfterStockOut(double? oldAverageCost) => oldAverageCost;

/// The average cost after a physical count corrects the quantity.
///
/// Unchanged as well, and for a plainer reason than stock out: no invoice was
/// involved. Nobody bought anything, so there is no new price to average in.
/// Units found join at the current average, units missing leave at it, and
/// their value is the shrinkage.
///
/// **One exception, in [openingCost] rather than here**: an item whose cost is
/// still unknown. See that function.
double? costAfterAdjustment(double? oldAverageCost) => oldAverageCost;

/// The cost an adjustment should leave behind, allowing for the opening
/// balance.
///
/// An item's first stock is recorded as an adjustment from zero — creating an
/// article with 40 kg in it *is* a stock change, and the movement log has to
/// say so from the article's first day. That single adjustment is the one
/// permitted to set a cost, because there is no earlier cost to preserve.
///
/// Written as a rule — *an adjustment may set a cost that is not yet known, and
/// may never change one that is* — rather than as a special case for one
/// caller. The opening balance is then simply the first time the rule applies,
/// and a later count on an item whose cost was never captured can benefit from
/// it too.
double? costAfterAdjustmentWithOpening({
  required double? oldAverageCost,
  required double? unitCost,
}) {
  if (oldAverageCost != null) return oldAverageCost;
  return unitCost;
}

/// What a quantity of stock is worth at a given cost.
///
/// Zero when the cost is unknown. An item with no cost and no supplier on file
/// contributes nothing rather than an invented figure: a valuation built partly
/// on guesses is worse than one that is visibly incomplete.
///
/// A negative quantity gives a negative value, deliberately. Negative stock is
/// a real state in this app — it means a delivery went unrecorded — and a
/// valuation that quietly clamped it to zero would hide the discrepancy at
/// exactly the moment somebody needs to see it.
double valueOf(double quantity, double? averageCost) {
  if (averageCost == null) return 0;
  return quantity * averageCost;
}

/// Whether two costs are the same to the nearest tenth of a cent.
bool sameCost(double? a, double? b) {
  if (a == null || b == null) return a == b;
  return (a - b).abs() < costEpsilon;
}
