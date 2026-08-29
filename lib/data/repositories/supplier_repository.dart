import 'package:drift/drift.dart';

import '../../models/price_history_entry.dart';
import '../../models/supplier.dart';
import '../../models/supplier_price.dart';
import '../database/app_database.dart';
import '../mappers/mappers.dart';

/// Suppliers, the prices they offer, and how those prices have moved.
///
/// A price belongs to the item–supplier *pair*, never to the article: one
/// product can be bought from several suppliers at several prices, and that is
/// the fact the whole schema is arranged around.
class SupplierRepository {
  const SupplierRepository(this._db);

  final AppDatabase _db;

  // ---------------------------------------------------------------------------
  // Suppliers
  // ---------------------------------------------------------------------------

  Stream<List<Supplier>> watchSuppliers(String storeId) =>
      _suppliersQuery(storeId).watch().map(_toSuppliers);

  Future<List<Supplier>> suppliers(String storeId) =>
      _suppliersQuery(storeId).get().then(_toSuppliers);

  Stream<Supplier?> watchSupplier(String id) =>
      (_db.select(_db.suppliers)..where((s) => s.id.equals(id)))
          .watchSingleOrNull()
          .map((row) => row == null ? null : supplierFromRow(row));

  Future<Supplier?> supplier(String id) =>
      (_db.select(_db.suppliers)..where((s) => s.id.equals(id)))
          .getSingleOrNull()
          .then((row) => row == null ? null : supplierFromRow(row));

  // ---------------------------------------------------------------------------
  // Prices — the item–supplier link
  // ---------------------------------------------------------------------------

  /// Every supplier offering this article, **cheapest first**.
  ///
  /// The order is a contract, not a convenience: unlinking a supplier and
  /// deleting one both promote whatever is now cheapest to be the new default,
  /// and both do it by taking the first of these.
  ///
  /// Ties break on `id`. Phase 1 broke them on the order the prices happened to
  /// be written in, which a database does not have and which stops being
  /// meaningful the moment ids are generated rather than authored.
  Stream<List<SupplierPrice>> watchPricesForItem(String itemId) =>
      _pricesForItem(itemId).watch().map(_toPrices);

  Future<List<SupplierPrice>> pricesForItem(String itemId) =>
      _pricesForItem(itemId).get().then(_toPrices);

  /// Every article this supplier provides.
  Future<List<SupplierPrice>> pricesForSupplier(String supplierId) =>
      (_db.select(_db.supplierPrices)
            ..where((p) => p.supplierId.equals(supplierId))
            ..orderBy([(p) => OrderingTerm(expression: p.id)]))
          .get()
          .then(_toPrices);

  /// How many articles this supplier is linked to. The number the supplier
  /// screen and the delete confirmation show.
  Future<int> itemCountForSupplier(String supplierId) async {
    final count = _db.supplierPrices.id.count();
    final query = _db.selectOnly(_db.supplierPrices)
      ..addColumns([count])
      ..where(_db.supplierPrices.supplierId.equals(supplierId));
    return (await query.getSingle()).read(count) ?? 0;
  }

  Future<SupplierPrice?> defaultPriceForItem(String itemId) =>
      (_db.select(_db.supplierPrices)
            ..where((p) => p.itemId.equals(itemId) & p.isDefault.equals(true)))
          .getSingleOrNull()
          .then(_toPriceOrNull);

  Future<SupplierPrice?> cheapestPriceForItem(String itemId) =>
      (_pricesForItem(itemId)..limit(1)).getSingleOrNull().then(_toPriceOrNull);

  Future<SupplierPrice?> priceFor(String itemId, String supplierId) =>
      (_db.select(_db.supplierPrices)..where(
            (p) => p.itemId.equals(itemId) & p.supplierId.equals(supplierId),
          ))
          .getSingleOrNull()
          .then(_toPriceOrNull);

  /// How much more the default supplier costs than the cheapest one, per unit.
  /// Zero when the establishment is already on the best price.
  ///
  /// The number the price comparison report is built around.
  Future<double> overpayPerUnit(String itemId) async {
    // One row, or none when the article has no default supplier — which is the
    // "nothing to compare" case and reads as no overpayment rather than as an
    // error.
    final row = await _db
        .customSelect(
          'SELECT d.price_per_unit - ('
          '  SELECT MIN(p.price_per_unit) FROM supplier_prices p '
          '  WHERE p.item_id = d.item_id'
          ') AS gap '
          'FROM supplier_prices d '
          'WHERE d.item_id = ? AND d.is_default = 1',
          variables: [Variable<String>(itemId)],
          readsFrom: {_db.supplierPrices},
        )
        .getSingleOrNull();

    final gap = row?.read<double?>('gap');
    return (gap == null || gap < 0) ? 0 : gap;
  }

  /// Price changes for one item–supplier pair, newest first.
  Stream<List<PriceHistoryEntry>> watchPriceHistory(
    String itemId,
    String supplierId,
  ) => _history(itemId, supplierId).watch().map(_toHistory);

  Future<List<PriceHistoryEntry>> priceHistoryFor(
    String itemId,
    String supplierId,
  ) => _history(itemId, supplierId).get().then(_toHistory);

  // ---------------------------------------------------------------------------

  SimpleSelectStatement<$SuppliersTable, SupplierRow> _suppliersQuery(
    String storeId,
  ) =>
      _db.select(_db.suppliers)
        ..where((s) => s.storeId.equals(storeId))
        ..orderBy([(s) => OrderingTerm(expression: s.name)]);

  SimpleSelectStatement<$SupplierPricesTable, SupplierPriceRow> _pricesForItem(
    String itemId,
  ) =>
      _db.select(_db.supplierPrices)
        ..where((p) => p.itemId.equals(itemId))
        ..orderBy([
          (p) => OrderingTerm(expression: p.pricePerUnit),
          (p) => OrderingTerm(expression: p.id),
        ]);

  SimpleSelectStatement<$PriceHistoryTable, PriceHistoryRow> _history(
    String itemId,
    String supplierId,
  ) =>
      _db.select(_db.priceHistory)
        ..where((h) => h.itemId.equals(itemId) & h.supplierId.equals(supplierId))
        ..orderBy([
          (h) => OrderingTerm(expression: h.changedAt, mode: OrderingMode.desc),
          (h) => OrderingTerm(expression: h.id, mode: OrderingMode.desc),
        ]);

  List<Supplier> _toSuppliers(List<SupplierRow> rows) =>
      rows.map(supplierFromRow).toList();

  List<SupplierPrice> _toPrices(List<SupplierPriceRow> rows) =>
      rows.map(supplierPriceFromRow).toList();

  SupplierPrice? _toPriceOrNull(SupplierPriceRow? row) =>
      row == null ? null : supplierPriceFromRow(row);

  List<PriceHistoryEntry> _toHistory(List<PriceHistoryRow> rows) =>
      rows.map(priceHistoryFromRow).toList();
}
