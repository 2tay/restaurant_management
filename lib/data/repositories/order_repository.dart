import 'package:drift/drift.dart';

import '../../core/utils/order_status.dart';
import '../../models/goods_receipt.dart';
import '../../models/purchase_order.dart';
import '../database/app_database.dart';
import '../mappers/mappers.dart';
import 'store_repository.dart';

/// Commandes and the deliveries against them.
///
/// Reads for now; stage 6 adds the writes, `confirmReceipt` chief among them.
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
