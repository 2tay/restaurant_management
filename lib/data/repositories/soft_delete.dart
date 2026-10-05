import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Deleting a row, the sync-safe way.
///
/// Nothing on a synced table is removed any more: a delete stamps `deletedAt`,
/// and every read skips stamped rows. A row that is really gone cannot tell
/// another device it was deleted (SYNC_PLAN.md, Phase 1, step 5).
///
/// The schema's `ON DELETE CASCADE` never fires for a stamp, so the cascades an
/// app delete relied on are written out here, one method per thing the app
/// deletes. Each one mirrors the foreign keys in `database/tables/`: if a
/// cascade is added there, it has to be added here too.
///
/// Every method only stamps rows that are still live, so deleting twice keeps
/// the first deletion time, and each returns how many rows it stamped.
class SoftDelete {
  const SoftDelete(this._db);

  final AppDatabase _db;

  /// An article, with its movements, its supplier links and their price
  /// history — what `items.id` cascaded to. Lines of commandes and receipts
  /// keep naming it, as they did before: those columns have no foreign key.
  Future<int> item(String id) async {
    final at = clock.now();
    final removed = await _stamp(_db.items, _db.items.id.equals(id), at);
    if (removed == 0) return 0;

    await _stamp(_db.stockMovements, _db.stockMovements.itemId.equals(id), at);
    await _stamp(_db.supplierPrices, _db.supplierPrices.itemId.equals(id), at);
    await _stamp(_db.priceHistory, _db.priceHistory.itemId.equals(id), at);
    return removed;
  }

  /// A supplier, with the prices they offered and the history of those
  /// prices. Movements and commandes naming them stay: no foreign key.
  Future<int> supplier(String id) async {
    final at = clock.now();
    final removed = await _stamp(
      _db.suppliers,
      _db.suppliers.id.equals(id),
      at,
    );
    if (removed == 0) return 0;

    await _stamp(
      _db.supplierPrices,
      _db.supplierPrices.supplierId.equals(id),
      at,
    );
    await _stamp(
      _db.priceHistory,
      _db.priceHistory.supplierId.equals(id),
      at,
    );
    return removed;
  }

  /// One item–supplier link. Its price history is kept, as it always was.
  Future<int> supplierPrice(String id) => _stamp(
    _db.supplierPrices,
    _db.supplierPrices.id.equals(id),
    clock.now(),
  );

  /// A commande with its lines, and any receipt against it with the receipt's
  /// lines — the two cascades from `purchase_orders.id`.
  Future<int> order(String id) async {
    final at = clock.now();
    final removed = await _stamp(
      _db.purchaseOrders,
      _db.purchaseOrders.id.equals(id),
      at,
    );
    if (removed == 0) return 0;

    await orderLines(id, at: at);
    final receiptIds = _db.selectOnly(_db.goodsReceipts)
      ..addColumns([_db.goodsReceipts.id])
      ..where(_db.goodsReceipts.orderId.equals(id));
    await _stamp(
      _db.goodsReceiptLines,
      _db.goodsReceiptLines.receiptId.isInQuery(receiptIds),
      at,
    );
    await _stamp(_db.goodsReceipts, _db.goodsReceipts.orderId.equals(id), at);
    return removed;
  }

  /// Every line of a commande, when a draft's lines are replaced as a set.
  Future<int> orderLines(String orderId, {DateTime? at}) => _stamp(
    _db.purchaseOrderLines,
    _db.purchaseOrderLines.orderId.equals(orderId),
    at ?? clock.now(),
  );

  Future<int> category(String id) =>
      _stamp(_db.categories, _db.categories.id.equals(id), clock.now());

  Future<int> unit(String id) =>
      _stamp(_db.units, _db.units.id.equals(id), clock.now());

  /// A one-off busy day.
  Future<int> busyDate(String storeId, String day) => _stamp(
    _db.busyDates,
    _db.busyDates.storeId.equals(storeId) & _db.busyDates.day.equals(day),
    clock.now(),
  );

  Future<int> _stamp<T extends Table, D>(
    TableInfo<T, D> table,
    Expression<bool> where,
    DateTime at,
  ) {
    final deletedAt = table.columnsByName['deleted_at']! as Column<DateTime>;
    return (_db.update(table)..where((_) => where & deletedAt.isNull())).write(
      RawValuesInsertable<D>({'deleted_at': Variable<DateTime>(at)}),
    );
  }
}
