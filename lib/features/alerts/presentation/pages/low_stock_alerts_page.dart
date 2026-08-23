import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/stock_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

/// Everything at or below its threshold, worst first.
///
/// Each row states the shortfall — how much is needed to get back above the
/// threshold — and offers to order from the item's usual supplier. A list that
/// only says "this is low" leaves the user to do the arithmetic and then go
/// looking for the supplier.
class LowStockAlertsPage extends StatelessWidget {
  const LowStockAlertsPage({required this.storeId, super.key});

  final String storeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final alerts = MockQueries.lowStockItems(storeId);

    return ShellPage(
      title: l10n.alertsTitle,
      subtitle: l10n.alertsSubtitle,
      scrollable: false,
      actions: [
        SecondaryButton(
          label: l10n.actionAddDelivery,
          icon: LucideIcons.arrowDownToLine,
          onPressed: () => context.pushScreen(Routes.toStockIn(storeId)),
        ),
      ],
      child: alerts.isEmpty
          ? EmptyState(
              icon: LucideIcons.circleCheck,
              title: l10n.alertsEmpty,
              message: l10n.alertsEmptyBody,
            )
          : ListView.separated(
              itemCount: alerts.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) =>
                  _AlertCard(item: alerts[index], storeId: storeId),
            ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.item, required this.storeId});

  final Item item;
  final String storeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final status = stockStatusOf(item);
    final colors = StockStatusBadge.colorsFor(status);
    final unit = MockQueries.unitAbbreviationOf(item.unitId);
    final shortfall = item.lowStockThreshold - item.quantity;
    final defaultPrice = MockQueries.defaultPriceForItem(item.id);

    return AppCard(
      onTap: () => context.pushScreen(Routes.toItem(storeId, item.id)),
      accentColor: colors.solid,
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  MockQueries.categoryNameOf(item.categoryId),
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          Expanded(
            flex: 3,
            child: Column(
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
                    l10n.alertsShortfall(
                      Formatters.quantityWithUnit(shortfall, unit),
                    ),
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          StockStatusBadge(status: status),
          const SizedBox(width: AppSpacing.md),

          if (defaultPrice != null)
            Flexible(
              flex: 3,
              child: SecondaryButton(
                label: l10n.alertsOrderFrom(
                  MockQueries.supplierNameOf(defaultPrice.supplierId),
                ),
                icon: LucideIcons.truck,
                onPressed: () => context.pushScreen(Routes.toStockIn(storeId)),
              ),
            ),
        ],
      ),
    );
  }
}
