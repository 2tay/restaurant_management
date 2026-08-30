import 'package:drift/drift.dart';

import '../../models/item.dart';
import '../database/app_database.dart';

Item itemFromRow(ItemRow row) => Item(
  id: row.id,
  storeId: row.storeId,
  name: row.name,
  categoryId: row.categoryId,
  unitId: row.unitId,
  quantity: row.quantity,
  lowStockThreshold: row.lowStockThreshold,
  updatedAt: row.updatedAt,
  averageCost: row.averageCost,
  defaultSupplierId: row.defaultSupplierId,
  barcode: row.barcode,
  note: row.note,
);

/// Writes every column, [Item.quantity] and [Item.averageCost] included.
///
/// That is safe here and only here: this function is called with a whole item
/// in hand, by the seed and by the movement repository, both of which have
/// already worked out what those two numbers should be. Nothing else builds an
/// item companion — the item repository's `update` has no quantity parameter,
/// exactly as `ItemMutations.update` had none.
ItemsCompanion itemToRow(Item item) => ItemsCompanion.insert(
  id: item.id,
  storeId: item.storeId,
  name: item.name,
  categoryId: item.categoryId,
  unitId: item.unitId,
  quantity: item.quantity,
  lowStockThreshold: item.lowStockThreshold,
  updatedAt: item.updatedAt,
  averageCost: Value(item.averageCost),
  defaultSupplierId: Value(item.defaultSupplierId),
  barcode: Value(item.barcode),
  note: Value(item.note),
);
