import '../../core/utils/employee_status.dart';
import '../../core/utils/stock_cost.dart';
import '../../models/models.dart';
import '../mock_items.dart';
import '../mock_session.dart';
import '../mock_stock_movements.dart';
import 'mock_write.dart';

/// Writes against the stock movement log.
///
/// **This is the only file in the app that changes an item's quantity, and the
/// only one that changes its average cost.** Every other path — a delivery
/// received against a commande, a manual stock-in, a stock-out mid-service, a
/// physical count, the opening balance on a brand-new article — comes through
/// here and leaves a movement behind.
///
/// That single-writer rule is what makes the movement history mean something.
/// If a screen could set a quantity directly, "quantity equals opening balance
/// plus the sum of its movements" would stop holding, and the log would become
/// a partial record that looks complete — which is worse than no log at all.
/// `tool/ux_audit.py` enforces it mechanically.
///
/// Cost is held to the same standard for the same reason. `Item.averageCost` is
/// path-dependent — it depends on the order deliveries happened in — so it is
/// stored rather than derived. Storing a running total is only safe while
/// exactly one place advances it, and every movement records both the cost it
/// applied and the average it produced, so the number stays auditable and
/// rebuildable rather than becoming a figure that changes on its own.
///
/// The arithmetic itself lives in `core/utils/stock_cost.dart`, so it can be
/// tested without writing to anything.
abstract final class MovementMutations {
  /// A delivery arriving.
  ///
  /// [orderId] and [receiptId] are set when this came from receiving a
  /// commande, and null when somebody bought 5 kg of tomatoes at the market on
  /// the way in. Both paths are legitimate and both land in the same log.
  static StockMovement recordStockIn({
    required String storeId,
    required String itemId,
    required double quantity,
    String? supplierId,
    double? unitPrice,
    DateTime? occurredAt,
    String? userName,
    String? orderId,
    String? receiptId,
    String? note,
  }) {
    return _record(
      StockMovement(
        id: MockWrite.id('mv'),
        storeId: storeId,
        itemId: itemId,
        type: StockMovementType.stockIn,
        quantity: quantity.abs(),
        occurredAt: occurredAt ?? DateTime.now(),
        userName: userName ?? employeeDisplayName(mockCurrentEmployee),
        supplierId: supplierId,
        unitPrice: unitPrice,
        orderId: orderId,
        receiptId: receiptId,
        note: note,
      ),
    );
  }

  /// Stock consumed or lost.
  ///
  /// The quantity is stored negative whatever sign the caller passes, so the
  /// log always adds up.
  ///
  /// **Nothing stops this taking an item below zero, deliberately.** Refusing
  /// would make staff either lie to the app or give up on it, and negative
  /// stock is a useful signal in its own right — it means a delivery went
  /// unrecorded. The stock-out screen warns before submitting; the adjustment
  /// screen is how it gets put right.
  static StockMovement recordStockOut({
    required String storeId,
    required String itemId,
    required double quantity,
    required StockOutReason reason,
    DateTime? occurredAt,
    String? userName,
    String? note,
  }) {
    return _record(
      StockMovement(
        id: MockWrite.id('mv'),
        storeId: storeId,
        itemId: itemId,
        type: StockMovementType.stockOut,
        quantity: -quantity.abs(),
        occurredAt: occurredAt ?? DateTime.now(),
        userName: userName ?? employeeDisplayName(mockCurrentEmployee),
        reason: reason,
        note: note,
      ),
    );
  }

  /// A physical count disagreed with the system and the system was corrected.
  ///
  /// Carries both figures rather than only the difference, because "we thought
  /// 40, we counted 31" is the useful record and "−9" on its own is not.
  ///
  /// [unitCost] is normally left alone: a count corrects a quantity, not a
  /// price, so units found or missing move at whatever the stock already cost.
  /// It is offered only for the opening balance, where the item has no cost yet
  /// and there is nothing to preserve — see [recordOpeningBalance].
  static StockMovement recordAdjustment({
    required String storeId,
    required String itemId,
    required double systemQuantity,
    required double countedQuantity,
    DateTime? occurredAt,
    String? userName,
    double? unitCost,
    String? note,
  }) {
    return _record(
      StockMovement(
        id: MockWrite.id('mv'),
        storeId: storeId,
        itemId: itemId,
        type: StockMovementType.adjustment,
        // Signed by the direction of the correction, so the movement still
        // sums correctly against the item's quantity.
        quantity: countedQuantity - systemQuantity,
        occurredAt: occurredAt ?? DateTime.now(),
        userName: userName ?? employeeDisplayName(mockCurrentEmployee),
        systemQuantity: systemQuantity,
        countedQuantity: countedQuantity,
        unitCost: unitCost,
        note: note,
      ),
    );
  }

  /// The stock a brand-new article starts with.
  ///
  /// Recorded as an adjustment from zero rather than written straight onto the
  /// item. Creating an article with 40 kg in it *is* a stock change, and if the
  /// form set the number directly the movement log would be incomplete from the
  /// article's first day.
  ///
  /// It also means a newly created item's history opens with a line explaining
  /// where its stock came from, instead of an unexplained 40 with no entries —
  /// which reads as a bug.
  ///
  /// [unitCost] is what that opening stock was bought at, and it is the one
  /// adjustment permitted to set an item's cost — there is no earlier cost for
  /// it to overwrite. Null leaves the cost unknown, and the item then
  /// contributes nothing to the valuation until a real delivery arrives.
  /// Understating beats inventing.
  static StockMovement? recordOpeningBalance({
    required String storeId,
    required String itemId,
    required double quantity,
    double? unitCost,
    String? userName,
    String? note,
  }) {
    if (quantity == 0) return null;
    return recordAdjustment(
      storeId: storeId,
      itemId: itemId,
      systemQuantity: 0,
      countedQuantity: quantity,
      userName: userName,
      unitCost: unitCost,
      note: note,
    );
  }

  /// Files the movement and moves the stock. The only quantity and cost writer.
  ///
  /// The movement is applied to the item **first**, because applying it is what
  /// works out the cost figures, and those figures then get stamped onto the
  /// movement before it is filed. A movement is a record of what happened, so
  /// it cannot be written until it is known.
  static StockMovement _record(StockMovement movement) {
    final applied = _applyToItem(movement);

    final recorded = StockMovement(
      id: movement.id,
      storeId: movement.storeId,
      itemId: movement.itemId,
      type: movement.type,
      quantity: movement.quantity,
      occurredAt: movement.occurredAt,
      userName: movement.userName,
      supplierId: movement.supplierId,
      unitPrice: movement.unitPrice,
      reason: movement.reason,
      systemQuantity: movement.systemQuantity,
      countedQuantity: movement.countedQuantity,
      unitCost: applied.unitCost,
      averageCostAfter: applied.averageCost,
      orderId: movement.orderId,
      receiptId: movement.receiptId,
      note: movement.note,
    );

    // Newest first, matching how every screen reads the log.
    mockStockMovements.insert(0, recorded);
    MockWrite.changed();
    return recorded;
  }

  /// Moves the item's quantity and remixes its average cost.
  ///
  /// **Order matters here.** The cost is worked out from the quantity *before*
  /// the movement is applied, because that is what the weighted average
  /// averages against. Doing it the other way round produces numbers that look
  /// entirely plausible and are wrong, which is the worst way for a money
  /// figure to fail.
  static _AppliedCost _applyToItem(StockMovement movement) {
    final index = mockItems.indexWhere((item) => item.id == movement.itemId);
    if (index == -1) return const _AppliedCost(null, null);

    final item = mockItems[index];
    final applied = _costOf(item, movement);

    mockItems[index] = item.copyWith(
      quantity: item.quantity + movement.quantity,
      averageCost: applied.averageCost,
      updatedAt: movement.occurredAt,
    );

    return applied;
  }

  /// What this movement does to the item's cost, and at what unit cost it did
  /// it.
  static _AppliedCost _costOf(Item item, StockMovement movement) {
    switch (movement.type) {
      case StockMovementType.stockIn:
        // A delivery with no price recorded is not a free delivery, it is an
        // unrecorded price. Falling back to what the stock already cost leaves
        // the average where it was rather than dragging it towards zero, which
        // would quietly destroy the item's value.
        final unitCost = movement.unitPrice ?? item.averageCost;
        if (unitCost == null) return const _AppliedCost(null, null);

        return _AppliedCost(
          costAfterStockIn(
            oldQuantity: item.quantity,
            oldAverageCost: item.averageCost,
            inQuantity: movement.quantity,
            inUnitPrice: unitCost,
          ),
          unitCost,
        );

      case StockMovementType.stockOut:
        // Unchanged, always. What left is valued at what it cost, which is what
        // makes a waste line answer "how many euros went in the bin".
        return _AppliedCost(
          costAfterStockOut(item.averageCost),
          item.averageCost,
        );

      case StockMovementType.adjustment:
        // Also unchanged — no invoice was involved — except on an item whose
        // cost is still unknown, where there is nothing to preserve. That is
        // the opening balance, and the rule is stated in `stock_cost.dart`
        // rather than special-cased for one caller.
        final cost = costAfterAdjustmentWithOpening(
          oldAverageCost: item.averageCost,
          unitCost: movement.unitCost,
        );
        return _AppliedCost(cost, cost);
    }
  }
}

/// The cost figures a movement produced, on their way onto the movement.
class _AppliedCost {
  const _AppliedCost(this.averageCost, this.unitCost);

  /// The item's average once the movement landed.
  final double? averageCost;

  /// The cost per unit this movement itself applied.
  final double? unitCost;
}
