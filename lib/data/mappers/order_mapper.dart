import 'package:drift/drift.dart';

import '../../models/purchase_order.dart';
import '../../models/purchase_order_line.dart';
import '../database/app_database.dart';

/// Takes its lines separately, because this is where the shape changes.
///
/// `PurchaseOrder.lines` is an embedded list on the model and a child table in
/// the schema. Rebuilding one from the other happens here and nowhere else, so
/// there is a single place to look when an order comes back with no lines.
///
/// The caller decides the line order; it is not re-sorted here. Lines are read
/// back by their `position` column, which is the order the person building the
/// commande added them in and the order the PDF prints them in.
PurchaseOrder orderFromRows(
  PurchaseOrderRow row,
  List<PurchaseOrderLineRow> lineRows,
) => PurchaseOrder(
  id: row.id,
  storeId: row.storeId,
  supplierId: row.supplierId,
  reference: row.reference,
  status: row.status,
  createdAt: row.createdAt,
  lines: lineRows.map(orderLineFromRow).toList(),
  sentAt: row.sentAt,
  closedAt: row.closedAt,
  note: row.note,
);

/// The order row only. Its lines are written separately — see
/// [orderLineToRow].
PurchaseOrdersCompanion orderToRow(PurchaseOrder order) =>
    PurchaseOrdersCompanion.insert(
      id: order.id,
      storeId: order.storeId,
      supplierId: order.supplierId,
      reference: order.reference,
      status: order.status,
      createdAt: order.createdAt,
      sentAt: Value(order.sentAt),
      closedAt: Value(order.closedAt),
      note: Value(order.note),
    );

PurchaseOrderLine orderLineFromRow(PurchaseOrderLineRow row) =>
    PurchaseOrderLine(
      id: row.id,
      itemId: row.itemId,
      quantityOrdered: row.quantityOrdered,
      unitPrice: row.unitPrice,
      quantityReceived: row.quantityReceived,
      closedShort: row.closedShort,
    );

/// The line carries neither its order's id nor its own position on the model —
/// it only ever exists inside one commande, as an element of an ordered list —
/// so the caller supplies both.
PurchaseOrderLinesCompanion orderLineToRow(
  PurchaseOrderLine line, {
  required String orderId,
  required int position,
}) => PurchaseOrderLinesCompanion.insert(
  id: line.id,
  orderId: orderId,
  position: position,
  itemId: line.itemId,
  quantityOrdered: line.quantityOrdered,
  unitPrice: line.unitPrice,
  quantityReceived: Value(line.quantityReceived),
  closedShort: Value(line.closedShort),
);
