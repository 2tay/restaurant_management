import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/stock_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../data/providers.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../shared/widgets/widgets.dart';

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
class LowStockAlertsPage extends ConsumerWidget {
  const LowStockAlertsPage({required this.storeId, super.key});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // Ordering and receiving both change what this screen should say, and the
    // query watches the tables both of them write to.
    final asyncAlerts = ref.watch(lowStockAlertsProvider(storeId));
    final alerts = asyncAlerts.value ?? const <LowStockAlertView>[];

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
      scrollable: false,
      actions: [
        SecondaryButton(
          label: l10n.actionAddDelivery,
          icon: LucideIcons.arrowDownToLine,
          onPressed: () => context.pushScreen(Routes.toStockIn(storeId)),
        ),
        PrimaryButton(
          label: l10n.alertsCreateOrders,
          icon: LucideIcons.clipboardList,
          onPressed: alerts.isEmpty
              ? null
              : () => _startOrders(context, alerts),
        ),
      ],
      child: AsyncListContent<LowStockAlertView>(
        value: asyncAlerts,
        onRetry: () => ref.invalidate(lowStockAlertsProvider(storeId)),
        empty: EmptyState(
          icon: LucideIcons.circleCheck,
          title: l10n.alertsEmpty,
          message: l10n.alertsEmptyBody,
        ),
        builder: (context, alerts) => ListView.separated(
          itemCount: alerts.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) =>
              _AlertCard(view: alerts[index], storeId: storeId),
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
    // Counted per supplier, and named from the same rows — the sheet lists who
    // would fill each group, and the row it came from already knows.
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

    final supplierId = await _SupplierGroupSheet.show(context, grouped);
    if (supplierId == null || !context.mounted) return;

    // `prefill` tells the order form to add this supplier's low items straight
    // away, which is the whole point of arriving from here.
    context.pushScreen(
      '${Routes.toNewOrder(storeId)}?supplier=$supplierId&prefill=1',
    );
  }
}

/// Which supplier to start a draft for.
class _SupplierGroupSheet extends StatelessWidget {
  const _SupplierGroupSheet({required this.grouped});

  /// Supplier id to how many low items they supply.
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

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.view, required this.storeId});

  final LowStockAlertView view;
  final String storeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final item = view.row.item;
    final status = stockStatusOf(item);
    final colors = StockStatusBadge.colorsFor(status);
    final unit = view.row.unitAbbreviation;
    final shortfall = item.lowStockThreshold - item.quantity;
    final supplierId = view.defaultSupplierId;
    final supplierName = view.defaultSupplierName;
    final onOrder = view.onOrderQuantity;

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
          view.row.categoryName,
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
          Formatters.quantityWithUnit(item.quantity, unit),
          style: AppTypography.numeric.copyWith(
            color: colors.foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (shortfall > 0)
          Text(
            l10n.alertsShortfall(Formatters.quantityWithUnit(shortfall, unit)),
            style: theme.textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );

    // The row's whole reason for existing after Phase 1.6: "low, and somebody
    // has already dealt with it" has to look different from "low, and nobody
    // has".
    final onOrderBlock = _OnOrderState(
      onOrder: onOrder,
      unitAbbreviation: unit,
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Five columns — name, quantity, on-order, status, action — plus
          // French labels do not fit a tablet held in portrait. Squeezing them
          // crushes the action button below the width of its own icon, so
          // below this the card becomes three stacked rows instead.
          if (constraints.maxWidth < 900) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: nameBlock),
                    const SizedBox(width: AppSpacing.md),
                    StockStatusBadge(status: status),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: quantityBlock),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: onOrderBlock),
                  ],
                ),
                if (orderButton != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Align(alignment: Alignment.centerLeft, child: orderButton),
                ],
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 4, child: nameBlock),
              const SizedBox(width: AppSpacing.md),
              Expanded(flex: 3, child: quantityBlock),
              const SizedBox(width: AppSpacing.md),
              Expanded(flex: 3, child: onOrderBlock),
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

class _OnOrderState extends StatelessWidget {
  const _OnOrderState({required this.onOrder, required this.unitAbbreviation});

  final double onOrder;
  final String unitAbbreviation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (onOrder <= 0) {
      return Row(
        children: [
          const Icon(
            LucideIcons.circleAlert,
            size: AppSizing.iconSm,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              l10n.alertsNothingOnOrder,
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        const Icon(
          LucideIcons.truck,
          size: AppSizing.iconSm,
          color: AppColors.steel800,
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            l10n.alertsOnOrder(
              Formatters.quantityWithUnit(onOrder, unitAbbreviation),
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.steel800,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
