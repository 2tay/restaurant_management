import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/stock_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../data/providers.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../alerts_filter.dart';
import '../widgets/coverage_bar.dart';

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
    final filter = ref.watch(alertsFilterProvider);
    final selection = ref.watch(alertSelectionProvider);
    final shown = filter.apply(all);

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
          onPressed: acting.isEmpty ? null : () => _startOrders(context, acting),
        ),
      ],
      // Only while something is ticked. A bar that is always there costs a row
      // of content on a short screen to say nothing.
      footer: selection.isEmpty
          ? null
          : _SelectionBar(
              alerts: acting,
              onClear: ref.read(alertSelectionProvider.notifier).clear,
              onCreate: () => _startOrders(context, acting),
            ),
      child: AsyncContent<List<LowStockAlertView>>(
        value: asyncAlerts,
        onRetry: () => ref.invalidate(lowStockAlertsProvider(storeId)),
        builder: (context, _) => all.isEmpty
            ? EmptyState(
                icon: LucideIcons.circleCheck,
                title: l10n.alertsEmpty,
                message: l10n.alertsEmptyBody,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Summary(alerts: all, storeId: storeId),
                  const SizedBox(height: AppSpacing.lg),
                  _Filters(alerts: all, shown: shown.length),
                  const SizedBox(height: AppSpacing.md),
                  _Results(shown: shown, storeId: storeId, filter: filter),
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
    List<LowStockAlertView> alerts,
  ) async {
    final supplierId = await _SupplierGroupSheet.show(
      context,
      groupBySupplier(alerts),
    );
    if (supplierId == null || !context.mounted) return;

    // `prefill` tells the order form to add this supplier's low items straight
    // away, which is the whole point of arriving from here.
    context.pushScreen(
      '${Routes.toNewOrder(storeId)}?supplier=$supplierId&prefill=1',
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
// The summary row.
// -----------------------------------------------------------------------------

/// Four counts over the whole list — deliberately not over the filtered one.
///
/// The tiles are how the filter is applied, so they have to keep saying what
/// the establishment's situation is rather than what is left of it after the
/// last tap. A tile that counted its own result would read zero the moment you
/// used it.
class _Summary extends ConsumerWidget {
  const _Summary({required this.alerts, required this.storeId});

  final List<LowStockAlertView> alerts;
  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(alertsFilterProvider);
    final notifier = ref.read(alertsFilterProvider.notifier);

    var out = 0;
    var low = 0;
    var covered = 0;
    final suppliers = <String>{};
    for (final alert in alerts) {
      switch (stockStatusOf(alert.row.item)) {
        case StockStatus.outOfStock:
          out++;
        case StockStatus.lowStock:
          low++;
        case StockStatus.inStock:
          break;
      }
      if (alert.onOrderQuantity > 0) covered++;
      final supplierId = alert.defaultSupplierId;
      if (supplierId != null) suppliers.add(supplierId);
    }

    /// Tapping a tile that is already applied clears it, so the same tap that
    /// narrowed the list widens it again.
    void toggleSeverity(AlertSeverity value) => notifier.setSeverity(
      filter.severity == value ? AlertSeverity.all : value,
    );

    return StatTileRow(
      tiles: [
        StatTile(
          label: l10n.alertsKpiOutOfStock,
          value: '$out',
          icon: LucideIcons.circleX,
          accent: AppColors.outOfStock,
          selected: filter.severity == AlertSeverity.outOfStock,
          onTap: () => toggleSeverity(AlertSeverity.outOfStock),
        ),
        StatTile(
          label: l10n.alertsKpiLowStock,
          value: '$low',
          icon: LucideIcons.triangleAlert,
          accent: AppColors.lowStock,
          selected: filter.severity == AlertSeverity.lowStock,
          onTap: () => toggleSeverity(AlertSeverity.lowStock),
        ),
        StatTile(
          label: l10n.alertsKpiOnOrder,
          value: '$covered',
          icon: LucideIcons.truck,
          accent: AppColors.inStock,
          selected: filter.coverage == AlertCoverage.onOrder,
          onTap: () => notifier.setCoverage(
            filter.coverage == AlertCoverage.onOrder
                ? AlertCoverage.all
                : AlertCoverage.onOrder,
          ),
        ),
        StatTile(
          label: l10n.alertsKpiSuppliers,
          value: '${suppliers.length}',
          icon: LucideIcons.building2,
          // No filter behind this one: "four suppliers" is context, and there
          // is no single supplier for it to narrow to.
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Filters.
// -----------------------------------------------------------------------------

class _Filters extends ConsumerWidget {
  const _Filters({required this.alerts, required this.shown});

  final List<LowStockAlertView> alerts;

  /// How many rows the current filters leave.
  final int shown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(alertsFilterProvider);
    final notifier = ref.read(alertsFilterProvider.notifier);
    final viewMode = ref.watch(alertsViewModeProvider);

    // Only the suppliers who actually appear in the list. A menu offering every
    // supplier in the establishment would be mostly dead ends.
    final suppliers = <String, String>{};
    var hasUnsupplied = false;
    for (final alert in alerts) {
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
      FilterMenu<AlertSeverity>(
        label: l10n.alertsFilterSeverity,
        selectedLabel: switch (filter.severity) {
          AlertSeverity.all => null,
          AlertSeverity.outOfStock => l10n.alertsKpiOutOfStock,
          AlertSeverity.lowStock => l10n.alertsKpiLowStock,
        },
        entries: {
          AlertSeverity.all: l10n.alertsFilterAll,
          AlertSeverity.outOfStock: l10n.alertsKpiOutOfStock,
          AlertSeverity.lowStock: l10n.alertsKpiLowStock,
        },
        onSelected: notifier.setSeverity,
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
      FilterMenu<AlertSort>(
        label: l10n.alertsFilterSort,
        selectedLabel: switch (filter.sort) {
          // Urgency is the default, so naming it would put a pill on screen
          // saying nothing had been chosen.
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
      ),
    ];

    final count = Text(
      l10n.alertsCount(shown),
      style: Theme.of(context).textTheme.bodySmall,
    );

    // Four controls and a count stack into five rows on a phone. They move
    // behind one button there and stay on screen on a tablet — the same bargain
    // the inventory and orders lists make.
    if (context.isPhone) {
      return Row(
        children: [
          FilterSheetButton(
            activeCount: filter.activeFilterCount,
            onPressed: () => FilterSheet.show(
              context,
              onClear: filter.hasActiveFilters ? notifier.clear : null,
              builder: (context) => Consumer(
                builder: (context, ref, _) {
                  // Watched, not captured: the pills inside the sheet have to
                  // follow the taps made on them.
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
          const SizedBox(width: AppSpacing.md),
          Expanded(child: count),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...controls,
                  if (filter.hasActiveFilters)
                    TextButton.icon(
                      onPressed: notifier.clear,
                      icon: const Icon(LucideIcons.x, size: AppSizing.iconSm),
                      label: Text(l10n.inventoryClearFilters),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            ViewModeToggle<AlertsViewMode>(
              value: viewMode,
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
        ),
        const SizedBox(height: AppSpacing.md),
        count,
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// The list.
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

    if (shown.isEmpty) {
      return EmptyState.noResults(
        l10n,
        onClearFilters: ref.read(alertsFilterProvider.notifier).clear,
      );
    }

    if (ref.watch(alertsViewModeProvider) == AlertsViewMode.table &&
        !context.isPhone) {
      return _AlertsTable(alerts: shown, storeId: storeId);
    }

    // Grouped by severity only in the default order. A list the user has asked
    // to sort by name, still cut into two blocks, is not sorted by name.
    final grouped =
        filter.sort == AlertSort.urgency && filter.severity == AlertSeverity.all;
    if (!grouped) return _AlertList(alerts: shown, storeId: storeId);

    final out = shown
        .where((v) => stockStatusOf(v.row.item) == StockStatus.outOfStock)
        .toList();
    final low = shown
        .where((v) => stockStatusOf(v.row.item) == StockStatus.lowStock)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (out.isNotEmpty) ...[
          _SectionBlock(
            title: l10n.alertsKpiOutOfStock,
            alerts: out,
            storeId: storeId,
          ),
          if (low.isNotEmpty) const SizedBox(height: AppSpacing.xl),
        ],
        if (low.isNotEmpty)
          _SectionBlock(
            title: l10n.alertsKpiLowStock,
            alerts: low,
            storeId: storeId,
          ),
      ],
    );
  }
}

/// One severity block: a header that counts it and selects it wholesale, then
/// its rows.
class _SectionBlock extends ConsumerWidget {
  const _SectionBlock({
    required this.title,
    required this.alerts,
    required this.storeId,
  });

  final String title;
  final List<LowStockAlertView> alerts;
  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selection = ref.watch(alertSelectionProvider);
    final notifier = ref.read(alertSelectionProvider.notifier);
    final ids = alerts.map((v) => v.row.item.id).toList();
    final allSelected = ids.every(selection.contains);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: title,
          count: alerts.length,
          trailing: TextButton.icon(
            onPressed: () =>
                allSelected ? notifier.removeAll(ids) : notifier.addAll(ids),
            icon: Icon(
              allSelected ? LucideIcons.squareMinus : LucideIcons.squareCheck,
              size: AppSizing.iconSm,
            ),
            label: Text(l10n.alertsSelectAll),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _AlertList(alerts: alerts, storeId: storeId),
      ],
    );
  }
}

class _AlertList extends StatelessWidget {
  const _AlertList({required this.alerts, required this.storeId});

  final List<LowStockAlertView> alerts;
  final String storeId;

  @override
  Widget build(BuildContext context) {
    // Part of the page: the whole page scrolls, title included.
    return ListView.separated(
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: alerts.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) =>
          _AlertCard(view: alerts[index], storeId: storeId),
    );
  }
}

// -----------------------------------------------------------------------------
// One row.
// -----------------------------------------------------------------------------

class _AlertCard extends ConsumerWidget {
  const _AlertCard({required this.view, required this.storeId});

  final LowStockAlertView view;
  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final item = view.row.item;
    final status = stockStatusOf(item);
    final colors = StockStatusBadge.colorsFor(status);
    final unit = view.row.unitAbbreviation;
    final shortfall = item.lowStockThreshold - item.quantity;
    final supplierId = view.defaultSupplierId;
    final supplierName = view.defaultSupplierName;
    final selected = ref.watch(alertSelectionProvider).contains(item.id);

    final checkbox = Checkbox(
      value: selected,
      onChanged: (_) =>
          ref.read(alertSelectionProvider.notifier).toggle(item.id),
    );

    final nameBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.name,
          style: theme.textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          // Category and supplier on one line: two facts that place the
          // article, neither of which deserves a line of its own.
          supplierName == null
              ? view.row.categoryName
              : '${view.row.categoryName} · $supplierName',
          style: theme.textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    final quantityBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.alertsLevel(
            Formatters.quantityWithUnit(item.quantity, unit),
            Formatters.quantityWithUnit(item.lowStockThreshold, unit),
          ),
          style: AppTypography.numeric.copyWith(
            color: colors.foreground,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs),
        CoverageBar(
          quantity: item.quantity,
          onOrder: view.onOrderQuantity,
          threshold: item.lowStockThreshold,
          color: colors.solid,
        ),
        if (shortfall > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.alertsShortfall(Formatters.quantityWithUnit(shortfall, unit)),
            style: theme.textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );

    // The row's whole reason for existing after Phase 1.6: "low, and somebody
    // has already dealt with it" has to look different from "low, and nobody
    // has".
    final onOrderPill = view.onOrderQuantity > 0
        ? StatusPill(
            label: l10n.alertsOnOrder(
              Formatters.quantityWithUnit(view.onOrderQuantity, unit),
            ),
            colors: AppColors.inStock,
            icon: LucideIcons.truck,
          )
        : StatusPill(
            label: l10n.alertsNothingOnOrder,
            colors: AppColors.lowStock,
            icon: LucideIcons.circleAlert,
          );

    final orderButton = supplierId == null || supplierName == null
        ? null
        : SecondaryButton(
            label: l10n.alertsOrderFrom(supplierName),
            icon: LucideIcons.truck,
            onPressed: () => context.pushScreen(
              '${Routes.toNewOrder(storeId)}?supplier=$supplierId&prefill=1',
            ),
          );

    return AppCard(
      onTap: () => context.pushScreen(Routes.toItem(storeId, item.id)),
      accentColor: colors.solid,
      selected: selected,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Five columns — name, level, on-order, status, action — plus French
          // labels do not fit a tablet held in portrait. Squeezing them crushes
          // the action button below the width of its own icon, so below this
          // the card becomes three stacked rows instead.
          // On a phone at large text even two things a line do not fit — the
          // badge alone is wider than half the card — so everything takes a
          // line of its own, badge first.
          if (constraints.maxWidth < 480 && context.isLargeText) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    checkbox,
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: StockStatusBadge(status: status),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                nameBlock,
                const SizedBox(height: AppSpacing.md),
                quantityBlock,
                const SizedBox(height: AppSpacing.sm),
                Align(alignment: Alignment.centerLeft, child: onOrderPill),
                if (orderButton != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Align(alignment: Alignment.centerLeft, child: orderButton),
                ],
              ],
            );
          }

          if (constraints.maxWidth < 900) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The checkbox costs this line a full tap target, which is what
                // the status badge used to sit in. The badge moves down beside
                // the on-order pill rather than the checkbox being shrunk below
                // 48dp — a tick box nobody can hit is worse than a badge one
                // line lower.
                Row(
                  children: [
                    checkbox,
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: nameBlock),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                quantityBlock,
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [StockStatusBadge(status: status), onOrderPill],
                ),
                // The button takes a line of its own: beside anything it cannot
                // shrink past its own label, and "Commander chez Grossiste
                // Central" is most of a phone's width on its own.
                if (orderButton != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Align(alignment: Alignment.centerLeft, child: orderButton),
                ],
              ],
            );
          }

          return Row(
            children: [
              checkbox,
              const SizedBox(width: AppSpacing.xs),
              Expanded(flex: 4, child: nameBlock),
              const SizedBox(width: AppSpacing.md),
              Expanded(flex: 4, child: quantityBlock),
              const SizedBox(width: AppSpacing.md),
              Expanded(flex: 3, child: onOrderPill),
              const SizedBox(width: AppSpacing.md),
              StockStatusBadge(status: status),
              const SizedBox(width: AppSpacing.md),
              if (orderButton != null) Flexible(flex: 3, child: orderButton),
            ],
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Table view.
// -----------------------------------------------------------------------------

class _AlertsTable extends StatelessWidget {
  const _AlertsTable({required this.alerts, required this.storeId});

  final List<LowStockAlertView> alerts;
  final String storeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    String quantity(LowStockAlertView v, double value) =>
        Formatters.quantityWithUnit(value, v.row.unitAbbreviation);

    return AppTable<LowStockAlertView>(
      rows: alerts,
      shrinkWrap: true,
      onRowTap: (v) => context.pushScreen(Routes.toItem(storeId, v.row.item.id)),
      rowAccent: (v) =>
          StockStatusBadge.colorsFor(stockStatusOf(v.row.item)).solid,
      columns: [
        AppTableColumn(label: l10n.alertsColumnItem, flex: 4),
        AppTableColumn(label: l10n.alertsColumnStock, flex: 2, numeric: true),
        // The threshold and the shortfall say the same thing twice on a narrow
        // table. The shortfall is the one that answers "how much do I order",
        // so the threshold is what goes when there is no room.
        AppTableColumn(
          label: l10n.alertsColumnThreshold,
          flex: 2,
          numeric: true,
          minTableWidth: 900,
        ),
        AppTableColumn(
          label: l10n.alertsColumnShortfall,
          flex: 2,
          numeric: true,
        ),
        AppTableColumn(
          label: l10n.alertsColumnOnOrder,
          flex: 2,
          numeric: true,
          minTableWidth: 760,
        ),
        AppTableColumn(label: l10n.alertsColumnStatus, width: 140),
      ],
      cell: (context, v, column) {
        final item = v.row.item;
        final gap = item.lowStockThreshold - item.quantity;
        return switch (column) {
          0 => Text(
            item.name,
            style: theme.textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          1 => Text(
            quantity(v, item.quantity),
            style: AppTypography.numeric.copyWith(
              color: StockStatusBadge.colorsFor(
                stockStatusOf(item),
              ).foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
          2 => Text(
            quantity(v, item.lowStockThreshold),
            style: AppTypography.numeric,
          ),
          3 => Text(
            gap > 0 ? quantity(v, gap) : '—',
            style: AppTypography.numeric,
          ),
          4 => Text(
            v.onOrderQuantity > 0 ? quantity(v, v.onOrderQuantity) : '—',
            style: AppTypography.numeric,
          ),
          _ => StockStatusBadge(status: stockStatusOf(item)),
        };
      },
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
