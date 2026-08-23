import '../../models/models.dart';
import '../mock_items.dart';
import '../mock_stock_movements.dart';
import '../mock_team.dart';
import 'mock_write.dart';

/// Writes against the stock movement log.
///
/// **This is the only file in the app that changes an item's quantity.** Every
/// other path — a delivery received against a commande, a manual stock-in, a
/// stock-out mid-service, a physical count, the opening balance on a brand-new
/// article — comes through here and leaves a movement behind.
///
/// That single-writer rule is what makes the movement history mean something.
/// If a screen could set a quantity directly, "quantity equals opening balance
/// plus the sum of its movements" would stop holding, and the log would become
/// a partial record that looks complete — which is worse than no log at all.
/// `tool/ux_audit.py` enforces it mechanically.
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
        userName: userName ?? mockCurrentUser.fullName,
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
        userName: userName ?? mockCurrentUser.fullName,
        reason: reason,
        note: note,
      ),
    );
  }

  /// A physical count disagreed with the system and the system was corrected.
  ///
  /// Carries both figures rather than only the difference, because "we thought
  /// 40, we counted 31" is the useful record and "−9" on its own is not.
  static StockMovement recordAdjustment({
    required String storeId,
    required String itemId,
    required double systemQuantity,
    required double countedQuantity,
    DateTime? occurredAt,
    String? userName,
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
        userName: userName ?? mockCurrentUser.fullName,
        systemQuantity: systemQuantity,
        countedQuantity: countedQuantity,
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
  static StockMovement? recordOpeningBalance({
    required String storeId,
    required String itemId,
    required double quantity,
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
      note: note,
    );
  }

  /// Files the movement and moves the stock. The only quantity writer.
  static StockMovement _record(StockMovement movement) {
    // Newest first, matching how every screen reads the log.
    mockStockMovements.insert(0, movement);
    _applyToItem(movement.itemId, movement.quantity, movement.occurredAt);
    MockWrite.changed();
    return movement;
  }

  static void _applyToItem(String itemId, double delta, DateTime at) {
    final index = mockItems.indexWhere((item) => item.id == itemId);
    if (index == -1) return;

    final item = mockItems[index];
    mockItems[index] = item.copyWith(
      quantity: item.quantity + delta,
      updatedAt: at,
    );
  }
}
