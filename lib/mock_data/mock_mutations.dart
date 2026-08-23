import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/order_status.dart';
import '../models/models.dart';
import 'mock_goods_receipts.dart';
import 'mock_items.dart';
import 'mock_price_history.dart';
import 'mock_purchase_orders.dart';
import 'mock_queries.dart';
import 'mock_stock_movements.dart';
import 'mock_supplier_prices.dart';
import 'mock_team.dart';

/// Writes against the mock lists.
///
/// The counterpart to [MockQueries], which only reads. This exists because the
/// ordering flow is not demonstrable as a set of static screens: the whole
/// point of receiving a delivery is that stock goes up and the price history
/// gains an entry, and a screen that shows a success message while nothing
/// moves teaches the client the wrong thing about what they are buying.
///
/// **It is still not a data layer.** No repository, no storage, no network —
/// these are list edits held in memory for as long as the app is open, and a
/// hot restart puts everything back. What matters is that the *rules* are here
/// and correct, because Phase 2 reimplements exactly these against real
/// local-first storage, and the screens calling them barely move.
///
/// The one rule everything else defends:
/// **an order never changes stock — only a receipt does.**
abstract final class MockOperations {
  // ---------------------------------------------------------------------------
  // Change notification
  // ---------------------------------------------------------------------------

  /// Bumped after every write.
  ///
  /// Screens read the mock lists directly at build time, so without a signal a
  /// page already on screen keeps showing what it read before the mutation —
  /// most visibly when the receiving screen pops back to an order detail that
  /// still says nothing has arrived.
  ///
  /// A revision counter rather than fine-grained events: with a dataset this
  /// size, "something changed, look again" is both correct and cheaper to
  /// reason about than a dependency graph. Phase 2 replaces it with whatever
  /// the storage layer's own change stream is.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void _changed() => revision.value++;

  // ---------------------------------------------------------------------------
  // Ids and references
  // ---------------------------------------------------------------------------

  static int _sequence = 0;

  static String _id(String prefix) {
    _sequence++;
    return '$prefix-new-$_sequence';
  }

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
      id: _id('po'),
      storeId: storeId,
      supplierId: supplierId,
      reference: _nextReference(storeId),
      status: PurchaseOrderStatus.draft,
      createdAt: DateTime.now(),
      lines: List.of(lines),
      note: note,
    );
    mockPurchaseOrders.add(order);
    _changed();
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
    _changed();
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
    final receiptId = _id('gr');

    final receiptLines = [
      for (final line in lines)
        GoodsReceiptLine(
          id: _id('grl'),
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
    _changed();
    return receipt;
  }

  /// One delivered line becomes one stock movement and one quantity change.
  static void _recordStockIn({
    required PurchaseOrder order,
    required String receiptId,
    required GoodsReceiptLine line,
    required DateTime occurredAt,
    required String userName,
  }) {
    mockStockMovements.insert(
      0,
      StockMovement(
        id: _id('mv'),
        storeId: order.storeId,
        itemId: line.itemId,
        type: StockMovementType.stockIn,
        quantity: line.quantityReceived,
        occurredAt: occurredAt,
        userName: userName,
        supplierId: order.supplierId,
        unitPrice: line.actualUnitPrice,
        orderId: order.id,
        receiptId: receiptId,
        note: line.note,
      ),
    );

    final index = mockItems.indexWhere((item) => item.id == line.itemId);
    if (index == -1) return;

    final item = mockItems[index];
    mockItems[index] = item.copyWith(
      quantity: item.quantity + line.quantityReceived,
      updatedAt: occurredAt,
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
          id: _id('sp'),
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
        id: _id('ph'),
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
    _changed();
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

/// Exposes [MockOperations.revision] to the widget tree.
///
/// Screens that show anything a write can change watch this, so a receipt
/// confirmed on one screen is visible on the one underneath it.
class MockDataRevision extends Notifier<int> {
  @override
  int build() {
    void listener() => state = MockOperations.revision.value;
    MockOperations.revision.addListener(listener);
    ref.onDispose(() => MockOperations.revision.removeListener(listener));
    return MockOperations.revision.value;
  }
}

final mockDataRevisionProvider = NotifierProvider<MockDataRevision, int>(
  MockDataRevision.new,
);
