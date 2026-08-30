import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../l10n/app_localizations.dart';

/// One supplier's offer for an item.
///
/// This row is where the app's central domain rule becomes visible: the same
/// product, several suppliers, a different price each. An item has no single
/// cost, and the item detail screen shows a list of these instead of one
/// number.
///
/// Two badges do the analytical work — which supplier is used by default, and
/// which is cheapest. When those are not the same supplier, the store is
/// overpaying, and the screen above this row says so in euros.
class SupplierPriceRow extends StatelessWidget {
  const SupplierPriceRow({
    required this.view,
    required this.unitAbbreviation,
    required this.isCheapest,
    required this.onViewHistory,
    this.onRemove,
    super.key,
  });

  final SupplierPriceView view;
  final String unitAbbreviation;
  final bool isCheapest;
  final VoidCallback onViewHistory;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final price = view.price;

    return Container(
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
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A Wrap, not a Row. An item can carry both badges at once —
                // the default supplier that is also the cheapest — and on a
                // narrow pane the name plus two tags does not fit one line.
                // Wrapping drops the tags below the name instead of clipping
                // them, and they are exactly the part that must stay readable.
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      view.supplierName,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (price.isDefault)
                      _Tag(
                        label: l10n.itemDefaultSupplier,
                        background: AppColors.primaryContainer,
                        foreground: AppColors.onPrimaryContainer,
                        icon: LucideIcons.star,
                      ),
                    if (isCheapest)
                      _Tag(
                        label: l10n.itemCheapest,
                        background: AppColors.inStock.container,
                        foreground: AppColors.inStock.foreground,
                        icon: LucideIcons.trendingDown,
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.itemPriceUpdated(Formatters.date(price.effectiveDate)),
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${Formatters.price(price.pricePerUnit)} / $unitAbbreviation',
                style: AppTypography.numeric,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            onPressed: onViewHistory,
            icon: const Icon(LucideIcons.chartLine),
            tooltip: l10n.itemViewPriceHistory,
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(LucideIcons.unlink),
              tooltip: l10n.actionDelete,
              color: AppColors.error,
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: foreground),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
