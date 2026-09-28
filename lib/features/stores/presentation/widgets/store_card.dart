import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/widgets.dart';

/// One store on the selector grid.
///
/// Carries the alert count as a badge, so an owner with three locations can see
/// which one needs them before choosing — that is the entire point of showing
/// them a grid rather than dropping them into the last store they opened.
class StoreCard extends StatelessWidget {
  const StoreCard({required this.view, required this.onTap, super.key});

  final StoreCardView view;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final store = view.store;
    final itemCount = view.itemCount;
    final alertCount = view.lowStockCount;
    final isNew = itemCount == 0;

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A generated tile rather than a photo. Every store has one, they load
          // instantly, and a real logo can replace it later without the layout
          // changing.
          Container(
            height: 120,
            width: double.infinity,
            color: AppColors.steel700,
            alignment: Alignment.center,
            child: const Icon(
              LucideIcons.store,
              size: 44,
              color: AppColors.neutral300,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        store.name,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isNew) ...[
                      const SizedBox(width: AppSpacing.sm),
                      LabelChip(
                        label: l10n.storesNewBadge,
                        background: AppColors.primaryContainer,
                        foreground: AppColors.onPrimaryContainer,
                        dense: true,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.mapPin,
                      size: AppSizing.iconSm,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        '${store.addressLine}, ${store.postalCode} ${store.city}',
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    // Bounded to one line. The grid gives every card the same
                    // fixed height, so a count that wraps to two lines at a
                    // narrow column width pushes the card past it — which is
                    // how the selector overflowed at 600dp, where three
                    // columns become two of 254dp each.
                    Expanded(
                      child: Text(
                        l10n.storesItemCount(itemCount),
                        style: theme.textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (alertCount > 0)
                      LabelChip(
                        label: l10n.storesAlertCount(alertCount),
                        background: AppColors.lowStock.container,
                        foreground: AppColors.lowStock.foreground,
                        icon: LucideIcons.triangleAlert,
                        dense: true,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.storesCreatedOn(Formatters.date(store.createdAt)),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textDisabled,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
