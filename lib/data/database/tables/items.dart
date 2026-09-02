import 'package:drift/drift.dart';

import 'catalog.dart';
import 'stores.dart';

/// A stocked product.
///
/// There is no price column, and that is the same deliberate absence the model
/// documents: one product can be supplied by several suppliers at their own
/// prices, so a price belongs to the item–supplier pair. See [SupplierPrices].
///
/// [averageCost] is not a counter-example. A price is what the *next* unit will
/// cost; a cost is what the units already on the shelf were paid for.
@DataClassName('ItemRow')
@TableIndex(name: 'items_store', columns: {#storeId})
@TableIndex(name: 'items_store_barcode', columns: {#storeId, #barcode})
@TableIndex(name: 'items_category', columns: {#categoryId})
@TableIndex(name: 'items_unit', columns: {#unitId})
class Items extends Table {
  TextColumn get id => text().withLength(min: 1, max: 64)();
  TextColumn get storeId =>
      text().references(Stores, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();

  /// `RESTRICT`, so "a category in use cannot be deleted" is a fact about the
  /// database rather than a check somebody could forget to call. The repository
  /// keeps its own check as well — that one produces the count the dialog shows
  /// ("3 articles utilisent cette catégorie"), and this one is the backstop for
  /// every path that does not go through it.
  TextColumn get categoryId =>
      text().references(Categories, #id, onDelete: KeyAction.restrict)();
  TextColumn get unitId =>
      text().references(Units, #id, onDelete: KeyAction.restrict)();

  /// Current quantity on hand.
  ///
  /// Written by exactly one file, `repositories/movement_repository.dart`, and
  /// always in the same transaction as the movement that explains the change.
  /// The invariant is `quantity == opening balance + sum of movements`, and
  /// `tool/ux_audit.py` guards the monopoly mechanically.
  RealColumn get quantity => real()();

  RealColumn get lowStockThreshold => real()();

  /// How much of this product the establishment wants on the shelf when it is
  /// fully stocked. What a commande tops up *to*.
  ///
  /// Zero means no ceiling has been declared, and the ordering screen falls
  /// back to its threshold-based figure. Not nullable for that: a maximum of
  /// zero says "order none of this, ever", which is not a thing anybody means,
  /// so the sentinel cannot collide with a real value. Defaulted rather than
  /// backfilled, so a database upgraded in place reads what a fresh one would.
  RealColumn get maxStock => real().withDefault(const Constant(0))();

  DateTimeColumn get updatedAt => dateTime()();

  /// Weighted average cost (CUMP) of the stock on hand, in EUR.
  ///
  /// Nullable because null means **unknown**, not zero: an item with no cost and
  /// no supplier on file contributes nothing to the valuation. Understating
  /// beats inventing.
  RealColumn get averageCost => real().nullable()();

  /// The supplier pre-selected when receiving a delivery.
  ///
  /// **No foreign key, on purpose.** Deleting a supplier keeps the stock
  /// movements that name them and their closed orders, and does not walk the
  /// catalogue clearing this field — so it is allowed to point at a supplier who
  /// is gone, exactly as it was in Phase 1. The screen that reads it treats a
  /// miss as "no preference". An FK would either forbid the delete or silently
  /// rewrite history to make the constraint true.
  TextColumn get defaultSupplierId => text().nullable()();

  /// Unique across a store, enforced when the item form saves. Empty input is
  /// stored as null rather than '', so "no barcode" is one value and not two.
  TextColumn get barcode => text().nullable()();

  TextColumn get note => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
