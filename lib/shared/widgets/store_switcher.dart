import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/routes.dart';
import '../../app/navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../mock_data/mock_data.dart';
import '../../models/models.dart';

/// The store selector in the top bar.
///
/// Visible at all times, per the brief. Somebody who manages three locations
/// needs to be able to answer "which store am I looking at?" without
/// navigating, and needs switching to be one tap.
class StoreSwitcher extends StatelessWidget {
  const StoreSwitcher({required this.currentStore, super.key});

  final Store currentStore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return PopupMenuButton<String>(
      tooltip: l10n.storeSwitcherChange,
      offset: const Offset(0, AppSizing.minTapTarget),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      onSelected: (value) {
        if (value == _allStoresValue) {
          context.goSection(Routes.stores);
        } else {
          context.goSection(Routes.toDashboard(value));
        }
      },
      itemBuilder: (context) => [
        for (final store in mockStores)
          PopupMenuItem<String>(
            value: store.id,
            child: Row(
              children: [
                Icon(
                  store.id == currentStore.id
                      ? LucideIcons.circleCheck
                      : LucideIcons.store,
                  size: AppSizing.iconMd,
                  color: store.id == currentStore.id
                      ? AppColors.primary600
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(store.name, style: theme.textTheme.bodyLarge),
                    Text(store.city, style: theme.textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: _allStoresValue,
          child: Row(
            children: [
              const Icon(LucideIcons.layoutGrid, size: AppSizing.iconMd),
              const SizedBox(width: AppSpacing.md),
              Text(l10n.storeSwitcherChange),
            ],
          ),
        ),
      ],
      child: Container(
        height: AppSizing.minTapTarget,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.store,
              size: AppSizing.iconMd,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            // Constrained rather than fixed: store names vary a lot in length
            // and the top bar must not push its other controls off screen.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                currentStore.name,
                style: theme.textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              LucideIcons.chevronDown,
              size: AppSizing.iconSm,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  static const String _allStoresValue = '__all__';
}
