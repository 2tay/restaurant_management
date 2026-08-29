import 'package:drift/drift.dart';

import '../../models/stock_movement.dart';
import '../database/app_database.dart';

StockMovement movementFromRow(StockMovementRow row) => StockMovement(
  id: row.id,
  storeId: row.storeId,
  itemId: row.itemId,
  type: row.type,
  quantity: row.quantity,
  occurredAt: row.occurredAt,
  userName: row.userName,
  supplierId: row.supplierId,
  unitPrice: row.unitPrice,
  reason: row.reason,
  systemQuantity: row.systemQuantity,
  countedQuantity: row.countedQuantity,
  unitCost: row.unitCost,
  averageCostAfter: row.averageCostAfter,
  orderId: row.orderId,
  receiptId: row.receiptId,
  note: row.note,
);

StockMovementsCompanion movementToRow(StockMovement movement) =>
    StockMovementsCompanion.insert(
      id: movement.id,
      storeId: movement.storeId,
      itemId: movement.itemId,
      type: movement.type,
      quantity: movement.quantity,
      occurredAt: movement.occurredAt,
      userName: movement.userName,
      supplierId: Value(movement.supplierId),
      unitPrice: Value(movement.unitPrice),
      reason: Value(movement.reason),
      systemQuantity: Value(movement.systemQuantity),
      countedQuantity: Value(movement.countedQuantity),
      unitCost: Value(movement.unitCost),
      averageCostAfter: Value(movement.averageCostAfter),
      orderId: Value(movement.orderId),
      receiptId: Value(movement.receiptId),
      note: Value(movement.note),
    );
