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
                  _Toolbar(alerts: all),
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
// The toolbar.
// -----------------------------------------------------------------------------

/// Severity, filters, sort and view mode — one row.
///
/// These were three stacked rows: a tab strip, a line of filter pills, and a
/// result count underneath. Between them they pushed the first article a third
/// of the way down a laptop screen to say things that fit on one line.
///
/// The count went first. Each tab already carries the number tapping it would
/// show — counted with the *other* filters applied, so "Ruptures 3" means three
/// after the supplier and coverage narrowing, not three in the abstract — which
/// made a separate "12 produits" a third telling of the same figure.
///
/// What is left reads left to right as what it does: which ones, narrowed how,
/// then ordered and drawn how, pushed to the far end.
class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.alerts});

  /// Every alert, before any filtering.
  final List<LowStockAlertView> alerts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(alertsFilterProvider);
    final notifier = ref.read(alertsFilterProvider.notifier);

    // Counted with everything except severity applied, so each tab says how
    // many rows tapping it would leave.
    final base = filter.copyWith(severity: AlertSeverity.all).apply(alerts);
    var out = 0;
    for (final alert in base) {
      if (stockStatusOf(alert.row.item) == StockStatus.outOfStock) out++;
    }

    final tabs = <Widget>[
      for (final (i, (value, label, count)) in <(AlertSeverity, String, int)>[
        (AlertSeverity.all, l10n.alertsFilterAll, base.length),
        (AlertSeverity.outOfStock, l10n.alertsSeverityOutOfStock, out),
        (AlertSeverity.lowStock, l10n.alertsSeverityLowStock, base.length - out),
      ].indexed) ...[
        if (i > 0) const SizedBox(width: AppSpacing.xs),
        _SeverityTab(
          label: label,
          count: count,
          selected: value == filter.severity,
          onTap: () => notifier.setSeverity(value),
        ),
      ],
    ];

    // Only the suppliers who actually appear. A menu offering every supplier in
    // the establishment would be mostly dead ends.
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
    // and not cleared with them — and it sits on the other side of the row.
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

    // On a phone the two filter menus go behind one button; the tabs and the
    // sort are what people reach for, and they stay on the row.
    final narrowing = context.isPhone
        ? <Widget>[
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
          ]
        : <Widget>[
            for (final control in controls) ...[
              control,
              const SizedBox(width: AppSpacing.xs),
            ],
            if (filter.hasActiveFilters)
              IconButton(
                onPressed: notifier.clear,
                tooltip: l10n.inventoryClearFilters,
                visualDensity: VisualDensity.compact,
                icon: const Icon(LucideIcons.x, size: AppSizing.iconSm),
              ),
          ];

    return Row(
      children: [
        // The row scrolls rather than wrapping: a toolbar that reflows onto a
        // second line when a long supplier name is picked moves everything
        // under it, which is worse than having to swipe it.
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...tabs,
                const SizedBox(width: AppSpacing.md),
                const _ToolbarDivider(),
                const SizedBox(width: AppSpacing.md),
                ...narrowing,
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        sort,
        if (!context.isPhone) ...[
          const SizedBox(width: AppSpacing.xs),
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
      ],
    );
  }
}

/// Separates what picks the rows from what narrows them.
class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: AppSizing.iconLg,
    color: AppColors.hairline,
  );
}

/// One severity tab: a word, and the count tapping it would leave.
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

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillAll,
        child: AnimatedContainer(
          duration: AppMotion.duration(context, AppMotion.fast),
          constraints: const BoxConstraints(minHeight: AppSizing.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            // Teal marks the selection and nothing else here. The severities
            // keep their own colours down in the rows, where they belong to an
            // article rather than to a control.
            color: selected ? AppColors.primaryContainer : AppColors.surface,
            borderRadius: AppRadius.pillAll,
            border: Border.all(
              color: selected ? AppColors.primary600 : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected
                      ? AppColors.onPrimaryContainer
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$count',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? AppColors.onPrimaryContainer
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
            title: l10n.alertsSeverityOutOfStock,
            alerts: out,
            storeId: storeId,
          ),
          if (low.isNotEmpty) const SizedBox(height: AppSpacing.xl),
        ],
        if (low.isNotEmpty)
          _SectionBlock(
            title: l10n.alertsSeverityLowStock,
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
          // An icon, not a labelled button: "Tout sélectionner" beside every
          // section heading is the same three words twice on one screen, and
          // the heading it sits on already says what "tout" covers.
          trailing: IconButton(
            onPressed: () =>
                allSelected ? notifier.removeAll(ids) : notifier.addAll(ids),
            tooltip: l10n.alertsSelectAll,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              allSelected ? LucideIcons.squareMinus : LucideIcons.squareCheck,
              size: AppSizing.iconMd,
            ),
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
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) =>
          _AlertCard(view: alerts[index], storeId: storeId),
    );
  }
}

// -----------------------------------------------------------------------------
// One row.
// -----------------------------------------------------------------------------

/// One article, as compactly as it can still be read.
///
/// The row used to carry five things: the name, the level, a status badge, an
/// on-order pill and a button naming the supplier — most of them repeating what
/// a neighbour already said, on four lines, fifteen times down the page. What
/// is left is three zones:
///
/// - **who** — the article, with its category and supplier underneath;
/// - **how bad** — the level, the bar, and the shortfall in two words;
/// - **what to do** — one button.
///
/// The status badge went because the number is the status: "0 / 8 kg" needs no
/// label, and in the default order the section heading above already names it.
/// "Rien en commande" went because it was on almost every row — silence now
/// means nothing is coming, and only stock genuinely on its way says so.
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
      visualDensity: VisualDensity.compact,
    );

    final nameBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.name,
          style: theme.textTheme.titleSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          // Category and supplier on one muted line. The supplier being here is
          // what lets the button below be one word.
          supplierName == null
              ? view.row.categoryName
              : '${view.row.categoryName} · $supplierName',
          style: theme.textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    // "manque 2 kg · 20 kg en route" — the two facts that decide the row, as a
    // single quiet line under the bar.
    final notes = <String>[
      if (shortfall > 0)
        l10n.alertsShortfallShort(
          Formatters.quantityWithUnit(shortfall, unit),
        ),
      if (view.onOrderQuantity > 0)
        l10n.alertsOnOrder(
          Formatters.quantityWithUnit(view.onOrderQuantity, unit),
        ),
    ];

    final levelBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.alertsLevel(
            Formatters.quantityWithUnit(item.quantity, unit),
            Formatters.quantityWithUnit(item.lowStockThreshold, unit),
          ),
          // Weight, not colour. The figure was tinted on every row, which made
          // the one thing every row has look like the alarm — and left nothing
          // louder for a rupture to be.
          style: AppTypography.numeric.copyWith(fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs),
        StockGauge(
          quantity: item.quantity,
          minimum: item.lowStockThreshold,
          maximum: item.maxStock,
          onOrder: view.onOrderQuantity,
          color: colors.solid,
        ),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            notes.join(' · '),
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );

    final orderButton = supplierId == null
        ? null
        : SecondaryButton(
            label: l10n.alertsOrder,
            icon: LucideIcons.truck,
            onPressed: () => context.pushScreen(
              '${Routes.toNewOrder(storeId)}?supplier=$supplierId&prefill=1',
            ),
          );

    return AppCard(
      onTap: () => context.pushScreen(Routes.toItem(storeId, item.id)),
      // Tighter than the default card: this is a list to work down, not a panel
      // to read, and sixteen points of padding a side turned fifteen rows into
      // two screens of scrolling.
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      // Only a rupture earns the coloured edge. When every row had one the edge
      // stopped meaning "look here" and became the list's wallpaper; reserved
      // for the articles at zero, a glance down the page finds them.
      accentColor: status == StockStatus.outOfStock ? colors.solid : null,
      selected: selected,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Narrow, or at large text: the level goes under the name rather than
          // beside it, and the button takes the width. Side by side, neither
          // the name nor the button can shrink past its own words.
          if (constraints.maxWidth < 560 || context.isLargeText) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    checkbox,
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: nameBlock),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                levelBlock,
                if (orderButton != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Align(alignment: Alignment.centerLeft, child: orderButton),
                ],
              ],
            );
          }

          return Row(
            children: [
              checkbox,
              const SizedBox(width: AppSpacing.xs),
              Expanded(flex: 5, child: nameBlock),
              const SizedBox(width: AppSpacing.lg),
              Expanded(flex: 4, child: levelBlock),
              if (orderButton != null) ...[
                const SizedBox(width: AppSpacing.lg),
                orderButton,
              ],
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
      // As on the cards: only the articles at zero are edged, so the eye can
      // find them down a column of otherwise identical rows.
      rowAccent: (v) => stockStatusOf(v.row.item) == StockStatus.outOfStock
          ? StockStatusBadge.colorsFor(StockStatus.outOfStock).solid
          : null,
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
            style: AppTypography.numeric.copyWith(fontWeight: FontWeight.w700),
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
