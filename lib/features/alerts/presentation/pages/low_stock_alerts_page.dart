import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/busy_calendar.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/stock_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../data/providers.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../alerts_filter.dart';
import '../../../calendar/presentation/busy_labels.dart';
import '../../../inventory/presentation/widgets/product_drawer.dart';
import '../../../inventory/presentation/widgets/product_wizard_dialog.dart';

/// Everything at or below its threshold, worst first.
///
/// Each row states the shortfall — how much is needed to get back above the
/// threshold — and, since Phase 1.6, **how much is already on its way**. That
/// second figure is what turns the screen from a list of complaints into a list
/// of decisions: an item that is low and already ordered needs nothing from
/// you, and an item that is low with nothing coming needs a commande today.
///
/// The alert itself still fires on what is physically in the store. Goods in a
/// van do not cook dinner.
///
/// It is the establishment's first screen — first in the rail, and the one the
/// badge counts — so it opens with the shape of the problem rather than with
/// the rows: how many are out, how many are low, how many are handled, and how
/// many suppliers it would take to fix. The tabs under the counts narrow the
/// list by the same measures.
class LowStockAlertsPage extends ConsumerWidget {
  const LowStockAlertsPage({required this.storeId, super.key});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // Ordering and receiving both change what this screen should say, and the
    // query watches the tables both of them write to.
    final asyncAlerts = ref.watch(lowStockAlertsProvider(storeId));
    final all = asyncAlerts.value ?? const <LowStockAlertView>[];
    // The calendar's list: under the busy-day minimum, which holds products
    // that are fine on an ordinary day. Its own tab, and the banner's count.
    final busyAsync = ref.watch(busyAlertsProvider(storeId));
    final busyAll = busyAsync.value ?? const <LowStockAlertView>[];
    final warning = ref.watch(busyWarningProvider(storeId));
    final filter = ref.watch(alertsFilterProvider);
    final selection = ref.watch(alertSelectionProvider);
    final busy = filter.severity == AlertSeverity.busy;
    final shown = filter.apply(busy ? busyAll : all);

    // What the selection bar acts on: the ticked rows still on screen.
    final acting = shown
        .where((v) => selection.contains(v.row.item.id))
        .toList();

    return ShellPage(
      title: l10n.alertsTitle,
      // No header actions: each row's ⋮ carries its « Commander », and ticking
      // rows brings up the bar that orders several at once. Only while
      // something is ticked — a bar that is always there costs a row of
      // content on a short screen to say nothing.
      footer: selection.isEmpty
          ? null
          : _SelectionBar(
              alerts: acting,
              onClear: ref.read(alertSelectionProvider.notifier).clear,
              onCreate: () => _startOrders(context, acting, busy: busy),
            ),
      child: AsyncContent<List<LowStockAlertView>>(
        value: asyncAlerts,
        onRetry: () => ref.invalidate(lowStockAlertsProvider(storeId)),
        // Rows the height of the real ones, so the page does not jump when
        // the list arrives.
        skeleton: const SkeletonList(rows: 6, rowHeight: _rowHeight),
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Summary(
              alerts: all,
              busyAlerts: busyAsync,
              warning: warning,
              storeId: storeId,
            ),
            SizedBox(height: context.isPhone ? AppSpacing.lg : AppSpacing.xl),
            if (all.isEmpty && busyAll.isEmpty)
              EmptyState(
                icon: LucideIcons.packageCheck,
                title: l10n.alertsEmpty,
                message: l10n.alertsEmptyBody,
              )
            else ...[
              _StatusTabs(alerts: all, busyAlerts: busyAsync.value),
              const SizedBox(height: AppSpacing.md),
              _Toolbar(alerts: [...all, ...busyAll]),
              const SizedBox(height: AppSpacing.md),
              _Results(shown: shown, storeId: storeId, filter: filter),
            ],
          ],
        ),
      ),
    );
  }

  /// Groups the low items by the supplier who would fill them, and lets the
  /// manager start a draft per supplier.
  ///
  /// Grouping matters because a commande goes to exactly one supplier: offering
  /// a single "order everything" button would produce a document nobody can
  /// send. One tap per supplier is the smallest honest version of the action.
  Future<void> _startOrders(
    BuildContext context,
    List<LowStockAlertView> alerts, {
    required bool busy,
  }) async {
    final supplierId = await _SupplierGroupSheet.show(
      context,
      groupBySupplier(alerts),
    );
    if (supplierId == null || !context.mounted) return;

    // `prefill` tells the order form to add this supplier's low items straight
    // away, which is the whole point of arriving from here.
    context.pushScreen(
      '${Routes.toNewOrder(storeId)}?supplier=$supplierId'
      '&prefill=${busy ? 'busy' : '1'}',
    );
  }
}

/// One entry per supplier who could fill some of [alerts]: what they are
/// called, and how many lines they would carry.
///
/// Articles with no default supplier are left out rather than pooled: a
/// commande needs somebody to send it to, and a group that cannot become a
/// document is not an option worth offering.
///
/// Lines, and deliberately not a total shortfall. The articles under one
/// supplier are measured in different units — kilos, crates, litres — and a
/// figure that adds them together would be a number with no meaning printed
/// where a useful one is expected.
Map<String, ({String name, int count})> groupBySupplier(
  List<LowStockAlertView> alerts,
) {
  final grouped = <String, ({String name, int count})>{};
  for (final alert in alerts) {
    final supplierId = alert.defaultSupplierId;
    if (supplierId == null) continue;
    final existing = grouped[supplierId];
    grouped[supplierId] = (
      name: alert.defaultSupplierName ?? existing?.name ?? '—',
      count: (existing?.count ?? 0) + 1,
    );
  }
  return grouped;
}

// -----------------------------------------------------------------------------
// The summary.
// -----------------------------------------------------------------------------

/// Four counts above the list: what the coming busy days are short of, how
/// many products are out, how many are low, and how many are fine.
///
/// Read-only. The tabs under them are the way to narrow the list; a count
/// that was also a button made two controls for one thing, and a tap on a
/// figure that only meant to be read changed the rows beneath it. "Stock OK"
/// counts the catalogue rather than the alerts, since the alerts by definition
/// hold none of them.
///
/// A count still loading shows a dash rather than a zero: a zero is a claim
/// about the stock, and it would be made before anything was read.
class _Summary extends ConsumerWidget {
  const _Summary({
    required this.alerts,
    required this.busyAlerts,
    required this.warning,
    required this.storeId,
  });

  /// Every alert, before any filtering.
  final List<LowStockAlertView> alerts;

  /// Every product under its busy-day minimum, as it loads.
  final AsyncValue<List<LowStockAlertView>> busyAlerts;

  /// The busy period the calendar is warning about, if one is near.
  final BusyPeriod? warning;

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final items = ref.watch(itemsByNameProvider(storeId));
    final today = ref.watch(todayProvider);
    final period = warning;

    final out = alerts
        .where((v) => stockStatusOf(v.row.item) == StockStatus.outOfStock)
        .length;
    final low = alerts.length - out;
    final ok = items.value
        ?.where((i) => stockStatusOf(i) == StockStatus.inStock)
        .length;
    final busy = busyAlerts.value?.length;

    return StatTileRow(
      spacing: context.isPhone ? AppSpacing.sm : AppSpacing.md,
      tiles: [
        StatTile(
          value: busy == null ? '–' : '$busy',
          label: period == null
              ? l10n.alertsSummaryBusy
              : l10n.alertsBusyBannerTitle(
                  busyWhenLabel(l10n, today, period.start),
                ),
          // The only caption kept: when the busy days are is information,
          // the others only restated their label.
          caption: period == null
              ? null
              : busyPeriodLabel(l10n, period, capitalized: true),
          icon: LucideIcons.calendarClock,
          // Amber only while a busy period is near and something is short
          // of it. Ahead of time the list is a check, not an alarm.
          accent: period != null && (busy ?? 0) > 0 ? AppColors.lowStock : null,
        ),
        StatTile(
          value: '$out',
          label: l10n.alertsSeverityOutOfStock,
          icon: StockStatusBadge.iconFor(StockStatus.outOfStock),
          // Tinted only when there is something to see. A red zero is an
          // alarm about nothing.
          accent: out > 0 ? AppColors.outOfStock : null,
        ),
        StatTile(
          value: '$low',
          label: l10n.alertsSeverityLowStock,
          icon: StockStatusBadge.iconFor(StockStatus.lowStock),
          accent: low > 0 ? AppColors.lowStock : null,
        ),
        StatTile(
          value: ok == null ? '–' : '$ok',
          label: l10n.alertsSummaryOk,
          icon: StockStatusBadge.iconFor(StockStatus.inStock),
          accent: AppColors.inStock,
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// The tabs and the toolbar.
// -----------------------------------------------------------------------------

/// Tous · Jours chargés · Rupture · Stock bas, each with the rows it would
/// show under the dropdowns as they are set — so a tab never promises rows
/// the category or the supplier then hides.
class _StatusTabs extends ConsumerWidget {
  const _StatusTabs({required this.alerts, required this.busyAlerts});

  final List<LowStockAlertView> alerts;

  /// Null while the busy list is loading.
  final List<LowStockAlertView>? busyAlerts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(alertsFilterProvider);

    int count(AlertSeverity severity, List<LowStockAlertView> from) =>
        filter.copyWith(severity: severity).apply(from).length;
    final busy = busyAlerts;

    return CountTabs<AlertSeverity>(
      selected: filter.severity,
      onSelected: ref.read(alertsFilterProvider.notifier).setSeverity,
      tabs: [
        CountTab(
          value: AlertSeverity.all,
          label: l10n.alertsTabEvery,
          count: count(AlertSeverity.all, alerts),
        ),
        CountTab(
          value: AlertSeverity.busy,
          label: l10n.alertsBusyTab,
          count: busy == null ? null : count(AlertSeverity.busy, busy),
        ),
        CountTab(
          value: AlertSeverity.outOfStock,
          label: l10n.alertsPriorityOut,
          count: count(AlertSeverity.outOfStock, alerts),
        ),
        CountTab(
          value: AlertSeverity.lowStock,
          label: l10n.alertsSeverityLowStock,
          count: count(AlertSeverity.lowStock, alerts),
        ),
      ],
    );
  }
}

/// The search, then Catégorie, Fournisseur and Couverture — the same strip as
/// the pointage history, so it folds behind one button on a small screen —
/// and, on a wide one, « Réinitialiser » and the table / grid switch.
///
/// The dropdowns offer only what the alerts hold: a category with nothing
/// low in it is a choice that can only empty the list.
class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.alerts});

  /// Every alert, ordinary and busy, for the dropdowns' choices.
  final List<LowStockAlertView> alerts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(alertsFilterProvider);
    final notifier = ref.read(alertsFilterProvider.notifier);

    final categories = <String, String>{
      for (final v in alerts) v.row.item.categoryId: v.row.categoryName,
    };
    final suppliers = <String, String>{
      for (final v in alerts)
        if (v.defaultSupplierId != null)
          v.defaultSupplierId!: v.defaultSupplierName ?? '—',
    };
    int byName(MapEntry<String, String> a, MapEntry<String, String> b) =>
        a.value.toLowerCase().compareTo(b.value.toLowerCase());
    final sortedCategories = categories.entries.toList()..sort(byName);
    final sortedSuppliers = suppliers.entries.toList()..sort(byName);

    final wide = !context.isSmallScreen;

    return FilterToolbar(
      activeCount: filter.activeFilterCount,
      onClear: notifier.clear,
      search: SearchField(
        hint: l10n.alertsSearchHint,
        initialValue: filter.query,
        onChanged: notifier.setQuery,
        maxWidth: double.infinity,
      ),
      filters: [
        FilterMenu<String?>(
          label: l10n.inventoryFilterCategory,
          selectedLabel: categories[filter.categoryId],
          entries: {
            null: l10n.inventoryFilterAll,
            for (final e in sortedCategories) e.key: e.value,
          },
          onSelected: notifier.setCategory,
        ),
        FilterMenu<String?>(
          label: l10n.alertsFilterSupplier,
          selectedLabel: filter.supplierId == AlertsFilter.noSupplier
              ? l10n.alertsNoSupplier
              : suppliers[filter.supplierId],
          entries: {
            null: l10n.alertsFilterAllSuppliers,
            for (final e in sortedSuppliers) e.key: e.value,
            AlertsFilter.noSupplier: l10n.alertsNoSupplier,
          },
          onSelected: notifier.setSupplier,
        ),
        FilterMenu<AlertCoverage>(
          label: l10n.alertsFilterCoverage,
          selectedLabel: switch (filter.coverage) {
            AlertCoverage.all => null,
            AlertCoverage.uncovered => l10n.alertsCoverageUncovered,
            AlertCoverage.onOrder => l10n.alertsCoverageOnOrder,
          },
          entries: {
            AlertCoverage.all: l10n.alertsFilterAll,
            AlertCoverage.uncovered: l10n.alertsCoverageUncovered,
            AlertCoverage.onOrder: l10n.alertsCoverageOnOrder,
          },
          onSelected: notifier.setCoverage,
        ),
        if (wide && filter.hasActiveFilters)
          TextButton.icon(
            onPressed: notifier.clear,
            icon: const Icon(LucideIcons.x, size: AppSizing.iconSm),
            label: Text(l10n.filtersReset),
          ),
        // The table needs the room a small screen does not have, so there is
        // no choice to offer there.
        if (wide)
          ViewModeToggle<AlertsViewMode>(
            value: ref.watch(alertsViewModeProvider),
            onSelected: ref.read(alertsViewModeProvider.notifier).select,
            options: [
              ViewModeOption(
                value: AlertsViewMode.list,
                icon: LucideIcons.list,
                label: l10n.movementsViewList,
              ),
              ViewModeOption(
                value: AlertsViewMode.table,
                icon: LucideIcons.table,
                label: l10n.movementsViewTable,
              ),
            ],
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// The results.
// -----------------------------------------------------------------------------

class _Results extends ConsumerWidget {
  const _Results({
    required this.shown,
    required this.storeId,
    required this.filter,
  });

  final List<LowStockAlertView> shown;
  final String storeId;
  final AlertsFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    final busy = filter.severity == AlertSeverity.busy;

    // The order is the query's — worst first — or the one the user picked.
    final wantsTable =
        !context.isPhone &&
        ref.watch(alertsViewModeProvider) == AlertsViewMode.table;

    return LayoutBuilder(
      builder: (context, constraints) {
        // The table's fixed columns — checkbox, status, actions — take their
        // width before the product gets any, so below [_tableMinWidth] (a
        // small tablet in portrait, or a large text size) the cards stand in
        // for it rather than a product name squeezed to nothing.
        final table = wantsTable && constraints.maxWidth >= _tableMinWidth;

        final header = _ResultsHeader(
          alerts: shown,
          // The table has its own select-all in its header.
          selectAll: !table && shown.isNotEmpty,
        );

        final Widget body;
        if (shown.isEmpty) {
          body = _emptyState(l10n, ref, busy: busy);
        } else if (table) {
          body = _AlertsTable(alerts: shown, storeId: storeId, busy: busy);
        } else {
          final cards = [
            for (final view in shown)
              _AlertCard(view: view, storeId: storeId, busy: busy),
          ];
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, card) in cards.indexed) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                card,
              ],
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: AppSpacing.sm),
            body,
          ],
        );
      },
    );
  }

  Widget _emptyState(
    AppLocalizations l10n,
    WidgetRef ref, {
    required bool busy,
  }) {
    // Nothing narrowing the list: it is genuinely empty, which is good news
    // rather than a filter to clear.
    final narrowed = filter.query.trim().isNotEmpty || filter.hasActiveFilters;
    if (!narrowed && busy) {
      return EmptyState(
        icon: LucideIcons.calendarCheck,
        title: l10n.alertsBusyEmpty,
        message: l10n.alertsBusyEmptyBody,
      );
    }
    if (!narrowed && filter.severity == AlertSeverity.all) {
      return EmptyState(
        icon: LucideIcons.packageCheck,
        title: l10n.alertsEmpty,
        message: l10n.alertsEmptyBody,
      );
    }
    return EmptyState.noResults(
      l10n,
      onClearFilters: ref.read(alertsFilterProvider.notifier).clear,
    );
  }
}

/// The narrowest content width the alerts table is drawn at.
const double _tableMinWidth = 900;

/// Above the rows: how many there are, and the select-all where the table's
/// own header does not carry one.
class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({required this.alerts, required this.selectAll});

  final List<LowStockAlertView> alerts;
  final bool selectAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final medallion = context.isPhone ? 36.0 : AppSizing.statTileMedallion;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: Row(
        children: [
          Container(
            width: medallion,
            height: medallion,
            decoration: BoxDecoration(
              color: AppColors.outOfStock.container,
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.bell,
              size: AppSizing.iconSm,
              color: AppColors.outOfStock.solid,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              l10n.alertsCount(alerts.length),
              style:
                  (context.isPhone
                          ? theme.textTheme.titleMedium
                          : theme.textTheme.titleLarge)
                      ?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (selectAll) ...[
            const SizedBox(width: AppSpacing.xs),
            _SelectAllCheckbox(alerts: alerts),
          ],
        ],
      ),
    );
  }
}

/// Ticks every row shown, or clears them — a dash while only some are ticked.
class _SelectAllCheckbox extends ConsumerWidget {
  const _SelectAllCheckbox({required this.alerts});

  final List<LowStockAlertView> alerts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selection = ref.watch(alertSelectionProvider);
    final notifier = ref.read(alertSelectionProvider.notifier);
    final ids = alerts.map((v) => v.row.item.id).toList();
    final ticked = ids.where(selection.contains).length;
    final all = ticked == ids.length && ids.isNotEmpty;

    return Checkbox(
      tristate: true,
      value: all ? true : (ticked == 0 ? false : null),
      semanticLabel: l10n.alertsSelectAll,
      visualDensity: VisualDensity.compact,
      onChanged: (_) => all ? notifier.removeAll(ids) : notifier.addAll(ids),
    );
  }
}

// -----------------------------------------------------------------------------
// The pieces a row and a card share.
// -----------------------------------------------------------------------------

/// The height of a table row, and of the skeleton rows that stand in for it.
const double _rowHeight = 72;

/// Below this table width the supplier column goes, and the supplier moves
/// under the product's name instead — a tablet in portrait.
const double _supplierColumnMinWidth = 1240;

/// What one alert row says, worked out once for the table and the card alike.
class _AlertFacts {
  _AlertFacts(this.view, {required this.busy});

  final LowStockAlertView view;

  /// Measured against the busy-day minimum rather than the ordinary one.
  final bool busy;

  Item get item => view.row.item;
  String get unit => view.row.unitAbbreviation;
  StockStatus get status => stockStatusOf(item);
  StockStatusColors get colors => StockStatusBadge.colorsFor(status);
  double get minimum => busy ? holidayMinimumOf(item) : item.lowStockThreshold;

  /// What a commande started from here would ask for: the existing top-up
  /// rules, the same ones the order form prefills with — up to the maximum,
  /// or to the busy-day minimum on the busy list when that is more.
  double get toOrder => busy ? busyTopUpQuantity(item) : topUpQuantity(item);

  String quantity(double value) => Formatters.quantityWithUnit(value, unit);
}

/// The figure in its status colour, a slim bar under it, and what is already
/// on its way when something is.
class _StockLevel extends StatelessWidget {
  const _StockLevel({required this.facts});

  final _AlertFacts facts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final view = facts.view;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          facts.quantity(facts.item.quantity),
          style: AppTypography.numeric.copyWith(
            fontSize: context.tableFigureSize,
            fontWeight: FontWeight.w700,
            color: facts.colors.foreground,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        StockGauge(
          quantity: facts.item.quantity,
          minimum: facts.minimum,
          maximum: facts.item.maxStock,
          height: 5,
        ),
        // Only stock genuinely on its way says so: silence means nothing is
        // coming, which is the case that needs a commande.
        if (view.onOrderQuantity > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              const Icon(
                LucideIcons.truck,
                size: 12,
                color: AppColors.primary700,
              ),
              const SizedBox(width: AppSpacing.xxs + 2),
              Flexible(
                child: Text(
                  l10n.alertsOnOrder(facts.quantity(view.onOrderQuantity)),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.primary700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// How much to order, emphasised — in red when the shelf is empty.
class _ToOrder extends StatelessWidget {
  const _ToOrder({required this.facts});

  final _AlertFacts facts;

  @override
  Widget build(BuildContext context) {
    final amount = facts.toOrder;
    return Text(
      amount > 0 ? facts.quantity(amount) : '—',
      style: AppTypography.numeric.copyWith(
        fontSize: context.tableFigureSize,
        fontWeight: FontWeight.w700,
        color: facts.status == StockStatus.outOfStock
            ? AppColors.outOfStock.foreground
            : AppColors.textPrimary,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// The supplier a commande would go to, or plainly none — never a guess.
class _SupplierName extends StatelessWidget {
  const _SupplierName({required this.facts});

  final _AlertFacts facts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final name = facts.view.defaultSupplierName;

    return Text(
      name ?? l10n.alertsNoSupplier,
      style: name == null
          ? theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            )
          : theme.textTheme.bodyMedium,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// The status badge — Rupture, Stock bas, Stock OK. How far under the minimum
/// the row is reads from the bar and « À commander », not from more words.
class _Priority extends StatelessWidget {
  const _Priority({required this.facts});

  final _AlertFacts facts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = facts.status;

    return StatusPill(
      colors: facts.colors,
      icon: StockStatusBadge.iconFor(status),
      label: switch (status) {
        StockStatus.outOfStock => l10n.alertsPriorityOut,
        StockStatus.lowStock => l10n.alertsPriorityLow,
        StockStatus.inStock => l10n.alertsPriorityOk,
      },
    );
  }
}

/// The row's checkbox.
class _RowCheckbox extends ConsumerWidget {
  const _RowCheckbox({required this.item, this.shrinkWrap = false});

  final Item item;

  /// Drawn to its box alone — on the card's photo, where a full tap target
  /// would cover the picture.
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(alertSelectionProvider).contains(item.id);
    return Checkbox(
      value: selected,
      semanticLabel: item.name,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: shrinkWrap
          ? MaterialTapTargetSize.shrinkWrap
          : null,
      onChanged: (_) =>
          ref.read(alertSelectionProvider.notifier).toggle(item.id),
    );
  }
}

String _orderPath(String storeId, String supplierId, bool busy) =>
    '${Routes.toNewOrder(storeId)}?supplier=$supplierId'
    '&prefill=${busy ? 'busy' : '1'}';

enum _RowAction { order, linkSupplier, open, delivery, movements, thresholds }

/// The ⋮ on each row, and the row's only action control.
///
/// The step that fixes the alert comes first, set apart by a divider:
/// « Commander chez … » starts a commande with this row's supplier, the low
/// items already on it. A product nobody supplies cannot be ordered — a
/// commande goes to one supplier — so in its place « Associer un
/// fournisseur » opens the screen that links one, which is the step actually
/// missing. Then the ways to look closer: the product, a delivery, its
/// movements, and its thresholds when the alert itself is the mistake.
class _RowMenu extends StatelessWidget {
  const _RowMenu({required this.facts, required this.storeId});

  final _AlertFacts facts;
  final String storeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final supplierId = facts.view.defaultSupplierId;
    final supplierName = facts.view.defaultSupplierName;
    final itemId = facts.item.id;

    return PopupMenuButton<_RowAction>(
      tooltip: l10n.itemMoreActions,
      icon: const Icon(LucideIcons.ellipsisVertical, size: AppSizing.iconSm),
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      position: PopupMenuPosition.under,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      onSelected: (action) => switch (action) {
        _RowAction.order => context.pushScreen(
          _orderPath(storeId, supplierId!, facts.busy),
        ),
        _RowAction.linkSupplier => context.pushScreen(
          Routes.toLinkSupplier(storeId, itemId),
        ),
        _RowAction.open => openProductDrawer(
          context,
          storeId: storeId,
          itemId: itemId,
        ),
        _RowAction.delivery => context.pushScreen(Routes.toStockIn(storeId)),
        _RowAction.movements => context.pushScreen(
          Routes.toMovements(storeId, itemId: itemId),
        ),
        _RowAction.thresholds => showProductWizard(
          context,
          storeId: storeId,
          itemId: itemId,
        ),
      },
      itemBuilder: (context) => [
        if (supplierId != null)
          _menuItem(
            _RowAction.order,
            LucideIcons.shoppingCart,
            supplierName == null
                ? l10n.alertsOrder
                : l10n.alertsOrderFrom(supplierName),
            primary: true,
          )
        else
          _menuItem(
            _RowAction.linkSupplier,
            LucideIcons.link,
            l10n.itemLinkSupplier,
            primary: true,
          ),
        const PopupMenuDivider(),
        _menuItem(
          _RowAction.open,
          LucideIcons.packageSearch,
          l10n.alertsOpenProduct,
        ),
        _menuItem(
          _RowAction.delivery,
          LucideIcons.arrowDownToLine,
          l10n.actionAddDelivery,
        ),
        _menuItem(
          _RowAction.movements,
          LucideIcons.history,
          l10n.alertsViewMovements,
        ),
        _menuItem(
          _RowAction.thresholds,
          LucideIcons.slidersHorizontal,
          l10n.alertsEditThresholds,
        ),
      ],
    );
  }

  PopupMenuItem<_RowAction> _menuItem(
    _RowAction value,
    IconData icon,
    String label, {
    bool primary = false,
  }) => PopupMenuItem(
    value: value,
    child: Row(
      children: [
        Icon(
          icon,
          size: AppSizing.iconSm,
          color: primary ? AppColors.primary700 : AppColors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: primary
                ? const TextStyle(
                    color: AppColors.primary700,
                    fontWeight: FontWeight.w600,
                  )
                : null,
          ),
        ),
      ],
    ),
  );
}

/// The photo, the name, and the category in one muted line — with the
/// supplier after it where no column of its own shows it.
class _ProductIdentity extends StatelessWidget {
  const _ProductIdentity({required this.facts, this.showSupplier = false});

  final _AlertFacts facts;
  final bool showSupplier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final view = facts.view;
    final supplierName = showSupplier ? view.defaultSupplierName : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProductImage(
          imagePath: facts.item.imagePath,
          size: 40,
          radius: AppRadius.sm,
          placeholder: ProductImagePlaceholder.disc,
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Formatters.capitalized(facts.item.name),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                supplierName == null
                    ? view.row.categoryName
                    : '${view.row.categoryName} · $supplierName',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// The table — the default on a wide screen.
// -----------------------------------------------------------------------------

/// One aligned line per product: who, how much, against what, how much to
/// order, from whom, how bad, and the ⋮ that holds every action on it.
///
/// Drawn in the same [DataTableWrapper] as the pointage and payment
/// histories, so every table in the app reads alike. Narrower, the supplier
/// goes first — it moves under the product's name — then the minimum, so the
/// stock, the quantity to order, the status and the action are always there.
/// Below [_tableMinWidth] the cards take over.
class _AlertsTable extends ConsumerWidget {
  const _AlertsTable({
    required this.alerts,
    required this.storeId,
    this.busy = false,
  });

  final List<LowStockAlertView> alerts;
  final String storeId;

  /// Measured against the busy-day minimum rather than the ordinary one.
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selection = ref.watch(alertSelectionProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final supplierColumn = width >= _supplierColumnMinWidth;
        final minimumColumn = width >= 1080;

        return DataTableWrapper(
          minWidth: _tableMinWidth,
          columns: [
            DataColumn(label: _SelectAllCheckbox(alerts: alerts)),
            DataColumn(label: Text(l10n.tableColProduct)),
            DataColumn(label: Text(l10n.tableColStock)),
            if (minimumColumn)
              DataColumn(label: Text(l10n.alertsColumnMinimum), numeric: true),
            DataColumn(label: Text(l10n.alertsColumnToOrder), numeric: true),
            if (supplierColumn) DataColumn(label: Text(l10n.tableColSupplier)),
            DataColumn(label: Text(l10n.tableColStatus)),
            DataColumn(label: Text(l10n.employeesColumnActions)),
          ],
          rows: [
            for (final v in alerts)
              _row(
                context,
                _AlertFacts(v, busy: busy),
                selected: selection.contains(v.row.item.id),
                supplierColumn: supplierColumn,
                minimumColumn: minimumColumn,
              ),
          ],
        );
      },
    );
  }

  DataRow _row(
    BuildContext context,
    _AlertFacts facts, {
    required bool selected,
    required bool supplierColumn,
    required bool minimumColumn,
  }) {
    return DataRow(
      selected: selected,
      onSelectChanged: (_) =>
          openProductDrawer(context, storeId: storeId, itemId: facts.item.id),
      cells: [
        DataCell(_RowCheckbox(item: facts.item)),
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: _ProductIdentity(
              facts: facts,
              showSupplier: !supplierColumn,
            ),
          ),
        ),
        DataCell(SizedBox(width: 130, child: _StockLevel(facts: facts))),
        if (minimumColumn)
          DataCell(
            Text(
              facts.quantity(facts.minimum),
              style: AppTypography.numeric.copyWith(
                fontSize: context.tableFigureSize,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
            ),
          ),
        DataCell(_ToOrder(facts: facts)),
        if (supplierColumn)
          DataCell(
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: _SupplierName(facts: facts),
            ),
          ),
        DataCell(_Priority(facts: facts)),
        DataCell(_RowMenu(facts: facts, storeId: storeId)),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// The card — the default view, one per line.
// -----------------------------------------------------------------------------

/// One alert, drawn like a movement card (`MovementCard`) so the two lists
/// read alike — one card per line, and two shapes picked by the card's width:
///
/// - **Narrow (a phone):** the photo with its checkbox on the corner; beside
///   it the name, the status badge, the category and supplier, and the ⋮.
///   Under them three facts split by hairlines: the stock, the minimum, and
///   how much to order.
/// - **Wide ([_wideMinWidth] and up):** one line — checkbox, product, then
///   the same facts in blocks, the ⋮ and the chevron. On a narrower pane the
///   minimum goes first.
///
/// The card opens the product; a long press ticks it for the selection bar.
class _AlertCard extends ConsumerWidget {
  const _AlertCard({
    required this.view,
    required this.storeId,
    this.busy = false,
  });

  final LowStockAlertView view;
  final String storeId;
  final bool busy;

  /// The narrowest card drawn as one line.
  static const double _wideMinWidth = 560;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facts = _AlertFacts(view, busy: busy);
    final selected = ref.watch(alertSelectionProvider).contains(facts.item.id);

    // The width is read outside the cards' IntrinsicHeight: a LayoutBuilder
    // cannot answer the intrinsic-size questions IntrinsicHeight asks.
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideMinWidth;
        return GestureDetector(
          onLongPress: () =>
              ref.read(alertSelectionProvider.notifier).toggle(facts.item.id),
          child: AppCard(
            onTap: () => openProductDrawer(
              context,
              storeId: storeId,
              itemId: facts.item.id,
            ),
            selected: selected,
            bordered: false,
            tintColor: facts.colors.solid,
            padding: wide
                ? const EdgeInsets.fromLTRB(
                    AppSpacing.xs,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                  )
                : const EdgeInsets.all(AppSpacing.md + 2),
            child: wide
                ? _WideAlertContent(
                    facts: facts,
                    storeId: storeId,
                    width: constraints.maxWidth,
                  )
                : _NarrowAlertContent(facts: facts, storeId: storeId),
          ),
        );
      },
    );
  }
}

/// The card on a phone: the product on top, the three facts under it.
class _NarrowAlertContent extends StatelessWidget {
  const _NarrowAlertContent({required this.facts, required this.storeId});

  final _AlertFacts facts;
  final String storeId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardThumb(facts: facts, size: 64),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                child: _CardIdentity(facts: facts, nameLines: 2),
              ),
            ),
            Transform.translate(
              // Into the corner: its tap target is wider than its dots.
              offset: const Offset(AppSpacing.sm, -AppSpacing.xs),
              child: _RowMenu(facts: facts, storeId: storeId),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _StockFact(facts: facts)),
              const _FactRule(),
              Expanded(child: _MinimumFact(facts: facts)),
              const _FactRule(),
              Expanded(child: _ToOrderFact(facts: facts)),
            ],
          ),
        ),
        _OnOrderLine(facts: facts),
      ],
    );
  }
}

/// The card on a tablet or a desktop: everything on one line.
class _WideAlertContent extends StatelessWidget {
  const _WideAlertContent({
    required this.facts,
    required this.storeId,
    required this.width,
  });

  final _AlertFacts facts;
  final String storeId;
  final double width;

  @override
  Widget build(BuildContext context) {
    final showMinimum = width >= 820;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _RowCheckbox(item: facts.item)),
          const SizedBox(width: AppSpacing.xs),
          // The product.
          Expanded(
            child: Row(
              children: [
                ProductImage(
                  imagePath: facts.item.imagePath,
                  size: 56,
                  radius: AppRadius.md,
                  placeholder: ProductImagePlaceholder.disc,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _CardIdentity(facts: facts, nameLines: 1)),
              ],
            ),
          ),
          const _FactRule(wide: true),
          SizedBox(
            width: 140,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StockFact(facts: facts),
                _OnOrderLine(facts: facts, dense: true),
              ],
            ),
          ),
          if (showMinimum) ...[
            const _FactRule(wide: true),
            SizedBox(width: 150, child: _MinimumFact(facts: facts)),
          ],
          const _FactRule(wide: true),
          SizedBox(width: 140, child: _ToOrderFact(facts: facts)),
          const SizedBox(width: AppSpacing.sm),
          Center(
            child: _RowMenu(facts: facts, storeId: storeId),
          ),
          const Center(
            child: Icon(
              LucideIcons.chevronRight,
              size: AppSizing.iconSm,
              color: AppColors.primary600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The name, the status badge under it, then the category and supplier.
class _CardIdentity extends StatelessWidget {
  const _CardIdentity({required this.facts, required this.nameLines});

  final _AlertFacts facts;
  final int nameLines;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final view = facts.view;
    final supplierName = view.defaultSupplierName;
    final status = facts.status;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          Formatters.capitalized(facts.item.name),
          style: theme.textTheme.titleSmall?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          maxLines: nameLines,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs),
        // The movement type badge's shape.
        LabelChip(
          label: switch (status) {
            StockStatus.outOfStock => l10n.alertsPriorityOut,
            StockStatus.lowStock => l10n.alertsPriorityLow,
            StockStatus.inStock => l10n.alertsPriorityOk,
          },
          icon: StockStatusBadge.iconFor(status),
          background: facts.colors.container,
          foreground: facts.colors.foreground,
          borderRadius: AppRadius.smAll,
          dense: true,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          supplierName == null
              ? view.row.categoryName
              : '${view.row.categoryName} · $supplierName',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// The photo, with the row's checkbox on its corner.
class _CardThumb extends StatelessWidget {
  const _CardThumb({required this.facts, required this.size});

  final _AlertFacts facts;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          ProductImage(
            imagePath: facts.item.imagePath,
            size: size,
            radius: 14,
            placeholder: ProductImagePlaceholder.disc,
          ),
          Positioned(
            left: AppSpacing.xs,
            top: AppSpacing.xs,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.smAll,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neutral950.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Transform.scale(
                scale: 0.85,
                child: _RowCheckbox(item: facts.item, shrinkWrap: true),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What is on the shelf, in the status colour.
class _StockFact extends StatelessWidget {
  const _StockFact({required this.facts});

  final _AlertFacts facts;

  @override
  Widget build(BuildContext context) {
    return _AlertFact(
      icon: LucideIcons.package,
      color: facts.colors.solid,
      caption: AppLocalizations.of(context).alertsCardInStock,
      value: facts.quantity(facts.item.quantity),
      valueColor: facts.colors.foreground,
    );
  }
}

/// The minimum the stock should not fall under.
class _MinimumFact extends StatelessWidget {
  const _MinimumFact({required this.facts});

  final _AlertFacts facts;

  @override
  Widget build(BuildContext context) {
    return _AlertFact(
      icon: LucideIcons.gauge,
      color: AppColors.textSecondary,
      caption: AppLocalizations.of(context).alertsColumnMinimum,
      value: facts.quantity(facts.minimum),
      valueColor: AppColors.textPrimary,
    );
  }
}

/// How much a commande started from here would ask for.
class _ToOrderFact extends StatelessWidget {
  const _ToOrderFact({required this.facts});

  final _AlertFacts facts;

  @override
  Widget build(BuildContext context) {
    final amount = facts.toOrder;
    return _AlertFact(
      icon: LucideIcons.shoppingCart,
      color: facts.colors.solid,
      caption: AppLocalizations.of(context).alertsColumnToOrder,
      value: amount > 0 ? facts.quantity(amount) : '—',
      valueColor: facts.colors.foreground,
    );
  }
}

/// One fact: the icon in its round seat, the value, its caption under it.
class _AlertFact extends StatelessWidget {
  const _AlertFact({
    required this.icon,
    required this.color,
    required this.caption,
    required this.value,
    required this.valueColor,
  });

  final IconData icon;
  final Color color;
  final String caption;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final narrow = context.isPhone;
    final seat = narrow ? 28.0 : 36.0;

    return Row(
      children: [
        Container(
          width: seat,
          height: seat,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: narrow ? 14 : AppSizing.iconSm, color: color),
        ),
        SizedBox(width: narrow ? AppSpacing.xs + 2 : AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: AppTypography.numeric.copyWith(
                  fontSize: narrow ? 14 : 15,
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                caption,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The hairline between two facts.
class _FactRule extends StatelessWidget {
  const _FactRule({this.wide = false});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: wide ? AppSpacing.md : AppSpacing.sm,
      ),
      child: VerticalDivider(
        width: 1,
        thickness: 1,
        color: AppColors.border.withValues(alpha: 0.6),
      ),
    );
  }
}

/// What is already on its way, when something is. Only stock genuinely on
/// its way says so: silence means nothing is coming, which is the case that
/// needs a commande.
class _OnOrderLine extends StatelessWidget {
  const _OnOrderLine({required this.facts, this.dense = false});

  final _AlertFacts facts;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final onOrder = facts.view.onOrderQuantity;
    if (onOrder <= 0) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: dense ? AppSpacing.xs : AppSpacing.sm),
      child: Row(
        children: [
          const Icon(LucideIcons.truck, size: 12, color: AppColors.primary700),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              AppLocalizations.of(
                context,
              ).alertsOnOrder(facts.quantity(onOrder)),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: AppColors.primary700,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// The selection action bar.
// -----------------------------------------------------------------------------

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.alerts,
    required this.onClear,
    required this.onCreate,
  });

  final List<LowStockAlertView> alerts;
  final VoidCallback onClear;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final suppliers = groupBySupplier(alerts).length;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Both numbers, because they answer different questions: how much am
          // I ordering, and how many documents will that be.
          final summary = Text(
            l10n.alertsSelectionSummary(alerts.length, suppliers),
            style: theme.textTheme.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          );
          final clear = TextButton(
            onPressed: onClear,
            child: Text(l10n.alertsSelectionClear),
          );
          final create = PrimaryButton(
            label: l10n.alertsCreateOrders,
            shortLabel: l10n.shortCreateOrders,
            icon: LucideIcons.clipboardList,
            onPressed: alerts.isEmpty ? null : onCreate,
          );

          // A count, a cancel and a button do not fit a phone on one line, and
          // this bar sits over the content — an overflow here would cover a row
          // rather than push it down.
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                summary,
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(child: clear),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: create),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: summary),
              const SizedBox(width: AppSpacing.md),
              clear,
              const SizedBox(width: AppSpacing.sm),
              create,
            ],
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Which supplier to start a draft for.
// -----------------------------------------------------------------------------

class _SupplierGroupSheet extends StatelessWidget {
  const _SupplierGroupSheet({required this.grouped});

  /// Supplier id to what they would fill.
  final Map<String, ({String name, int count})> grouped;

  static Future<String?> show(
    BuildContext context,
    Map<String, ({String name, int count})> grouped,
  ) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _SupplierGroupSheet(grouped: grouped),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final entries = grouped.entries.toList()
      ..sort((a, b) => b.value.count.compareTo(a.value.count));

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.alertsCreateOrders, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.orderSupplierPromptBody, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.lg),

          if (entries.isEmpty)
            EmptyState(
              icon: LucideIcons.truck,
              title: l10n.itemNoSuppliersTitle,
              message: l10n.itemNoSuppliersBody,
            )
          else
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  onTap: () => Navigator.of(context).pop(entry.key),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.truck,
                        size: AppSizing.iconMd,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          entry.value.name,
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        l10n.ordersColumnLines(entry.value.count),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Icon(
                        LucideIcons.chevronRight,
                        size: AppSizing.iconSm,
                        color: AppColors.textDisabled,
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
