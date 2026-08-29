import 'package:drift/drift.dart';

import '../../models/goods_receipt.dart';
import '../../models/goods_receipt_line.dart';
import '../database/app_database.dart';

/// Same split as `order_mapper.dart`: the receipt's lines are a child table.
///
/// Line order is the caller's, and it matters more here than for an order — the
/// bon de réception PDF is a pure projection of this object, so two reads of the
/// same receipt have to produce the same document.
GoodsReceipt receiptFromRows(
  GoodsReceiptRow row,
  List<GoodsReceiptLineRow> lineRows,
) => GoodsReceipt(
  id: row.id,
  orderId: row.orderId,
  storeId: row.storeId,
  receivedAt: row.receivedAt,
  receivedByName: row.receivedByName,
  lines: lineRows.map(receiptLineFromRow).toList(),
  note: row.note,
);

GoodsReceiptsCompanion receiptToRow(GoodsReceipt receipt) =>
    GoodsReceiptsCompanion.insert(
      id: receipt.id,
      orderId: receipt.orderId,
      storeId: receipt.storeId,
      receivedAt: receipt.receivedAt,
      receivedByName: receipt.receivedByName,
      note: Value(receipt.note),
    );

GoodsReceiptLine receiptLineFromRow(GoodsReceiptLineRow row) => GoodsReceiptLine(
  id: row.id,
  itemId: row.itemId,
  quantityOrdered: row.quantityOrdered,
  quantityReceived: row.quantityReceived,
  actualUnitPrice: row.actualUnitPrice,
  closedShort: row.closedShort,
  wasUnordered: row.wasUnordered,
  note: row.note,
);

GoodsReceiptLinesCompanion receiptLineToRow(
  GoodsReceiptLine line, {
  required String receiptId,
}) => GoodsReceiptLinesCompanion.insert(
  id: line.id,
  receiptId: receiptId,
  itemId: line.itemId,
  quantityOrdered: line.quantityOrdered,
  quantityReceived: line.quantityReceived,
  actualUnitPrice: line.actualUnitPrice,
  closedShort: Value(line.closedShort),
  wasUnordered: Value(line.wasUnordered),
  note: Value(line.note),
);
