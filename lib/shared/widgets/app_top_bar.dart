import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/routes.dart';
import '../../app/navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../mock_data/mock_data.dart';
import '../../models/models.dart';
import 'store_switcher.dart';

/// The bar across the top of the shell: store switcher, search, notifications,
/// account.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({required this.store, super.key});

  final Store store;

  @override
  Size get preferredSize => const Size.fromHeight(AppSizing.topBarHeight);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unread = MockQueries.unreadNotificationCount(store.id);

    return Container(
      height: AppSizing.topBarHeight,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Row(
        children: [
          StoreSwitcher(currentStore: store),
          const SizedBox(width: AppSpacing.xl),

          // The search field takes the slack. On narrow tablets it collapses to
          // an icon so the store name and the account controls keep their room.
          if (context.isRailCollapsed)
            IconButton(
              onPressed: () => context.pushScreen(Routes.toSearch(store.id)),
              icon: const Icon(LucideIcons.search),
              tooltip: l10n.actionSearch,
            )
          else
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: _SearchAffordance(storeId: store.id),
              ),
            ),

          const Spacer(),

          _NotificationBell(storeId: store.id, unreadCount: unread),
          const SizedBox(width: AppSpacing.sm),
          _AccountButton(storeId: store.id),
        ],
      ),
    );
  }
}

/// Looks like a text field but navigates to the search screen on tap.
///
/// A real field here would need its own state and would compete with the search
/// screen's own field. This is a button wearing a field's clothes, which is
/// what the user expects to see and costs nothing to maintain.
class _SearchAffordance extends StatelessWidget {
  const _SearchAffordance({required this.storeId});

  final String storeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return InkWell(
      onTap: () => context.pushScreen(Routes.toSearch(storeId)),
      borderRadius: AppRadius.mdAll,
      child: Container(
        height: AppSizing.minTapTarget,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              LucideIcons.search,
              size: AppSizing.iconMd,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            // Expanded so the placeholder ellipsizes instead of overflowing
            // when the top bar gets tight. This sits in flexible space, so its
            // width is never something this widget can assume.
            Expanded(
              child: Text(
                l10n.actionSearch,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.textDisabled),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.storeId, required this.unreadCount});

  final String storeId;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () => context.pushScreen(Routes.toNotifications(storeId)),
          icon: const Icon(LucideIcons.bell),
          tooltip: l10n.topBarNotifications,
        ),
        if (unreadCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 1,
              ),
              // Sized for a 13pt numeral rather than shrinking the text: the
              // readable floor applies to the unread count too.
              constraints: const BoxConstraints(minWidth: 22),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: AppRadius.pillAll,
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
              child: Text(
                '$unreadCount',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppColors.white),
              ),
            ),
          ),
      ],
    );
  }
}

class _AccountButton extends StatelessWidget {
  const _AccountButton({required this.storeId});

  final String storeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = mockCurrentUser;
    final initials = user.fullName
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join();

    return PopupMenuButton<String>(
      tooltip: l10n.topBarAccount,
      offset: const Offset(0, AppSizing.minTapTarget),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      onSelected: (value) {
        switch (value) {
          case 'account':
            context.goSection(Routes.toAccountSettings(storeId));
          case 'logout':
            context.goSection(Routes.login);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(user.fullName, style: Theme.of(context).textTheme.bodyLarge),
              Text(user.email, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'account',
          child: Row(
            children: [
              const Icon(LucideIcons.user, size: AppSizing.iconMd),
              const SizedBox(width: AppSpacing.md),
              Text(l10n.topBarAccount),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              const Icon(LucideIcons.logOut, size: AppSizing.iconMd),
              const SizedBox(width: AppSpacing.md),
              Text(l10n.actionLogout),
            ],
          ),
        ),
      ],
      child: Container(
        width: AppSizing.minTapTarget,
        height: AppSizing.minTapTarget,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Text(
          initials,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: AppColors.onPrimaryContainer),
        ),
      ),
    );
  }
}
