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
import '../../../../core/utils/order_status.dart';
import '../../../../data/current_employee.dart';
import '../../../../data/providers.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../orders/presentation/pages/orders_list_page.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../stock_movement/presentation/widgets/movement_labels.dart';
import '../widgets/summary_tile.dart';

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
    final staleOrders =
        ref.watch(staleOrdersProvider(storeId)).value ??
        const <PurchaseOrder>[];

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
          // The real defence against orders left half-open. Whatever anybody
          // tapped at receiving time, an order sitting in `partial` past the
          // store's threshold keeps inflating the "on order" quantity — which
          // makes the double-order indicator lie — until somebody closes it.
          if (staleOrders.isNotEmpty) ...[
            _StaleOrdersWarning(storeId: storeId, count: staleOrders.length),
            const SizedBox(height: AppSpacing.lg),
          ],

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
                onTap: () => context.goSection(Routes.toOrders(storeId)),
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
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
              ),
            )
          else
            _TabbedPanels(storeId: storeId, activity: activity, alerts: alerts),
        ],
      ),
    );
  }
}

/// Orders left half-received for longer than the store's threshold.
///
/// Stated on the dashboard rather than left to the orders list because nobody
/// goes looking for a problem they do not know they have. An order stuck in
/// `partial` is invisible by nature: the goods that did arrive were booked in
/// and everything looked fine.
class _StaleOrdersWarning extends ConsumerWidget {
  const _StaleOrdersWarning({required this.storeId, required this.count});

  final String storeId;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // The establishment's own threshold, a column since this phase rather than
    // the mutable global it was in Phase 1. Falls back to the default while the
    // query is out, which is the number the settings form falls back to too.
    final days =
        ref.watch(stalePartialOrderDaysProvider(storeId)).value ??
        OrderRules.defaultStalePartialDays;

    return NoticeBanner(
      icon: LucideIcons.clock,
      colors: AppColors.lowStock,
      title: l10n.dashboardStaleOrdersTitle(count, days),
      message: l10n.dashboardStaleOrdersBody,
      action: SecondaryButton(
        label: l10n.dashboardStaleOrdersAction,
        icon: LucideIcons.clipboardList,
        onPressed: () {
          // Land on the orders that need doing something about, not on ninety
          // days of history the user then has to filter down.
          ref.read(ordersFilterProvider.notifier).showOpenOnly();
          context.goSection(Routes.toOrders(storeId));
        },
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
                  const Spacer(),
                  // Shrinks with the title rather than pushing the row past
                  // its edge — the narrower panel at 150% text had no room
                  // for both at full width.
                  if (onViewAll != null)
                    Flexible(
                      child: TextButton(
                        onPressed: onViewAll,
                        child: Text(
                          l10n.actionViewAll,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
          : Column(
              children: [
                for (final (i, view) in activity.indexed)
                  _ActivityLine(
                    view: view,
                    last: i == activity.length - 1,
                    onTap: () => context.pushScreen(
                      Routes.toItem(storeId, view.movement.itemId),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// One movement as a line of a timeline: a dot in the movement's colour and a
/// rail joining it to the next, the product, who and when, and the signed
/// quantity.
class _ActivityLine extends StatelessWidget {
  const _ActivityLine({
    required this.view,
    required this.last,
    required this.onTap,
  });

  final MovementRowView view;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final movement = view.movement;
    final colors = movementColors(movement.type);

    final at = movement.occurredAt;
    final now = DateTime.now();
    final today =
        at.year == now.year && at.month == now.month && at.day == now.day;
    final when = today ? Formatters.time(at) : Formatters.dayMonth(at);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 20,
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.md + 4),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colors.solid,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.container, width: 2),
                      ),
                    ),
                    if (!last)
                      Expanded(
                        child: Container(width: 2, color: AppColors.hairline),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        view.itemName,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: EmployeeNameTag(
                              name: movement.userName,
                              employeeId: movement.employeeId,
                              style: theme.textTheme.bodySmall,
                              avatarSize: 16,
                            ),
                          ),
                          Text(' · $when', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  Formatters.quantityDelta(
                    movement.quantity,
                    view.unitAbbreviation,
                  ),
                  style: AppTypography.numeric.copyWith(
                    fontWeight: FontWeight.w700,
                    color: quantityDeltaColor(movement.quantity),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
              return _level(a.item).compareTo(_level(b.item));
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
          : Column(
              children: [
                for (final view in shown)
                  _AlertLine(view: view, storeId: storeId),
              ],
            ),
    );
  }
}

/// How far into its alert zone a product is: its stock over its threshold.
double _level(Item item) => item.lowStockThreshold <= 0
    ? 0
    : (item.quantity / item.lowStockThreshold).clamp(0.0, 1.0);

class _AlertLine extends StatelessWidget {
  const _AlertLine({required this.view, required this.storeId});

  final ItemRowView view;
  final String storeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final item = view.item;
    final unit = view.unitAbbreviation;
    final status = stockStatusOf(item);
    final colors = StockStatusBadge.colorsFor(status);

    return InkWell(
      onTap: () => context.pushScreen(Routes.toItem(storeId, item.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            ProductImage(imagePath: item.imagePath, size: 36, radius: 8),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    l10n.dashboardAlertLevel(
                      Formatters.quantityWithUnit(item.quantity, unit),
                      Formatters.quantity(item.lowStockThreshold),
                    ),
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // How close to empty, in the status colour — the gauge a
                  // manager reads before the number.
                  ClipRRect(
                    borderRadius: AppRadius.pillAll,
                    child: LinearProgressIndicator(
                      value: _level(item),
                      minHeight: 4,
                      color: colors.solid,
                      backgroundColor: colors.container,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            StockStatusBadge(status: status, compact: true),
          ],
        ),
      ),
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
