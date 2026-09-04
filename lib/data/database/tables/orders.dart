import 'package:drift/drift.dart';

import '../../../models/purchase_order.dart';
import 'stores.dart';

/// A commande to a supplier.
///
/// Its lifecycle is `draft → sent → partial → received`, with `cancelled`
/// reachable from the two middle states. The transitions themselves are decided
/// by the pure predicates in `core/utils/order_status.dart`, which Phase 2
/// reuses unchanged — the status column is where their answer is written down,
/// never where it is worked out.
@DataClassName('PurchaseOrderRow')
@TableIndex(name: 'purchase_orders_store_status', columns: {#storeId, #status})
@TableIndex(name: 'purchase_orders_supplier', columns: {#supplierId})
class PurchaseOrders extends Table {
  TextColumn get id => text().withLength(min: 1, max: 64)();
  TextColumn get storeId =>
      text().references(Stores, #id, onDelete: KeyAction.cascade)();

  /// **No foreign key, on purpose.** A supplier can be deleted once they have
  /// no open order, and their closed orders are kept — the order history is how
  /// an owner sees who they used to buy from. Cascading would delete that
  /// history; restricting would forbid ever removing a supplier once used.
  TextColumn get supplierId => text()();

  /// `CMD-2026-017`. Account-global rather than per store, which is what Phase 1
  /// did — the `storeId` argument to the old `_nextReference` was accepted and
  /// ignored. Preserved deliberately: renumbering would rewrite the demo.
  TextColumn get reference => text()();

  TextColumn get status => textEnum<PurchaseOrderStatus>()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get sentAt => dateTime().nullable()();
  DateTimeColumn get closedAt => dateTime().nullable()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One article on a commande.
///
/// `PurchaseOrder.lines` is an embedded list on the model and a child table
/// here; `mappers/order_mapper.dart` is the single place that shape changes.
@DataClassName('PurchaseOrderLineRow')
@TableIndex(name: 'purchase_order_lines_order', columns: {#orderId})
@TableIndex(name: 'purchase_order_lines_item', columns: {#itemId})
class PurchaseOrderLines extends Table {
  TextColumn get id => text().withLength(min: 1, max: 64)();
  TextColumn get orderId =>
      text().references(PurchaseOrders, #id, onDelete: KeyAction.cascade)();

  /// **No foreign key, on purpose.** An article can be deleted while closed
  /// orders still list it — deletion is only blocked by an *open* order. An FK
  /// would either forbid deleting anything ever ordered, or delete lines out of
  /// a completed commande, and a commande that quietly loses a line is worse
  /// than one naming an article that is gone.
  TextColumn get itemId => text()();

  RealColumn get quantityOrdered => real()();

  /// Accumulated across receipts. A commande can be delivered in several goes,
  /// and this is the running total, not the last delivery.
  RealColumn get quantityReceived => real().withDefault(const Constant(0))();

  /// The price agreed when the commande was sent. What actually arrives is on
  /// the receipt line; the two differing is the point of the réserves section.
  RealColumn get unitPrice => real()();

  /// The receiver said the rest is not coming. Settles the line short rather
  /// than leaving the commande open forever with an inflated on-order quantity.
  BoolColumn get closedShort => boolean().withDefault(const Constant(false))();

  /// Where this line sits in the commande, from zero.
  ///
  /// `PurchaseOrder.lines` is an ordered list on the model, and a child table
  /// has no order of its own. Sorting by `id` would work for the demo, whose
  /// line ids happen to end in an ordinal, and would shuffle a real commande
  /// into UUID order the moment it was saved — the person who typed the lines
  /// would watch them rearrange. Sorting by `rowid` would work until the day
  /// somebody runs `VACUUM`. So the position is a column.
  IntColumn get position => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
