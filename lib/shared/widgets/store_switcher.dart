import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/routes.dart';
import '../../app/navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/permissions.dart';
import '../../data/current_employee.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../models/models.dart';

/// The store selector in the top bar.
///
/// Visible at all times, per the brief. Somebody who manages three locations
/// needs to be able to answer "which store am I looking at?" without
/// navigating, and needs switching to be one tap.
class StoreSwitcher extends ConsumerWidget {
  const StoreSwitcher({required this.currentStore, super.key});

  final Store currentStore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Only the owner spans stores. A manager or staff member belongs to one
    // store, so the switcher shows their store's name with no menu to open.
    final employee = ref.watch(currentEmployeeProvider);
    if (employee == null ||
        !can(employee.role, Capability.spanAllStores)) {
      return _StoreLabel(name: currentStore.name);
    }

    // The establishment being shown is already resolved — it is what the shell
    // handed down. Only the *other* entries in the menu need a query, and while
    // it is out the menu simply lists the current one: a switcher that offers
    // nowhere to go is better than one that offers nothing at all.
    final stores = ref.watch(storesProvider).value ?? [currentStore];

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
        for (final store in stores)
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

/// The non-switching variant: a manager or staff member belongs to one store,
/// so the top bar just names it — same footprint as the switcher, no chevron,
/// no tap.
class _StoreLabel extends StatelessWidget {
  const _StoreLabel({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              name,
              style: Theme.of(context).textTheme.titleSmall,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
