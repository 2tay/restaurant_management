import 'package:drift/drift.dart';

import 'orders.dart';
import 'stores.dart';

/// A delivery, as received.
///
/// **Append-only.** A receipt is never updated and never deleted: it is the
/// record of what physically arrived, and correcting it is a new movement, not
/// an edit. The bon de réception PDF is a pure projection of this row — same
/// receipt, same bytes, forever — which only holds because nothing rewrites it.
@DataClassName('GoodsReceiptRow')
@TableIndex(name: 'goods_receipts_order', columns: {#orderId})
@TableIndex(name: 'goods_receipts_store', columns: {#storeId})
class GoodsReceipts extends Table {
  TextColumn get id => text().withLength(min: 1, max: 64)();

  /// Cascades, because a receipt has no meaning without its commande — the
  /// derived reference `BR-2026-014/2` is literally the order's reference plus
  /// this receipt's position within it. In practice the cascade never fires: an
  /// order that has been received cannot be deleted.
  TextColumn get orderId =>
      text().references(PurchaseOrders, #id, onDelete: KeyAction.cascade)();

  TextColumn get storeId =>
      text().references(Stores, #id, onDelete: KeyAction.cascade)();

  /// Receipts for one order are read oldest first — the `/2` in the derived
  /// reference is a position in that order, so it has to be stable.
  DateTimeColumn get receivedAt => dateTime()();

  TextColumn get receivedByName => text()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One article on a delivery.
@DataClassName('GoodsReceiptLineRow')
@TableIndex(name: 'goods_receipt_lines_receipt', columns: {#receiptId})
@TableIndex(name: 'goods_receipt_lines_item', columns: {#itemId})
class GoodsReceiptLines extends Table {
  TextColumn get id => text().withLength(min: 1, max: 64)();
  TextColumn get receiptId =>
      text().references(GoodsReceipts, #id, onDelete: KeyAction.cascade)();

  /// No foreign key, for the reason given on `purchase_order_lines.itemId`.
  TextColumn get itemId => text()();

  /// What the commande asked for, copied onto the receipt at the time. Zero for
  /// an unordered line. Copied rather than joined so the document still reads
  /// correctly after the commande's own lines move on.
  RealColumn get quantityOrdered => real()();

  RealColumn get quantityReceived => real()();

  /// What the delivery actually charged, which is the number compared against
  /// the price on file to decide whether the price history gains an entry.
  RealColumn get actualUnitPrice => real()();

  BoolColumn get closedShort => boolean().withDefault(const Constant(false))();

  /// Arrived without being ordered. Kept on the receipt and stocked in, but
  /// deliberately not added to the commande — the commande is what was agreed.
  BoolColumn get wasUnordered => boolean().withDefault(const Constant(false))();

  TextColumn get note => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
