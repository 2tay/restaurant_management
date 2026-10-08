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
/// many suppliers it would take to fix. Each of those counts is a filter, so
/// the summary is also the way in.
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
    final busyAll =
        ref.watch(busyAlertsProvider(storeId)).value ??
        const <LowStockAlertView>[];
    final warning = ref.watch(busyWarningProvider(storeId));
    final filter = ref.watch(alertsFilterProvider);
    final selection = ref.watch(alertSelectionProvider);
    final busy = filter.severity == AlertSeverity.busy;
    final shown = filter.apply(busy ? busyAll : all);

    // What the buttons act on: the ticked rows, or — when nothing is ticked —
    // everything currently on screen. "Create the orders" with an empty
    // selection should do the obvious thing rather than nothing.
    final acting = selection.isEmpty
        ? shown
        : shown.where((v) => selection.contains(v.row.item.id)).toList();

    return ShellPage(
      tabs: SectionTabs(
        currentPath: Routes.toAlerts(storeId),
        tabs: [
          SectionTab(label: l10n.alertsTitle, path: Routes.toAlerts(storeId)),
          SectionTab(
            label: l10n.notificationsTitle,
            path: Routes.toNotifications(storeId),
          ),
        ],
      ),
      title: l10n.alertsTitle,
      subtitle: l10n.alertsSubtitle,
      actions: [
        SecondaryButton(
          label: l10n.actionAddDelivery,
          shortLabel: l10n.shortAddDelivery,
          icon: LucideIcons.arrowDownToLine,
          onPressed: () => context.pushScreen(Routes.toStockIn(storeId)),
        ),
        PrimaryButton(
          label: l10n.alertsCreateOrders,
          shortLabel: l10n.shortCreateOrders,
          icon: LucideIcons.clipboardList,
          onPressed: acting.isEmpty
              ? null
              : () => _startOrders(context, acting, busy: busy),
        ),
      ],
      // Only while something is ticked. A bar that is always there costs a row
      // of content on a short screen to say nothing.
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
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (warning != null) ...[
              _BusyBanner(
                period: warning,
                shortCount: busyAll.length,
                // No "see the list" on the list itself.
                onShowList: busy
                    ? null
                    : () => ref
                          .read(alertsFilterProvider.notifier)
                          .setSeverity(AlertSeverity.busy),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            _Summary(alerts: all, storeId: storeId),
            const SizedBox(height: AppSpacing.xl),
            if (all.isEmpty && busyAll.isEmpty)
              EmptyState(
                icon: LucideIcons.packageCheck,
                title: l10n.alertsEmpty,
                message: l10n.alertsEmptyBody,
              )
            else ...[
              _Toolbar(alerts: all, busyAlerts: busyAll),
              const SizedBox(height: AppSpacing.lg),
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

/// Four counts above the list: how many need something, how many are out, how
/// many are low, how many are fine.
///
/// It replaces nothing the list does not also say — it says it in two seconds.
/// The first three are filters as well: tapping one shows those rows. "Stock
/// OK" is the reassurance that the other three are the whole problem, and it
/// counts the catalogue rather than the alerts, since the alerts by definition
/// hold none of them.
class _Summary extends ConsumerWidget {
  const _Summary({required this.alerts, required this.storeId});

  /// Every alert, before any filtering.
  final List<LowStockAlertView> alerts;
  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(alertsFilterProvider.notifier);
    final items =
        ref.watch(itemsByNameProvider(storeId)).value ?? const <Item>[];

    final out = alerts
        .where((v) => stockStatusOf(v.row.item) == StockStatus.outOfStock)
        .length;
    final low = alerts.length - out;
    final ok = items
        .where((i) => stockStatusOf(i) == StockStatus.inStock)
        .length;

    void show(AlertSeverity severity) => notifier.setSeverity(severity);

    return StatTileRow(
      spacing: AppSpacing.md,
      tiles: [
        StatTile(
          value: '${alerts.length}',
          label: l10n.alertsSummaryAlerts,
          caption: l10n.alertsSummaryAlertsCaption,
          icon: LucideIcons.triangleAlert,
          onTap: () => show(AlertSeverity.all),
        ),
        StatTile(
          value: '$out',
          label: l10n.alertsSeverityOutOfStock,
          caption: l10n.alertsSummaryOutCaption,
          icon: StockStatusBadge.iconFor(StockStatus.outOfStock),
          // Tinted only when there is something to see. A red zero is an
          // alarm about nothing.
          accent: out > 0 ? AppColors.outOfStock : null,
          onTap: () => show(AlertSeverity.outOfStock),
        ),
        StatTile(
          value: '$low',
          label: l10n.alertsSeverityLowStock,
          caption: l10n.alertsSummaryLowCaption,
          icon: StockStatusBadge.iconFor(StockStatus.lowStock),
          accent: low > 0 ? AppColors.lowStock : null,
          onTap: () => show(AlertSeverity.lowStock),
        ),
        StatTile(
          value: '$ok',
          label: l10n.alertsSummaryOk,
          caption: l10n.alertsSummaryOkCaption,
          icon: StockStatusBadge.iconFor(StockStatus.inStock),
          accent: AppColors.inStock,
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// The toolbar.
// -----------------------------------------------------------------------------

/// Severity tabs, search, the two narrowing menus, sort and view mode.
///
/// Each tab carries the number tapping it would show — counted with the
/// *other* filters applied, so "Ruptures 3" means three after the supplier,
/// coverage and search narrowing, not three in the abstract.
///
/// Wide, everything shares one line; the tabs scroll rather than wrap so a long
/// supplier name picked in a menu never reflows the row. Narrower, the search
/// and the view controls take a line above the tabs. On a phone the search is
/// full width, the two menus go behind one filter button, and the tabs scroll
/// sideways with the sort pinned at the end.
class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.alerts, required this.busyAlerts});

  /// Every alert, before any filtering.
  final List<LowStockAlertView> alerts;

  /// Every product under its busy-day minimum, before any filtering.
  final List<LowStockAlertView> busyAlerts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(alertsFilterProvider);
    final notifier = ref.read(alertsFilterProvider.notifier);
    final phone = context.isPhone;

    // Counted with everything except severity applied, so each tab says how
    // many rows tapping it would leave.
    final base = filter.copyWith(severity: AlertSeverity.all).apply(alerts);
    var out = 0;
    for (final alert in base) {
      if (stockStatusOf(alert.row.item) == StockStatus.outOfStock) out++;
    }

    final tabs = Row(
      children: [
        for (final (i, (value, label, count)) in <(AlertSeverity, String, int)>[
          (AlertSeverity.all, l10n.alertsTabAll, base.length),
          (AlertSeverity.outOfStock, l10n.alertsSeverityOutOfStock, out),
          (
            AlertSeverity.lowStock,
            l10n.alertsSeverityLowStock,
            base.length - out,
          ),
          (
            AlertSeverity.busy,
            l10n.alertsBusyTab,
            filter
                .copyWith(severity: AlertSeverity.busy)
                .apply(busyAlerts)
                .length,
          ),
        ].indexed) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          _SeverityTab(
            label: label,
            count: count,
            selected: value == filter.severity,
            onTap: () => notifier.setSeverity(value),
          ),
        ],
      ],
    );

    // Only the suppliers who actually appear. A menu offering every supplier in
    // the establishment would be mostly dead ends.
    final suppliers = <String, String>{};
    var hasUnsupplied = false;
    final current = filter.severity == AlertSeverity.busy ? busyAlerts : alerts;
    for (final alert in current) {
      final id = alert.defaultSupplierId;
      if (id == null) {
        hasUnsupplied = true;
        continue;
      }
      suppliers[id] = alert.defaultSupplierName ?? '—';
    }

    String? supplierLabel() {
      if (filter.supplierId == null) return null;
      if (filter.supplierId == AlertsFilter.noSupplier) {
        return l10n.alertsNoSupplier;
      }
      return suppliers[filter.supplierId];
    }

    final controls = <Widget>[
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
      if (suppliers.isNotEmpty || hasUnsupplied)
        FilterMenu<String>(
          label: l10n.alertsFilterSupplier,
          selectedLabel: supplierLabel(),
          entries: {
            '': l10n.alertsFilterAllSuppliers,
            for (final entry in suppliers.entries) entry.key: entry.value,
            if (hasUnsupplied) AlertsFilter.noSupplier: l10n.alertsNoSupplier,
          },
          onSelected: (id) => notifier.setSupplier(id.isEmpty ? null : id),
        ),
    ];

    // Sorting reorders and never hides, so it is not counted among the filters
    // and not cleared with them.
    final sort = FilterMenu<AlertSort>(
      label: l10n.alertsFilterSort,
      selectedLabel: switch (filter.sort) {
        // Urgency is the default: naming it would put a pill on screen saying
        // nothing had been chosen.
        AlertSort.urgency => null,
        AlertSort.shortfall => l10n.alertsSortShortfall,
        AlertSort.name => l10n.alertsSortName,
      },
      entries: {
        AlertSort.urgency: l10n.alertsSortUrgency,
        AlertSort.shortfall: l10n.alertsSortShortfall,
        AlertSort.name: l10n.alertsSortName,
      },
      onSelected: notifier.setSort,
    );

    final search = SearchField(
      hint: l10n.alertsSearchHint,
      initialValue: filter.query,
      onChanged: notifier.setQuery,
      maxWidth: phone ? double.infinity : AppSizing.filterFieldWidth + 60,
    );

    if (phone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: AppSpacing.sm),
              FilterSheetButton(
                compact: true,
                activeCount: filter.activeFilterCount,
                onPressed: () => FilterSheet.show(
                  context,
                  onClear: filter.hasActiveFilters ? notifier.clear : null,
                  builder: (context) => Consumer(
                    builder: (context, ref, _) {
                      // Watched, not captured: the pills inside the sheet have
                      // to follow the taps made on them.
                      ref.watch(alertsFilterProvider);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (i, control) in controls.indexed) ...[
                            if (i > 0) const SizedBox(height: AppSpacing.md),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: control,
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: tabs,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              sort,
            ],
          ),
        ],
      );
    }

    final narrowing = <Widget>[
      for (final (i, control) in controls.indexed) ...[
        if (i > 0) const SizedBox(width: AppSpacing.xs),
        control,
      ],
      if (filter.hasActiveFilters)
        IconButton(
          onPressed: notifier.clear,
          tooltip: l10n.inventoryClearFilters,
          visualDensity: VisualDensity.compact,
          icon: const Icon(LucideIcons.x, size: AppSizing.iconSm),
        ),
    ];

    final viewToggle = ViewModeToggle<AlertsViewMode>(
      value: ref.watch(alertsViewModeProvider),
      onSelected: ref.read(alertsViewModeProvider.notifier).select,
      options: [
        ViewModeOption(
          value: AlertsViewMode.table,
          icon: LucideIcons.list,
          label: l10n.movementsViewList,
        ),
        ViewModeOption(
          value: AlertsViewMode.grid,
          icon: LucideIcons.layoutGrid,
          label: l10n.viewModeGrid,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final scrollingTabs = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              tabs,
              const SizedBox(width: AppSpacing.md),
              const _ToolbarDivider(),
              const SizedBox(width: AppSpacing.md),
              ...narrowing,
            ],
          ),
        );

        // One line when the search can sit beside the tabs at a useful width.
        if (constraints.maxWidth >= 1180) {
          return Row(
            children: [
              Expanded(child: scrollingTabs),
              const SizedBox(width: AppSpacing.md),
              SizedBox(width: AppSizing.filterFieldWidth + 20, child: search),
              const SizedBox(width: AppSpacing.sm),
              sort,
              const SizedBox(width: AppSpacing.sm),
              viewToggle,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: AppSpacing.sm),
                sort,
                const SizedBox(width: AppSpacing.sm),
                viewToggle,
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            scrollingTabs,
          ],
        );
      },
    );
  }
}

/// Separates what picks the rows from what narrows them.
class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: AppSizing.iconLg, color: AppColors.hairline);
}

/// One severity tab: a word, and the count tapping it would leave.
///
/// A soft rectangle rather than a pill: four of them in a row read as one
/// segmented choice, and the selected one is filled in the brand teal so it
/// is the first thing the eye lands on in the toolbar.
class _SeverityTab extends StatelessWidget {
  const _SeverityTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected ? AppColors.white : AppColors.textPrimary;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.smAll,
        child: AnimatedContainer(
          duration: AppMotion.duration(context, AppMotion.fast),
          constraints: BoxConstraints(
            minHeight: context.isPhone
                ? AppSizing.minTapTarget - 4
                : AppSizing.toolbarControlHeight,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary600 : AppColors.surface,
            borderRadius: AppRadius.smAll,
            border: Border.all(
              color: selected ? AppColors.primary600 : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(color: foreground),
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Text(
                '$count',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? AppColors.white.withValues(alpha: 0.85)
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
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

    if (shown.isEmpty) {
      // Nothing narrowing the list: it is genuinely empty, which is good news
      // rather than a filter to clear.
      final narrowed =
          filter.coverage != AlertCoverage.all ||
          filter.supplierId != null ||
          filter.query.trim().isNotEmpty;
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

    // The order is the query's — worst first — or the one the user picked.
    // Ruptures carry a red edge in every view, so they stand out without the
    // list being cut into sections.
    final wantsTable =
        !context.isPhone &&
        ref.watch(alertsViewModeProvider) == AlertsViewMode.table;

    final cards = [
      for (final view in shown)
        _AlertCard(view: view, storeId: storeId, busy: busy),
    ];

    // The table's fixed columns — checkbox, status, actions — take 400dp
    // before the product gets any, so below [_tableMinWidth] (a small tablet
    // in portrait, or a large text size) the cards stand in for it rather
    // than a product name squeezed to nothing.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (wantsTable && constraints.maxWidth >= _tableMinWidth) {
          return _AlertsTable(alerts: shown, storeId: storeId, busy: busy);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CardListHeader(alerts: shown),
            const SizedBox(height: AppSpacing.sm),
            if (context.isPhone)
              for (final (i, card) in cards.indexed) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                card,
              ]
            else
              ResponsiveCardGrid(minCardWidth: 300, children: cards),
          ],
        );
      },
    );
  }
}

/// The narrowest content width the alerts table is drawn at.
const double _tableMinWidth = 760;

/// Above the cards: select everything shown, and how many that is. The table
/// has the same checkbox in its header.
class _CardListHeader extends ConsumerWidget {
  const _CardListHeader({required this.alerts});

  final List<LowStockAlertView> alerts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Row(
      children: [
        _SelectAllCheckbox(alerts: alerts),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            l10n.alertsSelectAll,
            style: theme.textTheme.labelLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          l10n.inventoryCount(alerts.length),
          style: theme.textTheme.bodySmall,
        ),
      ],
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

/// What one alert row says, worked out once for the table and the card alike.
class _AlertFacts {
  _AlertFacts(this.view, {required this.busy});

  final LowStockAlertView view;

  /// Measured against the busy-day minimum rather than the ordinary one.
  final bool busy;

  Item get item => view.row.item;
  String get unit => view.row.unitAbbreviation;
  StockStatus get status => stockStatusOf(item);
  double get minimum => busy ? holidayMinimumOf(item) : item.lowStockThreshold;
  double get shortfall => minimum - item.quantity;

  String quantity(double value) => Formatters.quantityWithUnit(value, unit);

  /// Only the articles at zero are edged, so the eye can find them down a
  /// column of otherwise identical rows. An edge on every row would stop
  /// meaning "look here".
  Color? get accent => status == StockStatus.outOfStock
      ? StockStatusBadge.colorsFor(StockStatus.outOfStock).solid
      : null;
}

/// The figure, then a slim bar under it.
class _StockLevel extends StatelessWidget {
  const _StockLevel({required this.facts, this.showFigure = true});

  final _AlertFacts facts;
  final bool showFigure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final view = facts.view;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showFigure) ...[
          Text(
            facts.quantity(facts.item.quantity),
            // Weight, not colour: the badge beside it carries the alarm.
            style: AppTypography.numeric.copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs + 2),
        ],
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
          Text(
            l10n.alertsOnOrder(facts.quantity(view.onOrderQuantity)),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.primary700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

/// The badge, and what is missing in two words under it.
class _StatusBlock extends StatelessWidget {
  const _StatusBlock({required this.facts, this.inline = false});

  final _AlertFacts facts;

  /// The note beside the badge rather than under it — the phone card.
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = facts.status;

    // The shared colours, icon and words for a status — so colour is never
    // alone — in a squarer shape that sits better in a dense table.
    final badge = StatusPill(
      colors: StockStatusBadge.colorsFor(status),
      icon: StockStatusBadge.iconFor(status),
      label: StockStatusBadge.labelFor(l10n, status),
      borderRadius: AppRadius.smAll,
    );
    final note = Text(
      facts.shortfall > 0
          ? l10n.alertsShortfall(facts.quantity(facts.shortfall))
          : l10n.alertsNothingToReport,
      style: theme.textTheme.bodySmall,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    if (inline) {
      // Both give way on a narrow card: the pill ellipsizes its label
      // rather than pushing the note off the edge.
      return Row(
        children: [
          Flexible(child: badge),
          const SizedBox(width: AppSpacing.sm),
          Flexible(child: note),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        badge,
        const SizedBox(height: AppSpacing.xs),
        note,
      ],
    );
  }
}

/// The row's checkbox.
class _RowCheckbox extends ConsumerWidget {
  const _RowCheckbox({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(alertSelectionProvider).contains(item.id);
    return Checkbox(
      value: selected,
      semanticLabel: item.name,
      visualDensity: VisualDensity.compact,
      onChanged: (_) =>
          ref.read(alertSelectionProvider.notifier).toggle(item.id),
    );
  }
}

/// Starts a commande with this row's supplier, the low items already on it.
/// Compact: it sits on every row.
class _OrderButton extends StatelessWidget {
  const _OrderButton({
    required this.storeId,
    required this.supplierId,
    required this.busy,
  });

  final String storeId;
  final String supplierId;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OutlinedButton.icon(
      onPressed: () =>
          context.pushScreen(_orderPath(storeId, supplierId, busy)),
      icon: const Icon(LucideIcons.truck, size: AppSizing.iconSm),
      // Ellipsizes rather than overflows when the actions column or the card
      // leaves it less than its natural width.
      label: Text(
        l10n.alertsOrder,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: Size(
          0,
          context.isPhone
              ? AppSizing.minTapTarget - 4
              : AppSizing.toolbarControlHeight,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        foregroundColor: AppColors.primary700,
        side: const BorderSide(color: AppColors.border),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      ),
    );
  }
}

String _orderPath(String storeId, String supplierId, bool busy) =>
    '${Routes.toNewOrder(storeId)}?supplier=$supplierId'
    '&prefill=${busy ? 'busy' : '1'}';

enum _RowAction { open, order, delivery }

/// The ⋮ on each row: the product's panel, the commande, a delivery.
class _RowMenu extends StatelessWidget {
  const _RowMenu({required this.facts, required this.storeId});

  final _AlertFacts facts;
  final String storeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final supplierId = facts.view.defaultSupplierId;

    return PopupMenuButton<_RowAction>(
      tooltip: l10n.itemMoreActions,
      icon: const Icon(LucideIcons.ellipsisVertical, size: AppSizing.iconSm),
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      position: PopupMenuPosition.under,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      onSelected: (action) => switch (action) {
        _RowAction.open => openProductDrawer(
          context,
          storeId: storeId,
          itemId: facts.item.id,
        ),
        _RowAction.order => context.pushScreen(
          _orderPath(storeId, supplierId!, facts.busy),
        ),
        _RowAction.delivery => context.pushScreen(Routes.toStockIn(storeId)),
      },
      itemBuilder: (context) => [
        _menuItem(
          _RowAction.open,
          LucideIcons.packageSearch,
          l10n.alertsOpenProduct,
        ),
        if (supplierId != null)
          _menuItem(_RowAction.order, LucideIcons.truck, l10n.alertsOrder),
        _menuItem(
          _RowAction.delivery,
          LucideIcons.arrowDownToLine,
          l10n.actionAddDelivery,
        ),
      ],
    );
  }

  PopupMenuItem<_RowAction> _menuItem(
    _RowAction value,
    IconData icon,
    String label,
  ) => PopupMenuItem(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: AppSizing.iconSm, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.md),
        Text(label),
      ],
    ),
  );
}

/// The photo, the name, and the category and supplier in one muted line.
class _ProductIdentity extends StatelessWidget {
  const _ProductIdentity({
    required this.facts,
    this.thumbnail = 40,
    this.nameLines = 1,
  });

  final _AlertFacts facts;
  final double thumbnail;
  final int nameLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final view = facts.view;
    final supplierName = view.defaultSupplierName;

    return Row(
      children: [
        ProductImage(
          imagePath: facts.item.imagePath,
          size: thumbnail,
          radius: AppRadius.sm,
          placeholder: ProductImagePlaceholder.disc,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                facts.item.name,
                style: theme.textTheme.titleSmall,
                maxLines: nameLines,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                supplierName == null
                    ? view.row.categoryName
                    : '${view.row.categoryName} · $supplierName',
                style: theme.textTheme.bodySmall,
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

/// One aligned line per product: who, how much, against what, how bad, and
/// what to do.
///
/// On a tablet the unit goes first (the quantities already carry it), then
/// the minimum (the status note says how far under it the row is), so the
/// four columns that decide the row are always there.
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
    final theme = Theme.of(context);
    final selection = ref.watch(alertSelectionProvider);

    return AppTable<LowStockAlertView>(
      rows: alerts,
      shrinkWrap: true,
      rowHeight: 72,
      onRowTap: (v) =>
          openProductDrawer(context, storeId: storeId, itemId: v.row.item.id),
      isSelected: (v) => selection.contains(v.row.item.id),
      rowAccent: (v) => _AlertFacts(v, busy: busy).accent,
      columns: [
        AppTableColumn(
          label: l10n.alertsSelectAll,
          width: 52,
          header: _SelectAllCheckbox(alerts: alerts),
        ),
        AppTableColumn(label: l10n.alertsColumnItem, flex: 5),
        AppTableColumn(label: l10n.alertsColumnStock, flex: 3),
        AppTableColumn(
          label: l10n.alertsColumnThreshold,
          width: 136,
          minTableWidth: 860,
        ),
        AppTableColumn(
          label: l10n.itemUnitLabel,
          width: 76,
          minTableWidth: 1000,
        ),
        // Wide enough for « Rupture de stock » whole.
        AppTableColumn(label: l10n.alertsColumnStatus, width: 196),
        AppTableColumn(label: l10n.employeesColumnActions, width: 176),
      ],
      cell: (context, v, column) {
        final facts = _AlertFacts(v, busy: busy);
        final supplierId = v.defaultSupplierId;
        return switch (column) {
          0 => _RowCheckbox(item: facts.item),
          1 => _ProductIdentity(facts: facts),
          2 => ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: _StockLevel(facts: facts),
          ),
          3 => Text(
            facts.quantity(facts.minimum),
            style: AppTypography.numeric,
          ),
          4 => Text(facts.unit, style: theme.textTheme.bodyMedium),
          5 => _StatusBlock(facts: facts),
          _ => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (supplierId != null)
                Flexible(
                  child: _OrderButton(
                    storeId: storeId,
                    supplierId: supplierId,
                    busy: busy,
                  ),
                ),
              const SizedBox(width: AppSpacing.xs),
              _RowMenu(facts: facts, storeId: storeId),
            ],
          ),
        };
      },
    );
  }
}

// -----------------------------------------------------------------------------
// The card — phones always, and the grid view on a wide screen.
// -----------------------------------------------------------------------------

/// The same row as a card, laid out for one hand:
///
///     ☐ [photo] Carottes                    ⋮
///               Fruits et légumes
///     Stock actuel                       0 kg
///     Minimum                           50 kg
///     ▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭
///     (✕ Rupture de stock) Manque 50 kg   [Commander]
class _AlertCard extends ConsumerWidget {
  const _AlertCard({
    required this.view,
    required this.storeId,
    this.busy = false,
  });

  final LowStockAlertView view;
  final String storeId;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final facts = _AlertFacts(view, busy: busy);
    final selected = ref.watch(alertSelectionProvider).contains(facts.item.id);
    final supplierId = view.defaultSupplierId;

    // Label left, figure right. Both loose, so neither is handed half the
    // line it does not need — the figure sits against the right edge.
    Widget figure(String label, String value, {bool strong = false}) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            value,
            style: strong
                ? AppTypography.numeric.copyWith(fontWeight: FontWeight.w700)
                : AppTypography.numeric,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );

    final orderButton = supplierId == null
        ? null
        : _OrderButton(storeId: storeId, supplierId: supplierId, busy: busy);

    return AppCard(
      onTap: () =>
          openProductDrawer(context, storeId: storeId, itemId: facts.item.id),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.md,
      ),
      accentColor: facts.accent,
      selected: selected,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _RowCheckbox(item: facts.item),
              Expanded(
                child: _ProductIdentity(
                  facts: facts,
                  thumbnail: 36,
                  nameLines: 2,
                ),
              ),
              _RowMenu(facts: facts, storeId: storeId),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.sm),
                figure(
                  l10n.alertsColumnStock,
                  facts.quantity(facts.item.quantity),
                  strong: true,
                ),
                const SizedBox(height: AppSpacing.xxs),
                figure(l10n.alertsColumnMinimum, facts.quantity(facts.minimum)),
                const SizedBox(height: AppSpacing.sm),
                _StockLevel(facts: facts, showFigure: false),
                const SizedBox(height: AppSpacing.md),
                // The badge over its note, the button beside them: the badge
                // keeps its whole label. At large text, or on a very narrow
                // phone, the button goes under instead.
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (context.isLargeText || constraints.maxWidth < 280) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _StatusBlock(facts: facts, inline: true),
                          if (orderButton != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: orderButton,
                            ),
                          ],
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: _StatusBlock(facts: facts)),
                        if (orderButton != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(child: orderButton),
                        ],
                      ],
                    );
                  },
                ),
              ],
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

// -----------------------------------------------------------------------------
// The busy-day banner.
// -----------------------------------------------------------------------------

/// "Jours chargés demain": shown from the reminder day set on the calendar
/// until the busy period is over.
///
/// It says when, and how many products are short of their busy-day minimum,
/// and offers the list. The count is what makes it worth reading: zero turns
/// it into good news rather than hiding it, so the owner knows the reminder
/// ran and found nothing to buy.
class _BusyBanner extends ConsumerWidget {
  const _BusyBanner({
    required this.period,
    required this.shortCount,
    required this.onShowList,
  });

  final BusyPeriod period;
  final int shortCount;

  /// Null on the busy list itself.
  final VoidCallback? onShowList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final colors = shortCount > 0 ? AppColors.lowStock : AppColors.inStock;

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.alertsBusyBannerTitle(busyWhenLabel(l10n, today, period.start)),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 2),
        Text(
          l10n.alertsBusyBannerBody(
            shortCount,
            busyPeriodLabel(l10n, period, capitalized: true),
          ),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );

    final icon = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colors.container,
        shape: BoxShape.circle,
      ),
      child: Icon(
        LucideIcons.calendarClock,
        size: AppSizing.iconMd,
        color: colors.foreground,
      ),
    );

    final button = onShowList == null || shortCount == 0
        ? null
        : SecondaryButton(
            label: l10n.alertsBusyShow,
            icon: LucideIcons.list,
            onPressed: onShowList,
          );

    return AppCard(
      accentColor: colors.solid,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 520 || context.isLargeText) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    icon,
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: text),
                  ],
                ),
                if (button != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Align(alignment: Alignment.centerLeft, child: button),
                ],
              ],
            );
          }
          return Row(
            children: [
              icon,
              const SizedBox(width: AppSpacing.md),
              Expanded(child: text),
              if (button != null) ...[
                const SizedBox(width: AppSpacing.md),
                button,
              ],
            ],
          );
        },
      ),
    );
  }
}
