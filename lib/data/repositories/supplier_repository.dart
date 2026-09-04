import 'package:drift/drift.dart';

import '../../core/utils/order_status.dart';
import '../../core/utils/stock_cost.dart';
import '../../models/price_history_entry.dart';
import '../../models/supplier.dart';
import '../../models/supplier_price.dart';
import '../database/app_database.dart';
import '../mappers/mappers.dart';
import '../view_models/item_detail_views.dart';
import '../view_models/supplier_views.dart';
import 'account_repository.dart';
import 'new_id.dart';
import 'order_repository.dart';

/// What is standing between a supplier and deletion.
enum SupplierDeleteBlock {
  /// They have a commande that has been sent and is not finished.
  ///
  /// Deleting them would orphan an outstanding document — and, if anything on it
  /// has already arrived, the stock movements that document produced.
  hasOpenOrder,
}

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

  /// Every supplier of the establishment with the number of articles it
  /// supplies — what the suppliers list draws.
  ///
  /// `LEFT OUTER JOIN` so a supplier with no articles yet still appears: one
  /// that has just been created is exactly the one somebody is looking for.
  Stream<List<SupplierRowView>> watchSupplierRows(String storeId) {
    final count = _db.supplierPrices.id.count();
    final query = _db.select(_db.suppliers).join([
      leftOuterJoin(
        _db.supplierPrices,
        _db.supplierPrices.supplierId.equalsExp(_db.suppliers.id),
      ),
    ]);
    query
      ..where(_db.suppliers.storeId.equals(storeId))
      ..addColumns([count])
      ..groupBy([_db.suppliers.id])
      ..orderBy([OrderingTerm(expression: _db.suppliers.name)]);

    return query.watch().map(
      (rows) => [
        for (final row in rows)
          SupplierRowView(
            supplier: supplierFromRow(row.readTable(_db.suppliers)),
            productCount: row.read(count) ?? 0,
          ),
      ],
    );
  }

  /// Everything one supplier offers, named, with the best price on the market
  /// for each article alongside.
  ///
  /// The second number is what lets a row say "le moins cher" without asking a
  /// question of its own. It is a correlated subquery — one `MIN` per row,
  /// answered by the same index that orders the article's offers — rather than
  /// the per-row call the supplier screens made in Phase 1.
  Stream<List<SupplierProductView>> watchSupplierProducts(String supplierId) {
    final cheapest = subqueryExpression<double>(
      _db.selectOnly(_db.supplierPrices, distinct: true)
        ..addColumns([_db.supplierPrices.pricePerUnit.min()])
        ..where(
          _db.supplierPrices.itemId.equalsExp(_db.items.id),
        ),
    );

    final query =
        _db.select(_db.supplierPrices).join([
            leftOuterJoin(
              _db.items,
              _db.items.id.equalsExp(_db.supplierPrices.itemId),
            ),
            leftOuterJoin(_db.units, _db.units.id.equalsExp(_db.items.unitId)),
            leftOuterJoin(
              _db.categories,
              _db.categories.id.equalsExp(_db.items.categoryId),
            ),
          ])
          ..where(_db.supplierPrices.supplierId.equals(supplierId))
          ..addColumns([cheapest])
          // By article name: this is a catalogue, and somebody scanning it is
          // looking for a product rather than for a price.
          ..orderBy([OrderingTerm(expression: _db.items.name)]);

    return query.watch().map(
      (rows) => [
        for (final row in rows)
          SupplierProductView(
            price: supplierPriceFromRow(row.readTable(_db.supplierPrices)),
            itemName: row.readTableOrNull(_db.items)?.name ?? '—',
            unitAbbreviation:
                row.readTableOrNull(_db.units)?.abbreviation ?? '',
            categoryName: row.readTableOrNull(_db.categories)?.name ?? '—',
            cheapestPricePerUnit:
                row.read(cheapest) ??
                row.readTable(_db.supplierPrices).pricePerUnit,
          ),
      ],
    );
  }

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

  /// Every supplier of one article, named, plus what the default costs extra.
  ///
  /// What the item detail screen draws: a table of offers and, above it, the
  /// single most useful sentence this app produces — "vous payez 0,45 € de plus
  /// par kg que chez Boucherie Vanderlinden".
  ///
  /// One query and one derivation rather than four calls. The overpayment is
  /// computed from the same rows the table shows, so the callout cannot name a
  /// supplier the table does not list.
  Stream<ItemPricing> watchPricing(String itemId) {
    final query = _pricesForItem(itemId).join([
      leftOuterJoin(
        _db.suppliers,
        _db.suppliers.id.equalsExp(_db.supplierPrices.supplierId),
      ),
    ]);

    return query.watch().map((rows) {
      final prices = [
        for (final row in rows)
          SupplierPriceView(
            price: supplierPriceFromRow(row.readTable(_db.supplierPrices)),
            supplierName: row.readTableOrNull(_db.suppliers)?.name ?? '—',
          ),
      ];
      return ItemPricing(prices: prices, overpayPerUnit: _overpayIn(prices));
    });
  }

  /// The same rule as [overpayPerUnit], over rows already in hand.
  ///
  /// Written twice on purpose: the SQL version answers it for one article
  /// without loading the others, which is what the comparison report needs
  /// across a whole establishment; this one answers it for free from a list the
  /// screen already has. A test holds them to the same number.
  static double _overpayIn(List<SupplierPriceView> prices) {
    if (prices.isEmpty) return 0;

    double? defaultPrice;
    for (final entry in prices) {
      if (entry.price.isDefault) defaultPrice = entry.price.pricePerUnit;
    }
    if (defaultPrice == null) return 0;

    // Cheapest first, so the first row is the floor.
    final gap = defaultPrice - prices.first.price.pricePerUnit;
    return gap < 0 ? 0 : gap;
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
  // Writes — suppliers
  // ---------------------------------------------------------------------------

  Future<Supplier> create({
    required String storeId,
    required String name,
    required String contactName,
    required String email,
    required String phone,
    required String addressLine,
    required String postalCode,
    required String city,
    String? note,
  }) async {
    final supplier = Supplier(
      id: newId(),
      storeId: storeId,
      name: name.trim(),
      contactName: contactName.trim(),
      email: email.trim(),
      phone: phone.trim(),
      addressLine: addressLine.trim(),
      postalCode: postalCode.trim(),
      city: city.trim(),
      note: _clean(note),
    );

    await _db.into(_db.suppliers).insert(supplierToRow(supplier));
    return supplier;
  }

  /// Edits a supplier's details.
  ///
  /// Names are deliberately **not** checked for uniqueness. Two branches of the
  /// same butcher is a real situation, and blocking it would be the app
  /// inventing a rule the business does not have.
  Future<Supplier?> update(
    String id, {
    String? name,
    String? contactName,
    String? email,
    String? phone,
    String? addressLine,
    String? postalCode,
    String? city,
    String? note,
    bool clearNote = false,
  }) async {
    final trimmedName = name?.trim();
    if (trimmedName != null && trimmedName.isEmpty) return null;

    return _db.transaction(() async {
      final existing = await supplier(id);
      if (existing == null) return null;

      final updated = Supplier(
        id: existing.id,
        storeId: existing.storeId,
        name: trimmedName ?? existing.name,
        contactName: contactName?.trim() ?? existing.contactName,
        email: email?.trim() ?? existing.email,
        phone: phone?.trim() ?? existing.phone,
        addressLine: addressLine?.trim() ?? existing.addressLine,
        postalCode: postalCode?.trim() ?? existing.postalCode,
        city: city?.trim() ?? existing.city,
        note: clearNote ? null : _clean(note) ?? existing.note,
      );

      await (_db.update(_db.suppliers)..where((s) => s.id.equals(id))).write(
        supplierToRow(updated),
      );
      return updated;
    });
  }

  /// What would stop this supplier being deleted, or null if nothing would.
  Future<SupplierDeleteBlock?> deleteBlockedBy(String id) async {
    final orders = await OrderRepository(_db).ordersForSupplier(id);
    final hasOpen = orders.any(orderIsOpen);
    return hasOpen ? SupplierDeleteBlock.hasOpenOrder : null;
  }

  /// Deletes a supplier and the prices they offered.
  ///
  /// **Stock movements naming them are kept**, and so are their closed
  /// commandes. A movement is the record of goods that really moved; the
  /// supplier going away does not unmake that, and the screen renders
  /// "Fournisseur supprimé", which is true. Neither column carries a foreign key
  /// for exactly this reason.
  ///
  /// Every article this supplier was the default for gets a new default, or it
  /// silently loses its auto-fill on every stock-in and every order line with
  /// nothing on screen explaining why.
  Future<bool> delete(String id) {
    return _db.transaction(() async {
      if (await deleteBlockedBy(id) != null) return false;

      final orphaned = (await pricesForSupplier(id))
          .where((price) => price.isDefault)
          .map((price) => price.itemId)
          .toList();

      final removed = await (_db.delete(
        _db.suppliers,
      )..where((s) => s.id.equals(id))).go();
      if (removed == 0) return false;

      // The prices and their history went with the supplier through the
      // schema's cascade; the promotions are what the cascade cannot know to do.
      for (final itemId in orphaned) {
        await _promoteCheapestToDefault(itemId);
      }
      return true;
    });
  }

  // ---------------------------------------------------------------------------
  // Writes — the item-supplier link
  // ---------------------------------------------------------------------------

  /// Links an article to a supplier at a price.
  ///
  /// Returns null if the link already exists — that is an edit, not a new link,
  /// and silently overwriting the price would lose the history entry the edit
  /// path writes.
  Future<SupplierPrice?> linkItem({
    required String itemId,
    required String supplierId,
    required double pricePerUnit,
    bool makeDefault = false,
    DateTime? effectiveDate,
  }) async {
    if (pricePerUnit <= 0) return null;

    return _db.transaction(() async {
      if (await priceFor(itemId, supplierId) != null) return null;

      // The first supplier for an article becomes its default whether or not
      // the caller asked: an article with prices but no default has no auto-fill
      // anywhere, which reads as the feature being broken.
      final isFirst = (await pricesForItem(itemId)).isEmpty;
      final shouldDefault = makeDefault || isFirst;

      if (shouldDefault) await _clearDefaultFor(itemId);

      final price = SupplierPrice(
        id: newId(),
        itemId: itemId,
        supplierId: supplierId,
        pricePerUnit: pricePerUnit,
        effectiveDate: effectiveDate ?? DateTime.now(),
        isDefault: shouldDefault,
      );

      await _db.into(_db.supplierPrices).insert(supplierPriceToRow(price));
      return price;
    });
  }

  /// Changes what a supplier charges, and records why the number moved.
  ///
  /// Every change writes a history entry scoped to the item–supplier *pair*,
  /// which is what makes "what has this supplier charged us for chicken over six
  /// months" answerable.
  ///
  /// Setting the same price again writes nothing and returns the row unchanged.
  /// The threshold is `costEpsilon`, a tenth of a cent: a price that moved by
  /// less than that did not move, and a history full of no-op entries is a
  /// history nobody reads.
  Future<SupplierPrice?> updatePrice(
    String priceId,
    double newPrice, {
    String? changedByName,
    DateTime? changedAt,
  }) async {
    if (newPrice <= 0) return null;

    final author = changedByName ?? await AccountRepository(_db).currentUserName();

    return _db.transaction(() async {
      final row = await (_db.select(
        _db.supplierPrices,
      )..where((p) => p.id.equals(priceId))).getSingleOrNull();
      if (row == null) return null;

      final existing = supplierPriceFromRow(row);
      if ((existing.pricePerUnit - newPrice).abs() < costEpsilon) {
        return existing;
      }

      final at = changedAt ?? DateTime.now();

      await _db.into(_db.priceHistory).insert(
        priceHistoryToRow(
          PriceHistoryEntry(
            id: newId(),
            itemId: existing.itemId,
            supplierId: existing.supplierId,
            oldPrice: existing.pricePerUnit,
            newPrice: newPrice,
            changedAt: at,
            changedByName: author,
          ),
        ),
      );

      await (_db.update(
        _db.supplierPrices,
      )..where((p) => p.id.equals(priceId))).write(
        SupplierPricesCompanion(
          pricePerUnit: Value(newPrice),
          effectiveDate: Value(at),
        ),
      );

      return SupplierPrice(
        id: existing.id,
        itemId: existing.itemId,
        supplierId: existing.supplierId,
        pricePerUnit: newPrice,
        effectiveDate: at,
        isDefault: existing.isDefault,
      );
    });
  }

  /// Marks one supplier as the one normally used for an article.
  ///
  /// Clear-then-set, in a transaction, because "exactly one default per article"
  /// is not something SQLite can be asked to enforce without a trigger — and a
  /// trigger would be a second place the rule lives.
  Future<bool> setDefault(String priceId) {
    return _db.transaction(() async {
      final row = await (_db.select(
        _db.supplierPrices,
      )..where((p) => p.id.equals(priceId))).getSingleOrNull();
      if (row == null) return false;

      await _clearDefaultFor(row.itemId);
      await (_db.update(
        _db.supplierPrices,
      )..where((p) => p.id.equals(priceId))).write(
        const SupplierPricesCompanion(isDefault: Value(true)),
      );
      return true;
    });
  }

  /// Removes an item–supplier link.
  ///
  /// If it was the default, the cheapest remaining supplier is promoted. Without
  /// that the article keeps its other suppliers but loses its auto-fill
  /// everywhere, and nothing on screen explains why.
  ///
  /// The price history for the pair is kept: it records what that supplier
  /// charged while the link existed, which stays true afterwards.
  Future<bool> unlinkItem(String priceId) {
    return _db.transaction(() async {
      final row = await (_db.select(
        _db.supplierPrices,
      )..where((p) => p.id.equals(priceId))).getSingleOrNull();
      if (row == null) return false;

      await (_db.delete(
        _db.supplierPrices,
      )..where((p) => p.id.equals(priceId))).go();

      if (row.isDefault) await _promoteCheapestToDefault(row.itemId);
      return true;
    });
  }

  // ---------------------------------------------------------------------------
  // Default bookkeeping
  // ---------------------------------------------------------------------------

  Future<void> _clearDefaultFor(String itemId) async {
    await (_db.update(_db.supplierPrices)
          ..where((p) => p.itemId.equals(itemId) & p.isDefault.equals(true)))
        .write(const SupplierPricesCompanion(isDefault: Value(false)));
  }

  Future<void> _promoteCheapestToDefault(String itemId) async {
    final cheapest = await cheapestPriceForItem(itemId);
    if (cheapest == null) return;

    await (_db.update(
      _db.supplierPrices,
    )..where((p) => p.id.equals(cheapest.id))).write(
      const SupplierPricesCompanion(isDefault: Value(true)),
    );
  }

  String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
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
