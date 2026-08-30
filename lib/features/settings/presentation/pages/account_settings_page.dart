import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/employee_status.dart';
import '../../../../core/utils/permissions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../shared/widgets/widgets.dart';

/// The signed-in user's own profile, security and linked stores.
class AccountSettingsPage extends StatelessWidget {
  const AccountSettingsPage({required this.storeId, super.key});

  final String storeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = mockCurrentEmployee;
    final stores = visibleStores(user, mockStores);

    return ShellPage(
      tabs: SectionTabs(
        currentPath: Routes.toAccountSettings(storeId),
        tabs: [
          SectionTab(
            label: l10n.settingsTabStore,
            path: Routes.toStoreSettings(storeId),
          ),
          SectionTab(
            label: l10n.settingsTabAccount,
            path: Routes.toAccountSettings(storeId),
          ),
          SectionTab(
            label: l10n.settingsTabNotifications,
            path: Routes.toNotificationSettings(storeId),
          ),
          SectionTab(
            label: l10n.settingsTabSync,
            path: Routes.toSyncStatus(storeId),
          ),
        ],
      ),
      title: l10n.accountSettingsTitle,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title: l10n.accountProfile),
            AppCard(
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      employeeInitials(user),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppColors.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employeeDisplayName(user),
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(user.email, style: theme.textTheme.bodyMedium),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          employeeRoleLabel(l10n, user.role),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  SecondaryButton(
                    label: l10n.actionEdit,
                    icon: LucideIcons.pencil,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            SectionHeader(title: l10n.accountSecurity),
            AppCard(
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.lock,
                    size: AppSizing.iconMd,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      l10n.accountChangePassword,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                  SecondaryButton(
                    label: l10n.accountChangePassword,
                    onPressed: () => context.goSection(Routes.forgotPassword),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            SectionHeader(
              title: l10n.accountLinkedStores,
              count: stores.length,
            ),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final store in stores)
                    ListTile(
                      leading: const Icon(LucideIcons.store),
                      title: Text(store.name),
                      subtitle: Text(
                        '${store.addressLine}, ${store.postalCode} ${store.city}',
                      ),
                      trailing: store.id == storeId
                          ? const Icon(
                              LucideIcons.circleCheck,
                              color: AppColors.primary600,
                            )
                          : const Icon(LucideIcons.chevronRight),
                      onTap: () =>
                          context.goSection(Routes.toDashboard(store.id)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
