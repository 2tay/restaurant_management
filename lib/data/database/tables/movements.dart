import 'package:drift/drift.dart';

import '../../../models/stock_movement.dart';
import 'items.dart';
import 'stores.dart';

/// The log of everything that changed a quantity.
///
/// Nothing else in the app is allowed to move stock, and the item's quantity is
/// a running total of this table rather than an independent fact. It is stored
/// on the item rather than derived because deriving it would mean replaying the
/// whole log on every read, but it stays *rebuildable* from here — which is the
/// point of keeping [unitCost] and [averageCostAfter] on the row.
///
/// The two enum columns are stored as their **name string**, via drift's
/// `textEnum`, not as an index. An index shifts the day somebody reorders the
/// enum, and by then the database has a year of movements in it.
@DataClassName('StockMovementRow')
@TableIndex(
  name: 'stock_movements_item_time',
  columns: {#itemId, IndexedColumn(#occurredAt, orderBy: OrderingMode.desc)},
)
@TableIndex(
  name: 'stock_movements_store_time',
  columns: {#storeId, IndexedColumn(#occurredAt, orderBy: OrderingMode.desc)},
)
@TableIndex(name: 'stock_movements_receipt', columns: {#receiptId})
class StockMovements extends Table {
  TextColumn get id => text().withLength(min: 1, max: 64)();
  TextColumn get storeId =>
      text().references(Stores, #id, onDelete: KeyAction.cascade)();

  /// Cascades. Deleting an article is an explicit, confirmed act that states
  /// its own counts, and leaving movements pointing at an article that no longer
  /// exists would render them as "—" with no way to work out what they said.
  TextColumn get itemId =>
      text().references(Items, #id, onDelete: KeyAction.cascade)();

  TextColumn get type => textEnum<StockMovementType>()();

  /// Signed: positive in, negative out, and for an adjustment the difference
  /// between what was counted and what the system thought.
  RealColumn get quantity => real()();

  DateTimeColumn get occurredAt => dateTime()();

  /// The name, not the id — see `price_history.changedByName`.
  TextColumn get userName => text()();

  /// **No foreign key, on purpose.** Deleting a supplier keeps the movements
  /// that name them: a movement records goods that really moved, and the
  /// supplier going away does not unmake that. The row keeps their id and the
  /// screen renders "Fournisseur supprimé", which is true. `ON DELETE SET NULL`
  /// would erase the id and quietly make the past tidier than it was.
  TextColumn get supplierId => text().nullable()();

  /// What was paid per unit on this delivery, when it is known.
  RealColumn get unitPrice => real().nullable()();

  /// Only meaningful on a stock-out.
  TextColumn get reason => textEnum<StockOutReason>().nullable()();

  /// Only meaningful on an adjustment: what the system said, and what the count
  /// actually found.
  RealColumn get systemQuantity => real().nullable()();
  RealColumn get countedQuantity => real().nullable()();

  /// The cost this movement applied, and the weighted average it produced.
  ///
  /// Stamped at the time and never recomputed. Together they are what makes the
  /// average auditable — every step of it can be read back off the log.
  RealColumn get unitCost => real().nullable()();
  RealColumn get averageCostAfter => real().nullable()();

  /// Back-references to the delivery that caused this movement. No foreign
  /// keys: like [supplierId] these are historical pointers, and a movement that
  /// outlives what it points at is still a true record of goods that moved.
  TextColumn get orderId => text().nullable()();
  TextColumn get receiptId => text().nullable()();

  TextColumn get note => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
