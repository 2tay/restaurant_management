import 'package:flutter/foundation.dart';

import '../../core/utils/order_status.dart';
import '../../models/models.dart';
import '../mock_goods_receipts.dart';
import '../mock_price_history.dart';
import '../mock_purchase_orders.dart';
import '../mock_queries.dart';
import '../mock_supplier_prices.dart';
import '../mock_team.dart';
import 'mock_write.dart';
import 'movement_mutations.dart';

/// Writes against the commandes.
///
/// The rule everything here defends:
/// **an order never changes stock — only a receipt does.**
///
/// Shares its plumbing — ids, the change signal, the reset snapshot — with
/// every other mutation family through [MockWrite].
abstract final class OrderMutations {
  // ---------------------------------------------------------------------------
  // References
  // ---------------------------------------------------------------------------

  /// The next human-readable commande number.
  ///
  /// Continues the seeded series rather than restarting, so a demo does not
  /// create `CMD-2026-001` next to `CMD-2026-018`.
  static String _nextReference(String storeId) {
    var highest = 0;
    for (final order in mockPurchaseOrders) {
      final digits = RegExp(r'(\d+)$').firstMatch(order.reference)?.group(1);
      final value = digits == null ? 0 : int.tryParse(digits) ?? 0;
      if (value > highest) highest = value;
    }
    final year = DateTime.now().year;
    return 'CMD-$year-${(highest + 1).toString().padLeft(3, '0')}';
  }

  // ---------------------------------------------------------------------------
  // Orders
  // ---------------------------------------------------------------------------

  /// Starts a commande. Always a draft — nothing is sent by being created.
  static PurchaseOrder createDraft({
    required String storeId,
    required String supplierId,
    required List<PurchaseOrderLine> lines,
    String? note,
  }) {
    final order = PurchaseOrder(
      id: MockWrite.id('po'),
      storeId: storeId,
      supplierId: supplierId,
      reference: _nextReference(storeId),
      status: PurchaseOrderStatus.draft,
      createdAt: DateTime.now(),
      lines: List.of(lines),
      note: note,
    );
    mockPurchaseOrders.add(order);
    MockWrite.changed();
    return order;
  }

  /// Replaces a draft's contents.
  ///
  /// Refuses anything that is not a draft. A sent order is locked because the
  /// supplier is holding a copy of it, and an order that quietly disagrees with
  /// the document in somebody's inbox is worse than no order at all.
  static void updateDraft(
    String orderId, {
    String? supplierId,
    List<PurchaseOrderLine>? lines,
    String? note,
  }) {
    final order = MockQueries.orderById(orderId);
    if (order == null || !orderIsEditable(order)) return;

    _replace(
      order.copyWith(
        supplierId: supplierId,
        lines: lines == null ? null : List.of(lines),
        note: note,
      ),
    );
  }

  /// Draft → sent. Still moves no stock.
  static void send(String orderId) {
    final order = MockQueries.orderById(orderId);
    if (order == null || order.status != PurchaseOrderStatus.draft) return;

    _replace(
      order.copyWith(
        status: PurchaseOrderStatus.sent,
        sentAt: DateTime.now(),
      ),
    );
  }

  /// Deletes a draft outright.
  ///
  /// Only a draft: it was never sent, so nothing outside the app knows it
  /// existed and there is nothing to keep an audit trail of. Sent orders are
  /// cancelled instead, which leaves the record standing.
  static void deleteDraft(String orderId) {
    final order = MockQueries.orderById(orderId);
    if (order == null || order.status != PurchaseOrderStatus.draft) return;

    mockPurchaseOrders.removeWhere((candidate) => candidate.id == orderId);
    MockWrite.changed();
  }

  /// Sent → cancelled, only while nothing has been received.
  ///
  /// Once goods are through the door they have created stock movements, and
  /// cancelling would orphan them. Closing the order short is the correct exit
  /// at that point.
  static void cancel(String orderId) {
    final order = MockQueries.orderById(orderId);
    if (order == null || !orderCanCancel(order)) return;

    _replace(
      order.copyWith(
        status: PurchaseOrderStatus.cancelled,
        closedAt: DateTime.now(),
      ),
    );
  }

  /// Closes an open order, accepting that the outstanding lines are not coming.
  ///
  /// Marks the remaining lines short rather than trimming them to what arrived.
  /// The gap between ordered and received is the record of the supplier
  /// under-delivering, and rewriting the quantities would erase precisely the
  /// figure that makes it worth recording.
  static void closeShort(String orderId) {
    final order = MockQueries.orderById(orderId);
    if (order == null || !orderIsOpen(order)) return;

    final lines = [
      for (final line in order.lines)
        lineIsSettled(line) ? line : line.copyWith(closedShort: true),
    ];

    _replace(
      order.copyWith(
        status: PurchaseOrderStatus.received,
        closedAt: DateTime.now(),
        lines: lines,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Receiving — the only path that moves stock
  // ---------------------------------------------------------------------------

  /// Records a delivery and applies everything that follows from it.
  ///
  /// In order:
  ///
  /// 1. Writes the [GoodsReceipt] — permanent, never edited or deleted.
  /// 2. Generates one **Stock In movement per line**, carrying the order and
  ///    receipt references, and moves the item's quantity. The movement log
  ///    stays the single source of truth for stock; nothing bypasses it.
  /// 3. Accumulates received quantities onto the order's lines and marks any
  ///    line the receiver closed short.
  /// 4. Moves the order to `partial` or `received` per
  ///    [statusAfterReceipt].
  /// 5. Where the delivery note disagreed with the price on file, writes a
  ///    price-history entry and updates that supplier's current price.
  ///
  /// Step 5 is how price history stays honest without anyone maintaining it:
  /// prices update as deliveries arrive rather than when somebody remembers to
  /// sit down and edit them.
  static GoodsReceipt confirmReceipt({
    required String orderId,
    required List<ReceiptDraftLine> lines,
    String? receivedByName,
    String? note,
  }) {
    final order = MockQueries.orderById(orderId)!;
    final receivedBy = receivedByName ?? mockCurrentUser.fullName;
    final now = DateTime.now();
    final receiptId = MockWrite.id('gr');

    final receiptLines = [
      for (final line in lines)
        GoodsReceiptLine(
          id: MockWrite.id('grl'),
          itemId: line.itemId,
          quantityOrdered: line.quantityOrdered,
          quantityReceived: line.quantityReceived,
          actualUnitPrice: line.actualUnitPrice,
          closedShort: line.closeShort,
          wasUnordered: line.wasUnordered,
          note: line.note,
        ),
    ];

    final receipt = GoodsReceipt(
      id: receiptId,
      orderId: orderId,
      storeId: order.storeId,
      receivedAt: now,
      receivedByName: receivedBy,
      lines: receiptLines,
      note: note,
    );
    mockGoodsReceipts.add(receipt);

    for (final line in receiptLines) {
      if (line.quantityReceived <= 0) continue;

      _recordStockIn(
        order: order,
        receiptId: receiptId,
        line: line,
        occurredAt: now,
        userName: receivedBy,
      );

      _applyPriceChange(
        order: order,
        line: line,
        changedAt: now,
        changedByName: receivedBy,
      );
    }

    _applyReceiptToOrder(order, lines, closedAt: now);
    MockWrite.changed();
    return receipt;
  }

  /// One delivered line becomes one stock movement and one quantity change.
  ///
  /// Delegates rather than doing it, and that matters more than it looks.
  /// [MovementMutations] is documented as the only thing in the app that
  /// changes an item's quantity, and this used to be a quiet second
  /// implementation of exactly that — filing its own movement and editing
  /// `mockItems` itself.
  ///
  /// It stayed harmless only while "apply a movement" meant one line of
  /// arithmetic. It stopped being harmless the moment a movement also had to
  /// remix the item's average cost: the same rule would have had to be written
  /// twice, and the second copy is always the one that gets forgotten.
  static void _recordStockIn({
    required PurchaseOrder order,
    required String receiptId,
    required GoodsReceiptLine line,
    required DateTime occurredAt,
    required String userName,
  }) {
    MovementMutations.recordStockIn(
      storeId: order.storeId,
      itemId: line.itemId,
      quantity: line.quantityReceived,
      supplierId: order.supplierId,
      unitPrice: line.actualUnitPrice,
      occurredAt: occurredAt,
      userName: userName,
      orderId: order.id,
      receiptId: receiptId,
      note: line.note,
    );
  }

  /// Writes the price change, if there was one.
  ///
  /// Compares against the price **on file** rather than against the ordered
  /// price. The two are normally the same — the order auto-fills from the file
  /// — but where they have drifted, the file is what the comparison report
  /// reads and therefore what has to end up correct.
  static void _applyPriceChange({
    required PurchaseOrder order,
    required GoodsReceiptLine line,
    required DateTime changedAt,
    required String changedByName,
  }) {
    final index = mockSupplierPrices.indexWhere(
      (price) =>
          price.itemId == line.itemId && price.supplierId == order.supplierId,
    );

    // An unordered item from a supplier we have no price on file for. Record
    // the link rather than dropping the price on the floor.
    if (index == -1) {
      mockSupplierPrices.add(
        SupplierPrice(
          id: MockWrite.id('sp'),
          itemId: line.itemId,
          supplierId: order.supplierId,
          pricePerUnit: line.actualUnitPrice,
          effectiveDate: changedAt,
          isDefault: MockQueries.pricesForItem(line.itemId).isEmpty,
        ),
      );
      return;
    }

    final current = mockSupplierPrices[index];
    if ((current.pricePerUnit - line.actualUnitPrice).abs() < 0.001) return;

    mockPriceHistory.add(
      PriceHistoryEntry(
        id: MockWrite.id('ph'),
        itemId: line.itemId,
        supplierId: order.supplierId,
        oldPrice: current.pricePerUnit,
        newPrice: line.actualUnitPrice,
        changedAt: changedAt,
        changedByName: changedByName,
      ),
    );

    mockSupplierPrices[index] = SupplierPrice(
      id: current.id,
      itemId: current.itemId,
      supplierId: current.supplierId,
      pricePerUnit: line.actualUnitPrice,
      effectiveDate: changedAt,
      isDefault: current.isDefault,
    );
  }

  /// Folds a receipt back onto its order's lines and status.
  static void _applyReceiptToOrder(
    PurchaseOrder order,
    List<ReceiptDraftLine> received, {
    required DateTime closedAt,
  }) {
    final lines = [
      for (final line in order.lines) _accumulate(line, received),
    ];

    final status = statusAfterReceipt(lines);

    _replace(
      order.copyWith(
        lines: lines,
        status: status,
        closedAt: status == PurchaseOrderStatus.received ? closedAt : null,
      ),
    );
  }

  static PurchaseOrderLine _accumulate(
    PurchaseOrderLine line,
    List<ReceiptDraftLine> received,
  ) {
    var quantity = line.quantityReceived;
    var closedShort = line.closedShort;
    var matched = false;

    for (final entry in received) {
      if (entry.wasUnordered || entry.itemId != line.itemId) continue;
      matched = true;
      quantity += entry.quantityReceived;
      if (entry.closeShort) closedShort = true;
    }

    if (!matched) return line;
    return line.copyWith(
      quantityReceived: quantity,
      closedShort: closedShort,
    );
  }

  static void _replace(PurchaseOrder order) {
    final index = mockPurchaseOrders.indexWhere(
      (candidate) => candidate.id == order.id,
    );
    if (index == -1) return;
    mockPurchaseOrders[index] = order;
    MockWrite.changed();
  }
}

/// One line of a delivery as the receiving screen holds it, before confirming.
///
/// Separate from [GoodsReceiptLine] because this is input rather than record:
/// it carries the ordered price so the confirm step can tell whether the price
/// moved, and `closeShort` is a decision the receiver made rather than a fact
/// about the delivery.
@immutable
class ReceiptDraftLine {
  const ReceiptDraftLine({
    required this.itemId,
    required this.quantityOrdered,
    required this.quantityReceived,
    required this.orderedUnitPrice,
    required this.actualUnitPrice,
    this.closeShort = false,
    this.wasUnordered = false,
    this.note,
  });

  final String itemId;

  /// What was still outstanding on the line when the van arrived. Zero for an
  /// item that was not on the order.
  final double quantityOrdered;

  final double quantityReceived;

  /// What the order said this would cost — kept for comparison, not recorded.
  final double orderedUnitPrice;

  /// What the delivery note says it actually cost.
  final double actualUnitPrice;

  /// Short delivery, and the receiver decided the balance is not coming.
  final bool closeShort;

  final bool wasUnordered;

  final String? note;
}
