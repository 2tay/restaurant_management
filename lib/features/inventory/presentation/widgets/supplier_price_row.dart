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
/// Two marks do the analytical work — which supplier is used by default, and
/// which is cheapest. When those are not the same supplier, the store is
/// overpaying, and the two marks sitting on different rows are what say so.
/// The default is a star beside the name (its label in a tooltip); "Meilleur
/// prix" keeps its words, because it is the finding the screen exists for.
///
/// The whole row opens the price history — the one thing a row is tapped for.
/// Removing the offer is rare and destructive, so it waits behind the "⋯".
class SupplierPriceRow extends StatelessWidget {
  const SupplierPriceRow({
    required this.view,
    required this.unitAbbreviation,
    required this.isCheapest,
    required this.onViewHistory,
    this.onRemove,
    this.showDivider = true,
    super.key,
  });

  final SupplierPriceView view;
  final String unitAbbreviation;
  final bool isCheapest;
  final VoidCallback onViewHistory;
  final VoidCallback? onRemove;

  /// A hairline under the row. Off for the last row of a bordered list.
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final price = view.price;

    return InkWell(
      onTap: onViewHistory,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSizing.minTapTarget),
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
        ),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(bottom: BorderSide(color: AppColors.hairline))
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          view.supplierName,
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (price.isDefault) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Tooltip(
                          message: l10n.itemDefaultSupplier,
                          child: Semantics(
                            label: l10n.itemDefaultSupplier,
                            child: const Icon(
                              LucideIcons.star,
                              size: 16,
                              color: AppColors.primary600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xxs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        // The date alone. "Prix mis à jour le 12/03/2026" on
                        // every row is five words of scaffolding around the
                        // one that changes.
                        Formatters.date(price.effectiveDate),
                        style: theme.textTheme.bodySmall,
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
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: Formatters.price(price.pricePerUnit),
                    style: AppTypography.numeric.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: ' /$unitAbbreviation',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              maxLines: 1,
            ),
            if (onRemove != null)
              PopupMenuButton<VoidCallback>(
                tooltip: l10n.itemMoreActions,
                icon: const Icon(
                  LucideIcons.ellipsisVertical,
                  size: AppSizing.iconSm,
                ),
                onSelected: (action) => action(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: onViewHistory,
                    child: _MenuLabel(
                      icon: LucideIcons.chartLine,
                      label: l10n.itemViewPriceHistory,
                    ),
                  ),
                  PopupMenuItem(
                    value: onRemove,
                    child: _MenuLabel(
                      icon: LucideIcons.x,
                      label: l10n.actionDelete,
                      color: AppColors.error,
                    ),
                  ),
                ],
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Icon(
                  LucideIcons.chevronRight,
                  size: AppSizing.iconSm,
                  color: AppColors.textDisabled,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MenuLabel extends StatelessWidget {
  const _MenuLabel({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: AppSizing.iconSm, color: color),
        const SizedBox(width: AppSpacing.md),
        Text(label, style: TextStyle(color: color)),
      ],
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
          Flexible(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: foreground),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
