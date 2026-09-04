import 'package:drift/drift.dart';

import '../../models/report_figures.dart';
import '../../models/stock_movement.dart';
import '../database/app_database.dart';

/// The figures the dashboard and the reports are built from.
///
/// Everything here is derived on read. None of it is stored, and the one number
/// that used to be — the stock valuation, a constant in `mock_reports.dart` —
/// was the reason: a headline figure that does not follow a delivery makes the
/// dashboard contradict the inventory two taps away.
///
/// **Stock is valued at what it cost, never at what the next unit will cost.**
/// `items.averageCost` is the weighted average the movement log maintains;
/// a supplier price is an asking price. Multiplying the latter by everything on
/// hand revalues stock bought weeks ago at this morning's delivery price — 50 kg
/// arriving at 10 EUR on top of 100 kg bought at 8 EUR reported 1 500 EUR when
/// 1 300 EUR had been spent. `tool/ux_audit.py` has a check whose whole job is to
/// stop that spelling coming back.
///
/// An article with no cost on file contributes nothing rather than an invented
/// figure. Understating is the safer direction: a valuation built partly on
/// guesses is worse than one that is visibly incomplete.
/// What counts as waste: thrown away, or spoiled before it could be used.
///
/// Named once because two figures are built from it — the waste value and the
/// waste trend — and a definition of waste that differed between a number and
/// the chart beside it would be worse than either.
const Set<StockOutReason> wasteReasons = {
  StockOutReason.waste,
  StockOutReason.spoilage,
};

class ReportRepository {
  const ReportRepository(this._db);

  final AppDatabase _db;

  // ---------------------------------------------------------------------------
  // Valuation
  // ---------------------------------------------------------------------------

  /// What the stock on hand is worth, at what it actually cost.
  Stream<double> watchStockValuation(String storeId) {
    final (query, read) = _valuationQuery(storeId);
    return query.watchSingle().map(read);
  }

  Future<double> stockValuation(String storeId) async {
    final (query, read) = _valuationQuery(storeId);
    return read(await query.getSingle());
  }

  /// Stock value per category, largest first.
  ///
  /// One `GROUP BY`, and the share of total is worked out from the same result
  /// set rather than by asking the database for the total a second time. Phase 1
  /// walked the establishment twice for this.
  Future<List<ValuationRow>> valuationByCategory(String storeId) async {
    final rows = await _db
        .customSelect(
          'SELECT c.name AS label, COUNT(i.id) AS item_count, '
          '  SUM(i.quantity * COALESCE(i.average_cost, 0)) AS total '
          'FROM items i '
          'JOIN categories c ON c.id = i.category_id '
          'WHERE i.store_id = ? '
          'GROUP BY i.category_id, c.name '
          'ORDER BY total DESC, c.name',
          variables: [Variable<String>(storeId)],
          readsFrom: {_db.items, _db.categories},
        )
        .get();

    final totals = rows.map((r) => r.read<double>('total')).toList();
    final grand = totals.fold<double>(0, (sum, value) => sum + value);

    return [
      for (final (index, row) in rows.indexed)
        ValuationRow(
          label: row.read<String>('label'),
          itemCount: row.read<int>('item_count'),
          totalValue: totals[index],
          shareOfTotal: grand == 0 ? 0 : totals[index] / grand,
        ),
    ];
  }

  /// The most valuable individual articles, largest first.
  ///
  /// `itemCount` carries the quantity on hand rather than a count, matching the
  /// column the report renders it in.
  ///
  /// The share is of the establishment's **whole** valuation, so the trimming to
  /// [limit] and the dropping of worthless articles both happen after the total
  /// is known — one query, one pass, rather than a second trip for a number the
  /// rows already contain.
  Future<List<ValuationRow>> valuationByItem(
    String storeId, {
    int limit = 10,
  }) async {
    final rows = await _db
        .customSelect(
          'SELECT name AS label, quantity, '
          '  quantity * COALESCE(average_cost, 0) AS total '
          'FROM items WHERE store_id = ? '
          'ORDER BY total DESC, name',
          variables: [Variable<String>(storeId)],
          readsFrom: {_db.items},
        )
        .get();

    final grand = rows.fold<double>(
      0,
      (sum, row) => sum + row.read<double>('total'),
    );

    return rows
        .map(
          (row) => ValuationRow(
            label: row.read<String>('label'),
            itemCount: row.read<double>('quantity').round(),
            totalValue: row.read<double>('total'),
            shareOfTotal: grand == 0
                ? 0
                : row.read<double>('total') / grand,
          ),
        )
        .where((row) => row.totalValue > 0)
        .take(limit)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // What stock cost on the way out
  // ---------------------------------------------------------------------------
  //
  // These exist because every movement records the cost it applied. Before that
  // the app could say six kilos of chicken were thrown away but not what those
  // six kilos cost — which is the half of the sentence an owner acts on.
  //
  // A movement with no cost recorded contributes nothing rather than a guess,
  // the same rule the valuation follows. Seeded history predates the cost
  // fields, so in a demo that is the normal case rather than an edge one.

  /// The cost of everything that left stock in the window.
  Future<double> consumptionValue(
    String storeId, {
    DateTime? from,
    DateTime? to,
  }) => _outboundValue(storeId, from: from, to: to);

  /// The cost of what was thrown away or spoiled in the window.
  ///
  /// The number the cost fields were added for. The usage report could already
  /// say how many kilos went in the bin; this says how many euros did, valued at
  /// what they actually cost rather than at a supplier's current asking price.
  Future<double> wasteValue(String storeId, {DateTime? from, DateTime? to}) =>
      _outboundValue(
        storeId,
        from: from,
        to: to,
        reasons: wasteReasons,
      );

  /// The cost of stock that went missing between counts, in the window.
  ///
  /// Downward adjustments only. An adjustment upwards is stock that was there
  /// all along and had simply not been recorded, which is not a loss.
  Future<double> shrinkageValue(
    String storeId, {
    DateTime? from,
    DateTime? to,
  }) {
    final movements = _db.stockMovements;
    return _sumCost(
      movements.storeId.equals(storeId) &
          movements.type.equalsValue(StockMovementType.adjustment) &
          movements.quantity.isSmallerThanValue(0),
      from: from,
      to: to,
    );
  }

  // ---------------------------------------------------------------------------
  // Price comparison
  // ---------------------------------------------------------------------------

  /// The article with the largest gap between its default and cheapest supplier.
  ///
  /// Falls back to any article with more than one supplier, then to the first
  /// article, then to null for an empty establishment — so the price comparison
  /// report opens on something worth looking at rather than on nothing.
  ///
  /// This was a Dart loop in `initState` that read every article in the
  /// establishment and called two lookups for each. It is a report query; it now
  /// lives with the report queries.
  /// Weekly outbound value, oldest first — the usage and waste trend lines.
  ///
  /// Phase 1 drew these from two frozen lists in `mock_reports.dart` that could
  /// not follow a stock-out recorded during the session. They are a `GROUP BY`
  /// over the movement log now, which means they move when the log does.
  ///
  /// **By week, not by month.** The seeded movement history covers a few weeks
  /// in detail, and a six-month series over it would be five empty columns and
  /// one tall one — which reads as a broken chart rather than as a young
  /// dataset. Weeks are the finest grain this data supports and the grain a
  /// kitchen actually plans in.
  ///
  /// The bucket is `strftime('%Y-%W')`, and each point is dated to the Monday
  /// that starts its week so the axis can be formatted like any other date.
  Future<List<TrendPoint>> usageTrend(String storeId, {int weeks = 8}) =>
      _trend(storeId, weeks: weeks, reasons: null);

  /// The same, restricted to what was thrown away.
  Future<List<TrendPoint>> wasteTrend(String storeId, {int weeks = 8}) =>
      _trend(storeId, weeks: weeks, reasons: wasteReasons);

  Future<List<TrendPoint>> _trend(
    String storeId, {
    required int weeks,
    required Set<StockOutReason>? reasons,
  }) async {
    final from = _startOfWeek(
      DateTime.now(),
    ).subtract(Duration(days: 7 * (weeks - 1)));

    final movements = await (_db.select(_db.stockMovements)..where(
          (m) =>
              m.storeId.equals(storeId) &
              m.type.equalsValue(StockMovementType.stockOut) &
              m.occurredAt.isBiggerOrEqualValue(from),
        ))
        .get();

    // Bucketed in Dart rather than in SQL. `strftime` would need the epoch
    // conversion spelled out and would still hand back a string to parse, and
    // the rows here are a few weeks of one establishment's stock-outs — not a
    // scan worth pushing down.
    final totals = <DateTime, double>{
      for (var i = 0; i < weeks; i++) from.add(Duration(days: 7 * i)): 0,
    };

    for (final row in movements) {
      if (reasons != null && !reasons.contains(row.reason)) continue;
      final bucket = _startOfWeek(row.occurredAt);
      if (!totals.containsKey(bucket)) continue;
      totals[bucket] = totals[bucket]! + row.quantity.abs() * (row.unitCost ?? 0);
    }

    final points = [
      for (final entry in totals.entries)
        TrendPoint(date: entry.key, value: entry.value),
    ]..sort((a, b) => a.date.compareTo(b.date));
    return points;
  }

  /// Midnight on the Monday that starts the given date's week.
  static DateTime _startOfWeek(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  /// What a year of the current overpayment would cost.
  ///
  /// The headline figure on the reports dashboard, and the one number in this
  /// app that a restaurant owner will repeat to somebody else. Phase 1 had it
  /// as a constant; it is now the actual gap between what the establishment
  /// pays and the best price on offer, across everything it bought in the last
  /// year, annualised.
  ///
  /// Deliberately conservative: it counts only articles that have both a
  /// default supplier and a cheaper one, and only what was actually delivered.
  /// A figure built from what somebody *might* buy would be a bigger number and
  /// a worse one.
  Future<double> potentialAnnualSaving(String storeId) async {
    final row = await _db
        .customSelect(
          'SELECT COALESCE(SUM(m.quantity * ('
          '  d.price_per_unit - ('
          '    SELECT MIN(p.price_per_unit) FROM supplier_prices p '
          '    WHERE p.item_id = d.item_id'
          '  )'
          ')), 0) AS saving '
          'FROM stock_movements m '
          'JOIN items i ON i.id = m.item_id '
          'JOIN supplier_prices d ON d.item_id = i.id AND d.is_default = 1 '
          "WHERE m.store_id = ? AND m.type = 'stockIn' "
          'AND m.occurred_at >= ?',
          variables: [
            Variable<String>(storeId),
            Variable<DateTime>(
              DateTime.now().subtract(const Duration(days: 365)),
            ),
          ],
          readsFrom: {_db.stockMovements, _db.items, _db.supplierPrices},
        )
        .getSingle();

    final saving = row.read<double?>('saving') ?? 0;
    return saving < 0 ? 0 : saving;
  }

  Future<String?> largestOverpayItemId(String storeId) async {
    final overpaying = await _db
        .customSelect(
          'SELECT d.item_id AS item_id, '
          '  d.price_per_unit - MIN(p.price_per_unit) AS gap '
          'FROM supplier_prices d '
          'JOIN items i ON i.id = d.item_id '
          'JOIN supplier_prices p ON p.item_id = d.item_id '
          'WHERE i.store_id = ? AND d.is_default = 1 '
          'GROUP BY d.item_id, d.price_per_unit '
          'HAVING gap > 0 '
          'ORDER BY gap DESC, d.item_id '
          'LIMIT 1',
          variables: [Variable<String>(storeId)],
          readsFrom: {_db.supplierPrices, _db.items},
        )
        .getSingleOrNull();
    if (overpaying != null) return overpaying.read<String>('item_id');

    final competing = await _db
        .customSelect(
          'SELECT p.item_id AS item_id FROM supplier_prices p '
          'JOIN items i ON i.id = p.item_id '
          'WHERE i.store_id = ? '
          'GROUP BY p.item_id HAVING COUNT(*) > 1 '
          'ORDER BY p.item_id LIMIT 1',
          variables: [Variable<String>(storeId)],
          readsFrom: {_db.supplierPrices, _db.items},
        )
        .getSingleOrNull();
    if (competing != null) return competing.read<String>('item_id');

    final any = await (_db.select(_db.items)
          ..where((i) => i.storeId.equals(storeId))
          ..orderBy([(i) => OrderingTerm(expression: i.name)])
          ..limit(1))
        .getSingleOrNull();
    return any?.id;
  }

  // ---------------------------------------------------------------------------

  (JoinedSelectStatement<HasResultSet, dynamic>, double Function(TypedResult))
  _valuationQuery(String storeId) {
    final value = _stockValue.sum();
    final query = _db.selectOnly(_db.items)
      ..addColumns([value])
      ..where(_db.items.storeId.equals(storeId));
    return (query, (TypedResult row) => row.read(value) ?? 0);
  }

  Expression<double> get _stockValue =>
      _db.items.quantity *
      coalesce([_db.items.averageCost, const Constant<double>(0)]);

  Future<double> _outboundValue(
    String storeId, {
    DateTime? from,
    DateTime? to,
    Set<StockOutReason>? reasons,
  }) {
    final movements = _db.stockMovements;
    var predicate =
        movements.storeId.equals(storeId) &
        movements.type.equalsValue(StockMovementType.stockOut);
    if (reasons != null) {
      predicate = predicate & movements.reason.isInValues(reasons.toList());
    }
    return _sumCost(predicate, from: from, to: to);
  }

  /// `SUM(ABS(quantity) * unit_cost)` over whatever the caller narrowed to.
  ///
  /// The window bounds are inclusive at both ends, matching the `_within` check
  /// they replace. Dates go in as typed values so drift converts them to the
  /// storage format; hand-formatting them would work right up until the day the
  /// format changed.
  Future<double> _sumCost(
    Expression<bool> predicate, {
    DateTime? from,
    DateTime? to,
  }) async {
    final movements = _db.stockMovements;
    final cost =
        (movements.quantity.abs() *
                coalesce([movements.unitCost, const Constant<double>(0)]))
            .sum();

    var where = predicate;
    if (from != null) {
      where = where & movements.occurredAt.isBiggerOrEqualValue(from);
    }
    if (to != null) {
      where = where & movements.occurredAt.isSmallerOrEqualValue(to);
    }

    final query = _db.selectOnly(movements)
      ..addColumns([cost])
      ..where(where);
    return (await query.getSingle()).read(cost) ?? 0;
  }
}
