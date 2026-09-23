import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/stock_status.dart';
import '../../../data/view_models/view_models.dart';
import '../../../models/models.dart';

/// How bad an alert is.
enum AlertSeverity {
  all,

  /// Nothing left at all.
  outOfStock,

  /// At or under the threshold, but still something on the shelf.
  lowStock,
}

/// Whether anybody has already dealt with the alert.
///
/// The distinction the screen exists for: an article that is low and already
/// ordered needs nothing from you today, and one that is low with nothing
/// coming needs a commande.
enum AlertCoverage { all, uncovered, onOrder }

/// The order the rows come in.
enum AlertSort {
  /// Worst first — the order the query already returns, which weighs how far
  /// under the threshold an article is rather than just its quantity.
  urgency,

  /// Biggest gap to fill first.
  shortfall,

  /// Alphabetical, for looking one up rather than working through them.
  name,
}

/// Local filter state for the alerts screen. UI state only — no business rules.
///
/// Everything here is applied in memory over the list `lowStockAlertsProvider`
/// already returns. The query behind it is a single joined statement that
/// carries the supplier and the on-order quantity, so narrowing it again in SQL
/// would buy nothing and cost a round trip per keystroke.
class AlertsFilter {
  const AlertsFilter({
    this.severity = AlertSeverity.all,
    this.coverage = AlertCoverage.all,
    this.supplierId,
    this.sort = AlertSort.urgency,
  });

  final AlertSeverity severity;
  final AlertCoverage coverage;

  /// The supplier who would fill the article, or [noSupplier] for the articles
  /// that have none.
  final String? supplierId;

  final AlertSort sort;

  /// Stands in for "the articles nobody supplies" in [supplierId]. They are a
  /// real group worth isolating — they are the ones no shortcut can order, and
  /// the reason is a gap in the catalogue rather than in the stock.
  static const String noSupplier = '~none';

  bool get hasActiveFilters => activeFilterCount > 0;

  /// How many controls are narrowing the list, for the button that stands in
  /// for them on a phone. The sort is not one: it reorders, it hides nothing.
  int get activeFilterCount =>
      (severity != AlertSeverity.all ? 1 : 0) +
      (coverage != AlertCoverage.all ? 1 : 0) +
      (supplierId != null ? 1 : 0);

  AlertsFilter copyWith({
    AlertSeverity? severity,
    AlertCoverage? coverage,
    String? supplierId,
    AlertSort? sort,
    bool clearSupplier = false,
  }) {
    return AlertsFilter(
      severity: severity ?? this.severity,
      coverage: coverage ?? this.coverage,
      supplierId: clearSupplier ? null : supplierId ?? this.supplierId,
      sort: sort ?? this.sort,
    );
  }

  /// The rows this filter leaves, in the order it asks for.
  List<LowStockAlertView> apply(List<LowStockAlertView> alerts) {
    final kept = alerts.where(_keeps).toList();

    switch (sort) {
      case AlertSort.urgency:
        // Already worst-first out of the query. Re-sorting would replace a
        // considered order with a cruder one.
        break;
      case AlertSort.shortfall:
        kept.sort((a, b) => _shortfallOf(b).compareTo(_shortfallOf(a)));
      case AlertSort.name:
        kept.sort(
          (a, b) => a.row.item.name.toLowerCase().compareTo(
            b.row.item.name.toLowerCase(),
          ),
        );
    }
    return kept;
  }

  bool _keeps(LowStockAlertView view) {
    final status = stockStatusOf(view.row.item);
    final severityOk = switch (severity) {
      AlertSeverity.all => true,
      AlertSeverity.outOfStock => status == StockStatus.outOfStock,
      AlertSeverity.lowStock => status == StockStatus.lowStock,
    };
    if (!severityOk) return false;

    final coverageOk = switch (coverage) {
      AlertCoverage.all => true,
      AlertCoverage.uncovered => view.onOrderQuantity <= 0,
      AlertCoverage.onOrder => view.onOrderQuantity > 0,
    };
    if (!coverageOk) return false;

    if (supplierId == null) return true;
    if (supplierId == noSupplier) return view.defaultSupplierId == null;
    return view.defaultSupplierId == supplierId;
  }

  static double _shortfallOf(LowStockAlertView view) {
    final item = view.row.item;
    final gap = item.lowStockThreshold - item.quantity;
    return gap > 0 ? gap : 0;
  }
}

class AlertsFilterNotifier extends Notifier<AlertsFilter> {
  @override
  AlertsFilter build() => const AlertsFilter();

  void setSeverity(AlertSeverity value) => state = state.copyWith(severity: value);

  void setCoverage(AlertCoverage value) => state = state.copyWith(coverage: value);

  void setSupplier(String? id) => id == null
      ? state = state.copyWith(clearSupplier: true)
      : state = state.copyWith(supplierId: id);

  void setSort(AlertSort value) => state = state.copyWith(sort: value);

  /// Clears what is hiding rows, keeping the order the user chose.
  void clear() => state = AlertsFilter(sort: state.sort);
}

/// Kept for the session, like the orders list's own filter.
final alertsFilterProvider =
    NotifierProvider<AlertsFilterNotifier, AlertsFilter>(
      AlertsFilterNotifier.new,
    );

/// Cards or a table — kept for the session, like the orders list.
enum AlertsViewMode { list, table }

class AlertsViewModeNotifier extends Notifier<AlertsViewMode> {
  @override
  AlertsViewMode build() => AlertsViewMode.list;

  void select(AlertsViewMode mode) => state = mode;
}

final alertsViewModeProvider =
    NotifierProvider<AlertsViewModeNotifier, AlertsViewMode>(
      AlertsViewModeNotifier.new,
    );

/// Which articles the user has ticked.
///
/// Ids rather than rows: the list behind them is a live stream, and a selection
/// holding stale copies would order against quantities that have since moved.
class AlertSelectionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  void toggle(String itemId) {
    final next = <String>{...state};
    next.contains(itemId) ? next.remove(itemId) : next.add(itemId);
    state = next;
  }

  void addAll(Iterable<String> itemIds) =>
      state = <String>{...state, ...itemIds};

  void removeAll(Iterable<String> itemIds) =>
      state = <String>{...state}..removeAll(itemIds);

  void clear() => state = const <String>{};
}

final alertSelectionProvider =
    NotifierProvider<AlertSelectionNotifier, Set<String>>(
      AlertSelectionNotifier.new,
    );
