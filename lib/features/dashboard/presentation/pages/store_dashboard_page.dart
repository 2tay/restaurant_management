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
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../orders/presentation/pages/orders_list_page.dart';
import '../../../stock_movement/presentation/widgets/movement_row.dart';
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
    // open orders, recent movements — so it redraws whenever one lands.
    ref.watch(mockDataRevisionProvider);

    final items = MockQueries.itemsForStore(storeId);
    final alerts = MockQueries.lowStockItems(storeId);
    final suppliers = MockQueries.suppliersForStore(storeId);
    final activity = MockQueries.recentActivity(storeId);
    final openOrders = MockQueries.openOrders(storeId);
    final staleOrders = MockQueries.staleOrders(storeId);

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

    final columns = context.gridColumns(max: 4);

    return ShellPage(
      title: l10n.dashboardTitle,
      subtitle: l10n.dashboardGreeting(mockCurrentEmployee.firstName),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The real defence against orders left half-open. Whatever anybody
          // tapped at receiving time, an order sitting in `partial` past the
          // store's threshold keeps inflating the "on order" quantity — which
          // makes the double-order indicator lie — until somebody closes it.
          if (staleOrders.isNotEmpty) ...[
            _StaleOrdersWarning(storeId: storeId, count: staleOrders.length),
            const SizedBox(height: AppSpacing.xl),
          ],

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.lg,
            mainAxisSpacing: AppSpacing.lg,
            childAspectRatio: 1.55,
            children: [
              SummaryTile(
                label: l10n.dashboardTileStockValue,
                value: Formatters.priceCompact(MockQueries.stockValuation(storeId)),
                icon: LucideIcons.wallet,
                caption: l10n.valuationBasis,
                onTap: () =>
                    context.pushScreen(Routes.toValuationReport(storeId)),
              ),
              SummaryTile(
                label: l10n.dashboardTileItems,
                value: '${items.length}',
                icon: LucideIcons.boxes,
                caption: l10n.storesItemCount(items.length),
                onTap: () => context.goSection(Routes.toInventory(storeId)),
              ),
              SummaryTile(
                label: l10n.dashboardTileLowStock,
                value: '${alerts.length}',
                icon: LucideIcons.triangleAlert,
                // Tinted so it reads as something to act on rather than a
                // neutral statistic — but only when there is something to act
                // on.
                accent: alerts.isEmpty ? null : AppColors.lowStock,
                caption: l10n.storesAlertCount(alerts.length),
                onTap: () => context.goSection(Routes.toAlerts(storeId)),
              ),
              SummaryTile(
                label: l10n.dashboardTileOnOrder,
                value: '${openOrders.length}',
                icon: LucideIcons.clipboardList,
                caption: l10n.dashboardOnOrderCaption(openOrders.length),
                onTap: () => context.goSection(Routes.toOrders(storeId)),
              ),
              SummaryTile(
                label: l10n.dashboardTileSuppliers,
                value: '${suppliers.length}',
                icon: LucideIcons.truck,
                caption: l10n.suppliersProductCount(
                  MockQueries.itemsForStore(storeId).length,
                ),
                onTap: () => context.goSection(Routes.toSuppliers(storeId)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),

          SectionHeader(title: l10n.dashboardQuickActions),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.lg,
            mainAxisSpacing: AppSpacing.lg,
            childAspectRatio: 1.9,
            children: [
              QuickActionButton(
                label: l10n.actionAddDelivery,
                icon: LucideIcons.arrowDownToLine,
                emphasised: true,
                onPressed: () => context.pushScreen(Routes.toStockIn(storeId)),
              ),
              QuickActionButton(
                label: l10n.actionLogUsage,
                icon: LucideIcons.arrowUpFromLine,
                onPressed: () => context.pushScreen(Routes.toStockOut(storeId)),
              ),
              QuickActionButton(
                label: l10n.actionAddItem,
                icon: LucideIcons.plus,
                onPressed: () => context.pushScreen(Routes.toAddItem(storeId)),
              ),
              QuickActionButton(
                label: l10n.navAlerts,
                icon: LucideIcons.triangleAlert,
                onPressed: () => context.goSection(Routes.toAlerts(storeId)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),

          if (context.canSplitView)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _ActivityPanel(storeId: storeId, activity: activity),
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  Expanded(
                    flex: 2,
                    child: _AlertsPanel(storeId: storeId, alerts: alerts),
                  ),
                ],
              ),
            )
          else ...[
            _ActivityPanel(storeId: storeId, activity: activity),
            const SizedBox(height: AppSpacing.xl),
            _AlertsPanel(storeId: storeId, alerts: alerts),
          ],
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
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.lowStock.container,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.clock,
            size: AppSizing.iconLg,
            color: AppColors.lowStock.foreground,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.dashboardStaleOrdersTitle(
                    count,
                    MockQueries.storeSettings(storeId).stalePartialOrderDays,
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.lowStock.foreground,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.dashboardStaleOrdersBody,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.lowStock.foreground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          SecondaryButton(
            label: l10n.dashboardStaleOrdersAction,
            icon: LucideIcons.clipboardList,
            onPressed: () {
              // Land on the orders that need doing something about, not on
              // ninety days of history the user then has to filter down.
              ref.read(ordersFilterProvider.notifier).showOpenOnly();
              context.goSection(Routes.toOrders(storeId));
            },
          ),
        ],
      ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({required this.storeId, required this.activity});

  final String storeId;
  final List<StockMovement> activity;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.dashboardRecentActivity,
          trailing: TextButton(
            onPressed: () => context.goSection(Routes.toMovements(storeId)),
            child: Text(l10n.actionViewAll),
          ),
        ),
        if (activity.isEmpty)
          AppCard(
            child: EmptyState(
              icon: LucideIcons.arrowRightLeft,
              title: l10n.dashboardNoActivity,
              message: l10n.dashboardNoActivityBody,
              actionLabel: l10n.actionAddDelivery,
              onAction: () => context.pushScreen(Routes.toStockIn(storeId)),
            ),
          )
        else
          for (final movement in activity)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: MovementRow(
                movement: movement,
                storeId: storeId,
                onTap: () =>
                    context.pushScreen(Routes.toItem(storeId, movement.itemId)),
              ),
            ),
      ],
    );
  }
}

class _AlertsPanel extends StatelessWidget {
  const _AlertsPanel({required this.storeId, required this.alerts});

  final String storeId;
  final List<Item> alerts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shown = alerts.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.dashboardAlertsTitle,
          count: alerts.isEmpty ? null : alerts.length,
          trailing: alerts.isEmpty
              ? null
              : TextButton(
                  onPressed: () => context.goSection(Routes.toAlerts(storeId)),
                  child: Text(l10n.actionViewAll),
                ),
        ),
        if (shown.isEmpty)
          AppCard(
            child: EmptyState(
              icon: LucideIcons.circleCheck,
              title: l10n.dashboardAllGood,
              message: l10n.dashboardAllGoodBody,
            ),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final item in shown)
                  _AlertLine(item: item, storeId: storeId),
              ],
            ),
          ),
      ],
    );
  }
}

class _AlertLine extends StatelessWidget {
  const _AlertLine({required this.item, required this.storeId});

  final Item item;
  final String storeId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = MockQueries.unitAbbreviationOf(item.unitId);

    return InkWell(
      onTap: () => context.pushScreen(Routes.toItem(storeId, item.id)),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
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
                    Formatters.quantityWithUnit(item.quantity, unit),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            StockStatusBadge(status: stockStatusOf(item), compact: true),
          ],
        ),
      ),
    );
  }
}
