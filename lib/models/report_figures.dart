/// Pre-computed shapes for the reports screens.
///
/// Not in the brief's model list, added because the alternative was worse: the
/// reports screens need aggregates, and computing them in a widget would mean
/// writing the business logic Phase 1 is supposed to defer. Hardcoding the
/// results keeps the aggregation out of the UI entirely.
///
/// Phase 2 replaces these with real query results. The screens should not need
/// to change shape when it does.
library;

/// One row of the stock valuation report.
class ValuationRow {
  const ValuationRow({
    required this.label,
    required this.itemCount,
    required this.totalValue,
    required this.shareOfTotal,
  });

  /// A category name, or an item name on the drilled-down view.
  final String label;

  final int itemCount;

  /// Total value in EUR, valued at each item's default supplier price.
  final double totalValue;

  /// 0.0–1.0, for the bar width.
  final double shareOfTotal;
}

/// One point on a usage or waste trend line.
class TrendPoint {
  const TrendPoint({required this.date, required this.value});

  final DateTime date;
  final double value;
}

/// One supplier's offer for an item, on the price comparison report.
///
/// This report is the headline feature for a multi-store owner: it is the
/// screen that shows them money they are currently leaving on the table.
class PriceComparisonRow {
  const PriceComparisonRow({
    required this.supplierId,
    required this.supplierName,
    required this.pricePerUnit,
    required this.lastUpdated,
    required this.isDefault,
    required this.isCheapest,
  });

  final String supplierId;
  final String supplierName;
  final double pricePerUnit;
  final DateTime lastUpdated;

  /// The supplier currently used by default for this item.
  final bool isDefault;

  /// The cheapest offer on the list. When this is true and [isDefault] is
  /// false, the store is overpaying — the screen calls that out.
  final bool isCheapest;
}
