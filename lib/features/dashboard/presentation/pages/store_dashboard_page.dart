import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/stock_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../data/current_employee.dart';
import '../../../../data/providers.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../stock_movement/presentation/widgets/movement_labels.dart';
import '../../../stock_movement/presentation/widgets/movement_type_badge.dart';
import '../widgets/summary_tile.dart';
import '../../../inventory/presentation/widgets/product_drawer.dart';

/// The store dashboard.
///
/// Built last of the main features on purpose: it summarises everything else,
/// so building it after inventory, movements and suppliers meant its tiles
/// reference real shapes rather than guesses.
///
/// Ordered by what a manager walking in wants: how much is this worth, what is
/// about to run out, what do I need to do, what just happened.
class StoreDashboardPage extends ConsumerWidget {
  const StoreDashboardPage({required this.storeId, super.key});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // The dashboard summarises everything a write can touch — stock levels,
    // open orders, recent movements — so every one of these follows the tables
    // it reads, and the page redraws whenever a delivery or a correction lands.
    //
    // Six queries, folded into one decision. Six skeletons resolving at six
    // different moments would read as a page assembling itself.
    final data = asyncAll4(
      ref.watch(itemRowsProvider((storeId: storeId, filter: ItemFilter.none))),
      ref.watch(suppliersProvider(storeId)),
      ref.watch(movementRowsForStoreProvider(storeId)),
      ref.watch(openOrderRowsProvider(storeId)),
      (rows, suppliers, activity, openOrders) => (
        rows: rows,
        suppliers: suppliers,
        activity: activity,
        openOrders: openOrders,
      ),
    );

    return AsyncContent<
      ({
        List<ItemRowView> rows,
        List<Supplier> suppliers,
        List<MovementRowView> activity,
        List<OrderRowView> openOrders,
      })
    >(
      value: data,
      onRetry: () {
        ref.invalidate(
          itemRowsProvider((storeId: storeId, filter: ItemFilter.none)),
        );
        ref.invalidate(suppliersProvider(storeId));
        ref.invalidate(movementRowsForStoreProvider(storeId));
        ref.invalidate(openOrderRowsProvider(storeId));
      },
      skeleton: ShellPage(
        title: l10n.dashboardTitle,
        child: const SkeletonList(rows: 3, rowHeight: 140),
      ),
      builder: (context, data) => _body(context, ref, l10n, data),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    ({
      List<ItemRowView> rows,
      List<Supplier> suppliers,
      List<MovementRowView> activity,
      List<OrderRowView> openOrders,
    })
    data,
  ) {
    final items = data.rows;
    final suppliers = data.suppliers;
    final openOrders = data.openOrders;

    // Only the most recent handful, and only after the whole log has been
    // fetched for the store — which the alerts strip beside it needs anyway.
    final activity = data.activity.take(8).toList();

    final alerts = [
      for (final row in items)
        if (needsAttention(row.item)) row,
    ];

    // Watched separately because a Future cannot join the fold above, and
    // because an empty answer is the right thing to draw while it is out: no
    // warning is better than a warning that appears and then retracts.

    // The greeting names whoever is signed in; blank until it knows, which
    // reads as a plain "Bonjour" rather than as a missing name.
    final userName = ref.watch(currentEmployeeProvider)?.firstName;

    if (items.isEmpty) {
      return ShellPage(
        title: l10n.dashboardTitle,
        scrollable: false,
        child: EmptyState(
          icon: LucideIcons.packageOpen,
          title: l10n.dashboardEmptyStore,
          message: l10n.dashboardEmptyStoreBody,
          actionLabel: l10n.actionAddItem,
          actionIcon: LucideIcons.plus,
          onAction: () => context.pushScreen(Routes.toAddItem(storeId)),
        ),
      );
    }

    final storeName = ref.watch(storeProvider(storeId)).value?.name;
    final phone = context.isPhone;

    return ShellPage(
      title: l10n.dashboardTitle,
      // Who, when and where, in one line: the greeting, today's date and the
      // store — information rather than description, so it stays on a phone.
      subtitle: [
        l10n.dashboardGreeting(userName ?? '').trim(),
        Formatters.weekdayDayMonth(DateTime.now()),
        ?storeName,
      ].join(' · '),
      keepSubtitle: true,
      actions: [
        PrimaryButton(
          label: l10n.actionAddDelivery,
          shortLabel: l10n.shortAddDelivery,
          icon: LucideIcons.arrowDownToLine,
          onPressed: () => context.pushScreen(Routes.toStockIn(storeId)),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The figures — one row, always. Equal cards when they fit; a
          // sideways scroll with the next card peeking in when they do not.
          CardRow(
            minCardWidth: 176,
            scrollCardWidth: 172,
            spacing: phone ? AppSpacing.md : AppSpacing.lg,
            children: [
              SummaryTile(
                label: l10n.dashboardTileStockValue,
                value: Formatters.priceCompact(
                  ref.watch(stockValuationProvider(storeId)).value ?? 0,
                ),
                icon: LucideIcons.wallet,
                iconColors: AppColors.onBreak,
                caption: l10n.valuationBasis,
                onTap: () =>
                    context.pushScreen(Routes.toValuationReport(storeId)),
              ),
              SummaryTile(
                label: l10n.dashboardTileItems,
                value: '${items.length}',
                icon: LucideIcons.boxes,
                iconColors: AppColors.info,
                caption: l10n.storesItemCount(items.length),
                onTap: () => context.goSection(Routes.toInventory(storeId)),
              ),
              SummaryTile(
                label: l10n.dashboardTileLowStock,
                value: '${alerts.length}',
                icon: LucideIcons.triangleAlert,
                // Tinted only when there is something to act on — red once a
                // product has run out, amber while they are only low.
                accent: alerts.isEmpty
                    ? null
                    : alerts.any(
                        (row) =>
                            stockStatusOf(row.item) == StockStatus.outOfStock,
                      )
                    ? AppColors.outOfStock
                    : AppColors.lowStock,
                iconColors: AppColors.inStock,
                caption: l10n.storesAlertCount(alerts.length),
                onTap: () => context.goSection(Routes.toAlerts(storeId)),
              ),
              SummaryTile(
                label: l10n.dashboardTileOnOrder,
                value: '${openOrders.length}',
                icon: LucideIcons.clipboardList,
                iconColors: AppColors.lowStock,
                caption: l10n.dashboardOnOrderCaption(openOrders.length),
                onTap: () => context.goSection(Routes.toReceptions(storeId)),
              ),
              SummaryTile(
                label: l10n.dashboardTileSuppliers,
                value: '${suppliers.length}',
                icon: LucideIcons.truck,
                caption: l10n.suppliersProductCount(items.length),
                onTap: () => context.goSection(Routes.toSuppliers(storeId)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          SectionHeader(title: l10n.dashboardQuickActions),
          // The three kinds of movement, in their colours, and a new product
          // — four that share one row even at 360dp, as icon-over-label
          // shortcuts there.
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 640;
              return CardRow(
                minCardWidth: compact ? 64 : 150,
                scrollCardWidth: 72,
                spacing: compact ? AppSpacing.sm : AppSpacing.md,
                children: [
                  QuickActionButton(
                    label: l10n.actionAddDelivery,
                    shortLabel: l10n.shortAddDelivery,
                    icon: LucideIcons.arrowDownToLine,
                    colors: movementColors(StockMovementType.stockIn),
                    emphasised: true,
                    compact: compact,
                    onPressed: () =>
                        context.pushScreen(Routes.toStockIn(storeId)),
                  ),
                  QuickActionButton(
                    label: l10n.actionLogUsage,
                    shortLabel: l10n.shortLogUsage,
                    icon: LucideIcons.arrowUpFromLine,
                    colors: movementColors(StockMovementType.stockOut),
                    compact: compact,
                    onPressed: () =>
                        context.pushScreen(Routes.toStockOut(storeId)),
                  ),
                  QuickActionButton(
                    label: l10n.actionAdjustStock,
                    shortLabel: l10n.shortAdjustStock,
                    icon: LucideIcons.clipboardCheck,
                    colors: movementColors(StockMovementType.adjustment),
                    compact: compact,
                    onPressed: () =>
                        context.pushScreen(Routes.toAdjustment(storeId)),
                  ),
                  QuickActionButton(
                    label: l10n.actionAddItem,
                    shortLabel: l10n.dashboardAddProductShort,
                    icon: LucideIcons.plus,
                    colors: AppColors.onBreak,
                    compact: compact,
                    onPressed: () =>
                        context.pushScreen(Routes.toAddItem(storeId)),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),

          // What happened and what needs doing — side by side with room,
          // two tabs of one panel on a phone.
          if (context.canSplitView)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _ActivityPanel(storeId: storeId, activity: activity),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  flex: 2,
                  child: _AlertsPanel(storeId: storeId, alerts: alerts),
                ),
              ],
            )
          else
            _TabbedPanels(storeId: storeId, activity: activity, alerts: alerts),
        ],
      ),
    );
  }
}

/// A card with a header — the frame both lower panels share, so they line up
/// and read as a pair.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.count,
    this.onViewAll,
    this.showHeader = true,
  });

  final String title;
  final int? count;
  final VoidCallback? onViewAll;
  final Widget child;

  /// Off inside the phone tabs, where the tab already names the panel.
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  // The title takes whatever the link leaves, so the link
                  // sits hard against the right edge of the panel.
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (count != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          _CountBadge(count: count!),
                        ],
                      ],
                    ),
                  ),
                  if (onViewAll != null)
                    // Capped rather than fixed: at 150% text the narrower
                    // panel has no room for the label at full width, and the
                    // label gives way before the row does.
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: TextButton(
                        onPressed: onViewAll,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                l10n.actionViewAll,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            const Icon(
                              LucideIcons.arrowRight,
                              size: AppSizing.iconSm,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.lowStock.container,
      borderRadius: AppRadius.pillAll,
    ),
    child: Text(
      '$count',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.lowStock.foreground,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({
    required this.storeId,
    required this.activity,
    this.showHeader = true,
  });

  final String storeId;
  final List<MovementRowView> activity;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _Panel(
      title: l10n.dashboardRecentActivity,
      showHeader: showHeader,
      onViewAll: () => context.goSection(Routes.toMovements(storeId)),
      child: activity.isEmpty
          ? EmptyState(
              icon: LucideIcons.arrowRightLeft,
              title: l10n.dashboardNoActivity,
              message: l10n.dashboardNoActivityBody,
              actionLabel: l10n.actionAddDelivery,
              onAction: () => context.pushScreen(Routes.toStockIn(storeId)),
            )
          : _ActivityTable(storeId: storeId, activity: activity),
    );
  }
}

/// The latest movements as a compact table: product with its type's dot,
/// the signed quantity, who, and when. Each row opens the product.
class _ActivityTable extends StatelessWidget {
  const _ActivityTable({required this.storeId, required this.activity});

  final String storeId;
  final List<MovementRowView> activity;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = DateTime.now();

    return AppTable<MovementRowView>(
      rows: activity,
      shrinkWrap: true,
      bordered: false,
      headerColor: AppColors.surface,
      rowHeight: 52,
      // The product, not the movement: a row here names an article, and the
      // panel answers everything about it — this movement included, in its own
      // recent history.
      onRowTap: (view) => openProductDrawer(
        context,
        storeId: storeId,
        itemId: view.movement.itemId,
      ),
      columns: [
        AppTableColumn(label: l10n.tableColProduct, flex: 3),
        AppTableColumn(
          label: l10n.tableColType,
          width: 128,
          minTableWidth: 480,
        ),
        AppTableColumn(label: l10n.tableColQuantity, width: 104, numeric: true),
        AppTableColumn(label: l10n.tableColBy, flex: 2, minTableWidth: 600),
        AppTableColumn(label: l10n.tableColTime, width: 72, numeric: true),
      ],
      cell: (context, view, column) {
        final movement = view.movement;
        return switch (column) {
          0 => Row(
            children: [
              ProductImage(imagePath: view.itemImagePath, size: 32, radius: 6),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  view.itemName,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          1 => MovementTypeBadge(type: movement.type),
          2 => Text(
            Formatters.quantityDelta(movement.quantity, view.unitAbbreviation),
            style: AppTypography.numeric.copyWith(
              fontWeight: FontWeight.w700,
              color: movementQuantityColor(movement.type),
            ),
            maxLines: 1,
          ),
          3 => Text(
            movement.userName,
            style: theme.textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          _ => Text(
            _when(movement.occurredAt, now),
            style: theme.textTheme.bodySmall,
            maxLines: 1,
          ),
        };
      },
    );
  }

  /// The time today, the day before that.
  static String _when(DateTime at, DateTime now) =>
      at.year == now.year && at.month == now.month && at.day == now.day
      ? Formatters.time(at)
      : Formatters.dayMonth(at);
}

class _AlertsPanel extends StatelessWidget {
  const _AlertsPanel({
    required this.storeId,
    required this.alerts,
    this.showHeader = true,
  });

  final String storeId;
  final List<ItemRowView> alerts;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Out of stock first, then the lowest against their threshold.
    final shown =
        ([...alerts]..sort((a, b) {
              final byStatus = stockStatusOf(
                b.item,
              ).index.compareTo(stockStatusOf(a.item).index);
              if (byStatus != 0) return byStatus;
              return _fill(a.item).compareTo(_fill(b.item));
            }))
            .take(6)
            .toList();

    return _Panel(
      title: l10n.dashboardAlertsTitle,
      showHeader: showHeader,
      count: alerts.isEmpty ? null : alerts.length,
      onViewAll: alerts.isEmpty
          ? null
          : () => context.goSection(Routes.toAlerts(storeId)),
      child: shown.isEmpty
          ? EmptyState(
              icon: LucideIcons.circleCheck,
              title: l10n.dashboardAllGood,
              message: l10n.dashboardAllGoodBody,
            )
          : _AlertsTable(storeId: storeId, alerts: shown),
    );
  }
}

/// How far into its alert zone a product is: its stock over its threshold.
/// How full an article is against its declared maximum.
///
/// The alerts panel's tie-breaker, not a drawing figure — [StockGauge] works
/// its own out. Keyed to the maximum rather than to the threshold so the order
/// down the panel matches the length of the bars beside it; against the
/// threshold an article at 2 of 8 and one at 2 of 80 sorted the same.
double _fill(Item item) => item.maxStock <= 0
    ? 0
    : (item.quantity / item.maxStock).clamp(0.0, 1.0);

/// The products under their threshold as a compact table: photo and name,
/// stock against threshold with a gauge, and the status. Each row opens the
/// product.
class _AlertsTable extends StatelessWidget {
  const _AlertsTable({required this.storeId, required this.alerts});

  final String storeId;
  final List<ItemRowView> alerts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AppTable<ItemRowView>(
      rows: alerts,
      shrinkWrap: true,
      bordered: false,
      headerColor: AppColors.surface,
      rowHeight: 52,
      onRowTap: (view) => openProductDrawer(
        context,
        storeId: storeId,
        itemId: view.item.id,
      ),
      columns: [
        AppTableColumn(label: l10n.tableColProduct, flex: 3),
        AppTableColumn(label: l10n.tableColStock, width: 112, numeric: true),
        AppTableColumn(
          label: l10n.tableColLevel,
          width: 88,
          minTableWidth: 400,
        ),
        AppTableColumn(
          label: l10n.tableColStatus,
          width: 132,
          minTableWidth: 440,
        ),
      ],
      cell: (context, view, column) {
        final item = view.item;
        final status = stockStatusOf(item);
        final colors = StockStatusBadge.colorsFor(status);
        return switch (column) {
          0 => Row(
            children: [
              ProductImage(imagePath: item.imagePath, size: 32, radius: 6),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  item.name,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          1 => Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Formatters.quantityWithUnit(
                  item.quantity,
                  view.unitAbbreviation,
                ),
                style: AppTypography.numeric.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
              ),
              Text(
                '/ ${Formatters.quantity(item.lowStockThreshold)}',
                style: theme.textTheme.bodySmall,
                maxLines: 1,
              ),
            ],
          ),
          // The shared gauge: it fills to the declared maximum and marks the
          // minimum, where this filled at the minimum and so showed every
          // alerted product as a nearly empty bar of the same length.
          2 => StockGauge(
            quantity: item.quantity,
            minimum: item.lowStockThreshold,
            maximum: item.maxStock,
          ),
          _ => StatusDot(
            color: colors.solid,
            label: StockStatusBadge.labelFor(l10n, status),
          ),
        };
      },
    );
  }
}

/// On a phone the two lower panels share one place: a two-way switch, then
/// whichever panel is chosen. Stacked, the alerts sat a screen and a half
/// below the fold.
class _TabbedPanels extends StatefulWidget {
  const _TabbedPanels({
    required this.storeId,
    required this.activity,
    required this.alerts,
  });

  final String storeId;
  final List<MovementRowView> activity;
  final List<ItemRowView> alerts;

  @override
  State<_TabbedPanels> createState() => _TabbedPanelsState();
}

class _TabbedPanelsState extends State<_TabbedPanels> {
  bool _alerts = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: AppRadius.pillAll,
          ),
          child: Row(
            children: [
              _Tab(
                label: l10n.dashboardTabActivity,
                selected: !_alerts,
                onTap: () => setState(() => _alerts = false),
              ),
              _Tab(
                label: l10n.dashboardTabAlerts,
                count: widget.alerts.isEmpty ? null : widget.alerts.length,
                selected: _alerts,
                onTap: () => setState(() => _alerts = true),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_alerts)
          _AlertsPanel(
            storeId: widget.storeId,
            alerts: widget.alerts,
            showHeader: false,
          )
        else
          _ActivityPanel(
            storeId: widget.storeId,
            activity: widget.activity,
            showHeader: false,
          ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => context.goSection(
              _alerts
                  ? Routes.toAlerts(widget.storeId)
                  : Routes.toMovements(widget.storeId),
            ),
            child: Text(l10n.actionViewAll),
          ),
        ),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: AppRadius.pillAll,
          elevation: selected ? 1 : 0,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.pillAll,
            child: Container(
              constraints: const BoxConstraints(minHeight: 40),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: selected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    _CountBadge(count: count!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
