import 'package:drift/drift.dart';

import 'items.dart';
import 'stores.dart';

/// A supplier the establishment buys from.
@DataClassName('SupplierRow')
@TableIndex(name: 'suppliers_store', columns: {#storeId})
class Suppliers extends Table {
  TextColumn get id => text().withLength(min: 1, max: 64)();
  TextColumn get storeId =>
      text().references(Stores, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get contactName => text()();
  TextColumn get email => text()();
  TextColumn get phone => text()();
  TextColumn get addressLine => text()();
  TextColumn get postalCode => text()();
  TextColumn get city => text()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// What one supplier charges for one item — the item–supplier link.
///
/// The unique index on `(itemId, supplierId)` is the "already linked" rule at
/// the schema level. The repository still returns null rather than throwing
/// when a link exists, because that case is an edit and not an error; the index
/// is what makes a second path to the same mistake impossible.
///
/// Both foreign keys cascade. Deleting an item removes the prices offered for
/// it, and deleting a supplier removes the prices they offered — neither leaves
/// a price for something that no longer exists, and that is what Phase 1 did.
@DataClassName('SupplierPriceRow')
@TableIndex(name: 'supplier_prices_item', columns: {#itemId})
@TableIndex(name: 'supplier_prices_supplier', columns: {#supplierId})
@TableIndex(
  name: 'supplier_prices_pair',
  columns: {#itemId, #supplierId},
  unique: true,
)
class SupplierPrices extends Table {
  TextColumn get id => text().withLength(min: 1, max: 64)();
  TextColumn get itemId =>
      text().references(Items, #id, onDelete: KeyAction.cascade)();
  TextColumn get supplierId =>
      text().references(Suppliers, #id, onDelete: KeyAction.cascade)();

  /// What the *next* unit will cost. Never used to value stock on hand — that
  /// is `items.averageCost`, and confusing the two is what made the valuation
  /// report revalue last week's stock at this morning's delivery price.
  RealColumn get pricePerUnit => real()();

  DateTimeColumn get effectiveDate => dateTime()();

  /// Exactly one true per item, maintained by the supplier repository in a
  /// transaction (clear, then set). Not expressible as a constraint in SQLite
  /// without a trigger, and a trigger would be a second place the rule lives.
  BoolColumn get isDefault => boolean()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Every price change, kept.
///
/// Written by the supplier repository on an edit and by the order repository
/// when a delivery arrives at a different price than the one on file. Never
/// updated, never deleted on its own — this is how an owner sees a supplier
/// drifting upward over a season.
@DataClassName('PriceHistoryRow')
@TableIndex(
  name: 'price_history_pair_time',
  columns: {
    #itemId,
    #supplierId,
    IndexedColumn(#changedAt, orderBy: OrderingMode.desc),
  },
)
class PriceHistory extends Table {
  TextColumn get id => text().withLength(min: 1, max: 64)();
  TextColumn get itemId =>
      text().references(Items, #id, onDelete: KeyAction.cascade)();
  TextColumn get supplierId =>
      text().references(Suppliers, #id, onDelete: KeyAction.cascade)();
  RealColumn get oldPrice => real()();
  RealColumn get newPrice => real()();
  DateTimeColumn get changedAt => dateTime()();

  /// The name, not the id. The person may leave the team; what they did to the
  /// price stays legible.
  TextColumn get changedByName => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
