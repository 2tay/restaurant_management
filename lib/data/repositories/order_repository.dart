import 'package:drift/drift.dart';

import '../../core/utils/order_status.dart';
import '../../models/goods_receipt.dart';
import '../../models/goods_receipt_line.dart';
import '../../models/purchase_order.dart';
import '../../models/purchase_order_line.dart';
import '../database/app_database.dart';
import '../mappers/mappers.dart';
import 'account_repository.dart';
import 'movement_repository.dart';
import 'new_id.dart';
import 'store_repository.dart';
import 'supplier_repository.dart';

/// What would stop a commande being received.
enum ReceiptBlock {
  /// It is not there. Reachable through a stale route or a second device.
  noSuchOrder,

  /// A draft has not been sent, and a cancelled or finished commande has
  /// nothing left to arrive.
  notReceivable,
}

/// One line of a delivery as the receiving screen holds it, before confirming.
///
/// Separate from `GoodsReceiptLine` because this is input rather than record: it
/// carries the ordered price so the confirm step can tell whether the price
/// moved, and `closeShort` is a decision the receiver made rather than a fact
/// about the delivery.
///
/// Not annotated `@immutable`: every field is final and the constructor is
/// const, and reaching for `package:meta` to say so would be the data layer's
/// first dependency outside drift.
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
  /// article that was not on the commande.
  final double quantityOrdered;

  final double quantityReceived;

  /// What the commande said this would cost — kept for comparison, not recorded.
  final double orderedUnitPrice;

  /// What the delivery note says it actually cost.
  final double actualUnitPrice;

  /// Short delivery, and the receiver decided the balance is not coming.
  final bool closeShort;

  final bool wasUnordered;

  final String? note;
}

/// Commandes and the deliveries against them.
///
/// Every read that returns a commande returns it **with its lines**, because a
/// commande without them is not something any screen can render. That is one
/// left join and a fold, not a query per order.
class OrderRepository {
  const OrderRepository(this._db);

  final AppDatabase _db;

  // ---------------------------------------------------------------------------
  // Commandes
  // ---------------------------------------------------------------------------

  /// Newest first — the commandes list order.
  Stream<List<PurchaseOrder>> watchOrders(String storeId) =>
      _orders(_db.purchaseOrders.storeId.equals(storeId)).watch().map(_assemble);

  Future<List<PurchaseOrder>> orders(String storeId) =>
      _orders(_db.purchaseOrders.storeId.equals(storeId)).get().then(_assemble);

  Stream<PurchaseOrder?> watchOrder(String id) => _orders(
    _db.purchaseOrders.id.equals(id),
  ).watch().map((rows) => _assemble(rows).firstOrNull);

  Future<PurchaseOrder?> order(String id) => _orders(
    _db.purchaseOrders.id.equals(id),
  ).get().then((rows) => _assemble(rows).firstOrNull);

  /// Sent or partial: the supplier holds the document and goods may still come.
  Stream<List<PurchaseOrder>> watchOpenOrders(String storeId) =>
      _orders(_openIn(storeId)).watch().map(_assemble);

  Future<List<PurchaseOrder>> openOrders(String storeId) =>
      _orders(_openIn(storeId)).get().then(_assemble);

  Future<List<PurchaseOrder>> ordersForSupplier(String supplierId) => _orders(
    _db.purchaseOrders.supplierId.equals(supplierId),
  ).get().then(_assemble);

  /// Open commandes that still have something outstanding for this article.
  ///
  /// Powers the "déjà commandé" flag on the create screen and the open-orders
  /// panel on the item detail. A manager who ordered on Monday and is looking at
  /// a low stock level on Wednesday needs to see that the goods are in transit
  /// rather than missing.
  ///
  /// Filtered in Dart, deliberately. The lines are already loaded by the query
  /// above, so this costs nothing extra, and it lets `lineOutstanding` stay the
  /// single definition of what "still owed" means. The one place that rule is
  /// also written in SQL is [onOrderQuantity], where it removes a query per row;
  /// a test holds the two spellings to the same answer.
  Stream<List<PurchaseOrder>> watchOpenOrdersForItem(
    String storeId,
    String itemId,
  ) => watchOpenOrders(storeId).map((orders) => _outstandingFor(orders, itemId));

  Future<List<PurchaseOrder>> openOrdersForItem(String storeId, String itemId) =>
      openOrders(storeId).then((orders) => _outstandingFor(orders, itemId));

  /// Total quantity of an article still expected across every open commande.
  ///
  /// The counterpart to "on hand". Low-stock alerts still fire on what is
  /// physically in the establishment — goods in a van do not cook dinner — but
  /// an article that is low *and already ordered* has to look different from one
  /// that is low and nobody has acted.
  ///
  /// This one is SQL. It is read once per row of the inventory and alerts lists,
  /// and answering it in Dart meant loading every open commande to add up two
  /// numbers.
  Stream<double> watchOnOrderQuantity(String storeId, String itemId) =>
      _onOrderQuery(storeId, itemId).watchSingle().map(_readOutstanding);

  Future<double> onOrderQuantity(String storeId, String itemId) =>
      _onOrderQuery(storeId, itemId).getSingle().then(_readOutstanding);

  /// Commandes sitting in `partial` past this establishment's threshold.
  ///
  /// The threshold is a column on the store since this phase. [now] is injected
  /// so a test can decide what "today" is rather than waiting for one.
  Future<List<PurchaseOrder>> staleOrders(String storeId, {DateTime? now}) async {
    final threshold = await StoreRepository(_db).stalePartialOrderDays(storeId);
    final all = await orders(storeId);
    return all.where((o) => orderIsStale(o, threshold, now: now)).toList();
  }

  // ---------------------------------------------------------------------------
  // Receipts
  // ---------------------------------------------------------------------------

  /// Deliveries against one commande, **oldest first**.
  ///
  /// The order they happened in, which is how the receipts tab reads and — more
  /// importantly — what the `/2` in `BR-2026-014/2` counts. A receipt's number is
  /// its position here, so this order is part of the document rather than a
  /// display preference.
  Stream<List<GoodsReceipt>> watchReceiptsForOrder(String orderId) =>
      _receipts(_db.goodsReceipts.orderId.equals(orderId))
          .watch()
          .map(_assembleReceipts);

  Future<List<GoodsReceipt>> receiptsForOrder(String orderId) =>
      _receipts(_db.goodsReceipts.orderId.equals(orderId))
          .get()
          .then(_assembleReceipts);

  Future<GoodsReceipt?> receipt(String id) => _receipts(
    _db.goodsReceipts.id.equals(id),
  ).get().then((rows) => _assembleReceipts(rows).firstOrNull);

  /// The quotable number for one delivery — `BR-2026-014/2`.
  ///
  /// Resolves the receipt's position among its commande's deliveries and hands
  /// both to `receiptReference`. The arithmetic lives there so it can be tested
  /// without a database; this is only the lookup.
  ///
  /// Falls back to a bare `BR-<id>` for a receipt whose commande has gone
  /// missing. That cannot happen through the app, but it keeps the document
  /// renderable rather than throwing at the moment somebody needs to send it.
  Future<String> receiptReferenceOf(GoodsReceipt receipt) async {
    final row = await (_db.select(
      _db.purchaseOrders,
    )..where((o) => o.id.equals(receipt.orderId))).getSingleOrNull();
    if (row == null) return 'BR-${receipt.id}';

    final siblings = await receiptsForOrder(receipt.orderId);
    final index = siblings.indexWhere((s) => s.id == receipt.id);
    return receiptReference(row.reference, index == -1 ? 1 : index + 1);
  }


  // ---------------------------------------------------------------------------
  // Writes — commandes
  // ---------------------------------------------------------------------------
  //
  // The rule everything here defends:
  // **a commande never changes stock — only a receipt does.**

  /// Starts a commande. Always a draft — nothing is sent by being created.
  Future<PurchaseOrder> createDraft({
    required String storeId,
    required String supplierId,
    required List<PurchaseOrderLine> lines,
    String? note,
  }) {
    return _db.transaction(() async {
      final order = PurchaseOrder(
        id: newId(),
        storeId: storeId,
        supplierId: supplierId,
        // Inside the transaction, so two drafts started in the same second
        // cannot take the same number. Phase 1 scanned the list outside any
        // such protection, which was safe only because nothing was concurrent.
        reference: await _nextReference(),
        status: PurchaseOrderStatus.draft,
        createdAt: DateTime.now(),
        lines: List.of(lines),
        note: note,
      );

      await _db.into(_db.purchaseOrders).insert(orderToRow(order));
      await _writeLines(order.id, order.lines);
      return order;
    });
  }

  /// Replaces a draft's contents.
  ///
  /// Refuses anything that is not a draft. A sent commande is locked because the
  /// supplier is holding a copy of it, and a commande that quietly disagrees
  /// with the document in somebody's inbox is worse than none at all.
  Future<PurchaseOrder?> updateDraft(
    String orderId, {
    String? supplierId,
    List<PurchaseOrderLine>? lines,
    String? note,
  }) {
    return _db.transaction(() async {
      final existing = await order(orderId);
      if (existing == null || !orderIsEditable(existing)) return null;

      final updated = existing.copyWith(
        supplierId: supplierId,
        lines: lines == null ? null : List.of(lines),
        note: note,
      );

      await (_db.update(
        _db.purchaseOrders,
      )..where((o) => o.id.equals(orderId))).write(orderToRow(updated));

      if (lines != null) {
        // Replaced wholesale rather than diffed. A draft's lines are edited as
        // a set by a form that hands back the whole set, and matching them up
        // to decide which three changed would be work in service of nothing.
        await (_db.delete(
          _db.purchaseOrderLines,
        )..where((l) => l.orderId.equals(orderId))).go();
        await _writeLines(orderId, updated.lines);
      }

      return order(orderId);
    });
  }

  /// Draft → sent. Still moves no stock.
  Future<PurchaseOrder?> send(String orderId) {
    return _db.transaction(() async {
      final existing = await order(orderId);
      if (existing == null ||
          existing.status != PurchaseOrderStatus.draft) {
        return null;
      }

      await (_db.update(
        _db.purchaseOrders,
      )..where((o) => o.id.equals(orderId))).write(
        PurchaseOrdersCompanion(
          status: const Value(PurchaseOrderStatus.sent),
          sentAt: Value(DateTime.now()),
        ),
      );
      return order(orderId);
    });
  }

  /// Deletes a draft outright.
  ///
  /// Only a draft: it was never sent, so nothing outside the app knows it
  /// existed and there is nothing to keep an audit trail of. Sent commandes are
  /// cancelled instead, which leaves the record standing.
  Future<bool> deleteDraft(String orderId) {
    return _db.transaction(() async {
      final existing = await order(orderId);
      if (existing == null ||
          existing.status != PurchaseOrderStatus.draft) {
        return false;
      }

      // The lines go with it through the schema's cascade.
      final removed = await (_db.delete(
        _db.purchaseOrders,
      )..where((o) => o.id.equals(orderId))).go();
      return removed > 0;
    });
  }

  /// Sent → cancelled, only while nothing has been received.
  ///
  /// Once goods are through the door they have created stock movements, and
  /// cancelling would orphan them. Closing the commande short is the correct
  /// exit at that point.
  Future<PurchaseOrder?> cancel(String orderId) {
    return _db.transaction(() async {
      final existing = await order(orderId);
      if (existing == null || !orderCanCancel(existing)) return null;

      await (_db.update(
        _db.purchaseOrders,
      )..where((o) => o.id.equals(orderId))).write(
        PurchaseOrdersCompanion(
          status: const Value(PurchaseOrderStatus.cancelled),
          closedAt: Value(DateTime.now()),
        ),
      );
      return order(orderId);
    });
  }

  /// Closes an open commande, accepting that the outstanding lines are not
  /// coming.
  ///
  /// Marks the remaining lines short rather than trimming them to what arrived.
  /// The gap between ordered and received is the record of the supplier
  /// under-delivering, and rewriting the quantities would erase precisely the
  /// figure that makes it worth recording.
  Future<PurchaseOrder?> closeShort(String orderId) {
    return _db.transaction(() async {
      final existing = await order(orderId);
      if (existing == null || !orderIsOpen(existing)) return null;

      for (final line in existing.lines) {
        if (lineIsSettled(line)) continue;
        await (_db.update(
          _db.purchaseOrderLines,
        )..where((l) => l.id.equals(line.id))).write(
          const PurchaseOrderLinesCompanion(closedShort: Value(true)),
        );
      }

      await (_db.update(
        _db.purchaseOrders,
      )..where((o) => o.id.equals(orderId))).write(
        PurchaseOrdersCompanion(
          status: const Value(PurchaseOrderStatus.received),
          closedAt: Value(DateTime.now()),
        ),
      );
      return order(orderId);
    });
  }

  // ---------------------------------------------------------------------------
  // Receiving — the only path that moves stock
  // ---------------------------------------------------------------------------

  /// What would stop this commande being received, or null if nothing would.
  ///
  /// Exposed so the screen can explain before it offers the button, the same
  /// shape as `deleteBlockedBy` elsewhere. `confirmReceipt` checks again inside
  /// its transaction, because between the two calls anything can happen.
  Future<ReceiptBlock?> receiveBlockedBy(String orderId) async {
    final existing = await order(orderId);
    if (existing == null) return ReceiptBlock.noSuchOrder;
    if (!orderCanReceive(existing)) return ReceiptBlock.notReceivable;
    return null;
  }

  /// Records a delivery and applies everything that follows from it.
  ///
  /// In order, and **all of it in one transaction**:
  ///
  /// 1. Writes the [GoodsReceipt] — permanent, never edited or deleted.
  /// 2. Generates one stock-in movement per delivered line, carrying the
  ///    commande and receipt references, and moves the article's quantity.
  /// 3. Accumulates received quantities onto the commande's lines and marks any
  ///    line the receiver closed short.
  /// 4. Moves the commande to `partial` or `received` per `statusAfterReceipt`.
  /// 5. Where the delivery note disagreed with the price on file, writes a
  ///    price-history entry and updates that supplier's current price.
  ///
  /// Step 5 is how price history stays honest without anyone maintaining it:
  /// prices update as deliveries arrive rather than when somebody remembers to
  /// sit down and edit them.
  ///
  /// **If any step throws, none of it happened.** Phase 1 could not half-fail
  /// because five list edits in a row cannot be interrupted; five statements
  /// against a database can, and a delivery that moved the stock but left the
  /// commande open — or updated the prices but recorded no receipt — is not a
  /// state this app has a name for. A test drives a receipt whose third line
  /// names an article that does not exist and asserts that stock, status and
  /// price history are all exactly where they were.
  ///
  /// Returns null when the commande is gone or cannot be received;
  /// [receiveBlockedBy] says which. Phase 1 wrote `orderById(orderId)!` here,
  /// which was safe only because the data was compiled in.
  Future<GoodsReceipt?> confirmReceipt({
    required String orderId,
    required List<ReceiptDraftLine> lines,
    String? receivedByName,
    String? note,
  }) async {
    final receivedBy =
        receivedByName ?? await AccountRepository(_db).currentUserName();

    return _db.transaction(() async {
      final existing = await order(orderId);
      if (existing == null || !orderCanReceive(existing)) return null;

      final now = DateTime.now();
      final receiptId = newId();

      final receiptLines = [
        for (final line in lines)
          GoodsReceiptLine(
            id: newId(),
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
        storeId: existing.storeId,
        receivedAt: now,
        receivedByName: receivedBy,
        lines: receiptLines,
        note: note,
      );

      await _db.into(_db.goodsReceipts).insert(receiptToRow(receipt));
      for (final (index, line) in receiptLines.indexed) {
        await _db
            .into(_db.goodsReceiptLines)
            .insert(receiptLineToRow(line, receiptId: receiptId, position: index));
      }

      for (final line in receiptLines) {
        if (line.quantityReceived <= 0) continue;

        // Delegated, never inlined. `MovementRepository` is the only thing in
        // the app that changes an article's quantity, and this used to be a
        // quiet second implementation of exactly that. It stayed harmless only
        // while "apply a movement" meant one line of arithmetic; it stopped
        // being harmless the moment a movement also had to remix the average
        // cost, because the second copy is always the one that gets forgotten.
        await MovementRepository(_db).recordStockIn(
          storeId: existing.storeId,
          itemId: line.itemId,
          quantity: line.quantityReceived,
          supplierId: existing.supplierId,
          unitPrice: line.actualUnitPrice,
          occurredAt: now,
          userName: receivedBy,
          orderId: existing.id,
          receiptId: receiptId,
          note: line.note,
        );

        await _applyPriceChange(
          supplierId: existing.supplierId,
          line: line,
          changedAt: now,
          changedByName: receivedBy,
        );
      }

      await _applyReceiptToOrder(existing, lines, closedAt: now);
      return receipt;
    });
  }

  /// Writes the price change, if there was one.
  ///
  /// Compares against the price **on file** rather than against the ordered
  /// price. The two are normally the same — the commande auto-fills from the
  /// file — but where they have drifted, the file is what the comparison report
  /// reads and therefore what has to end up correct.
  ///
  /// Both branches go through `SupplierRepository`, so the rules about defaults
  /// and about what counts as a change live in one place. One consequence is
  /// deliberate and is a change from Phase 1: a delivery line priced at zero no
  /// longer rewrites the supplier's price on file. The movement still records
  /// what was paid, and the cost arithmetic still applies it — but a free
  /// replacement for a bad delivery is not a quotation, and letting it become
  /// one would auto-fill the next commande at nothing.
  Future<void> _applyPriceChange({
    required String supplierId,
    required GoodsReceiptLine line,
    required DateTime changedAt,
    required String changedByName,
  }) async {
    final suppliers = SupplierRepository(_db);
    final current = await suppliers.priceFor(line.itemId, supplierId);

    if (current == null) {
      // An article delivered by a supplier we have no price on file for —
      // normally an unordered line. Record the link rather than dropping the
      // price on the floor.
      await suppliers.linkItem(
        itemId: line.itemId,
        supplierId: supplierId,
        pricePerUnit: line.actualUnitPrice,
        effectiveDate: changedAt,
      );
      return;
    }

    await suppliers.updatePrice(
      current.id,
      line.actualUnitPrice,
      changedByName: changedByName,
      changedAt: changedAt,
    );
  }

  /// Folds a receipt back onto its commande's lines and status.
  Future<void> _applyReceiptToOrder(
    PurchaseOrder existing,
    List<ReceiptDraftLine> received, {
    required DateTime closedAt,
  }) async {
    final lines = [
      for (final line in existing.lines) _accumulate(line, received),
    ];

    for (final line in lines) {
      await (_db.update(
        _db.purchaseOrderLines,
      )..where((l) => l.id.equals(line.id))).write(
        PurchaseOrderLinesCompanion(
          quantityReceived: Value(line.quantityReceived),
          closedShort: Value(line.closedShort),
        ),
      );
    }

    final status = statusAfterReceipt(lines);
    await (_db.update(
      _db.purchaseOrders,
    )..where((o) => o.id.equals(existing.id))).write(
      PurchaseOrdersCompanion(
        status: Value(status),
        closedAt: Value(
          status == PurchaseOrderStatus.received ? closedAt : null,
        ),
      ),
    );
  }

  /// An unordered line is left off the commande on purpose: the commande is
  /// what was agreed, and the receipt is what arrived.
  PurchaseOrderLine _accumulate(
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

  Future<void> _writeLines(String orderId, List<PurchaseOrderLine> lines) async {
    for (final (index, line) in lines.indexed) {
      await _db
          .into(_db.purchaseOrderLines)
          .insert(orderLineToRow(line, orderId: orderId, position: index));
    }
  }

  /// The next human-readable commande number.
  ///
  /// Continues the seeded series rather than restarting, so a demo does not
  /// create `CMD-2026-001` next to `CMD-2026-018`.
  ///
  /// Account-global, not per establishment. Phase 1's version took a `storeId`
  /// and ignored it; that is preserved rather than corrected, because numbering
  /// per store would renumber the demo and the reference is a document number
  /// rather than a key.
  ///
  /// The scan is in Dart rather than SQL because the rule is "the largest
  /// trailing number", which `MAX(CAST(substr(...)))` only answers while every
  /// reference has the same number of digits.
  Future<String> _nextReference() async {
    final rows = await _db.select(_db.purchaseOrders).get();

    var highest = 0;
    for (final row in rows) {
      final digits = RegExp(r'(\d+)$').firstMatch(row.reference)?.group(1);
      final value = digits == null ? 0 : int.tryParse(digits) ?? 0;
      if (value > highest) highest = value;
    }

    final year = DateTime.now().year;
    return 'CMD-$year-${(highest + 1).toString().padLeft(3, '0')}';
  }
  // ---------------------------------------------------------------------------

  Expression<bool> _openIn(String storeId) =>
      _db.purchaseOrders.storeId.equals(storeId) &
      _db.purchaseOrders.status.isInValues(const [
        PurchaseOrderStatus.sent,
        PurchaseOrderStatus.partial,
      ]);

  JoinedSelectStatement<HasResultSet, dynamic> _orders(
    Expression<bool> predicate,
  ) => _db.select(_db.purchaseOrders).join([
    leftOuterJoin(
      _db.purchaseOrderLines,
      _db.purchaseOrderLines.orderId.equalsExp(_db.purchaseOrders.id),
    ),
  ])..where(predicate)..orderBy([
    OrderingTerm(
      expression: _db.purchaseOrders.createdAt,
      mode: OrderingMode.desc,
    ),
    OrderingTerm(expression: _db.purchaseOrders.id, mode: OrderingMode.desc),
    OrderingTerm(expression: _db.purchaseOrderLines.position),
  ]);

  JoinedSelectStatement<HasResultSet, dynamic> _receipts(
    Expression<bool> predicate,
  ) => _db.select(_db.goodsReceipts).join([
    leftOuterJoin(
      _db.goodsReceiptLines,
      _db.goodsReceiptLines.receiptId.equalsExp(_db.goodsReceipts.id),
    ),
  ])..where(predicate)..orderBy([
    OrderingTerm(expression: _db.goodsReceipts.receivedAt),
    OrderingTerm(expression: _db.goodsReceipts.id),
    OrderingTerm(expression: _db.goodsReceiptLines.position),
  ]);

  /// Folds one row per line back into one commande per order, keeping the order
  /// the query returned and the position order of the lines within it.
  List<PurchaseOrder> _assemble(List<TypedResult> rows) {
    final order = <String>[];
    final heads = <String, PurchaseOrderRow>{};
    final lines = <String, List<PurchaseOrderLineRow>>{};

    for (final row in rows) {
      final head = row.readTable(_db.purchaseOrders);
      if (!heads.containsKey(head.id)) {
        heads[head.id] = head;
        order.add(head.id);
        lines[head.id] = <PurchaseOrderLineRow>[];
      }
      final line = row.readTableOrNull(_db.purchaseOrderLines);
      if (line != null) lines[head.id]!.add(line);
    }

    return order.map((id) => orderFromRows(heads[id]!, lines[id]!)).toList();
  }

  List<GoodsReceipt> _assembleReceipts(List<TypedResult> rows) {
    final order = <String>[];
    final heads = <String, GoodsReceiptRow>{};
    final lines = <String, List<GoodsReceiptLineRow>>{};

    for (final row in rows) {
      final head = row.readTable(_db.goodsReceipts);
      if (!heads.containsKey(head.id)) {
        heads[head.id] = head;
        order.add(head.id);
        lines[head.id] = <GoodsReceiptLineRow>[];
      }
      final line = row.readTableOrNull(_db.goodsReceiptLines);
      if (line != null) lines[head.id]!.add(line);
    }

    return order.map((id) => receiptFromRows(heads[id]!, lines[id]!)).toList();
  }

  List<PurchaseOrder> _outstandingFor(
    List<PurchaseOrder> orders,
    String itemId,
  ) => orders
      .where(
        (order) => order.lines.any(
          (line) => line.itemId == itemId && lineOutstanding(line) > 0,
        ),
      )
      .toList();

  /// `lineOutstanding`, in SQL. The only place that rule is written twice.
  Selectable<QueryRow> _onOrderQuery(String storeId, String itemId) =>
      _db.customSelect(
        'SELECT COALESCE(SUM('
        '  CASE WHEN l.closed_short THEN 0 '
        '  ELSE MAX(0, l.quantity_ordered - l.quantity_received) END'
        '), 0) AS outstanding '
        'FROM purchase_order_lines l '
        'JOIN purchase_orders o ON o.id = l.order_id '
        'WHERE o.store_id = ? AND l.item_id = ? '
        "AND o.status IN ('sent', 'partial')",
        variables: [Variable<String>(storeId), Variable<String>(itemId)],
        readsFrom: {_db.purchaseOrders, _db.purchaseOrderLines},
      );

  double _readOutstanding(QueryRow row) => row.read<double>('outstanding');
}
