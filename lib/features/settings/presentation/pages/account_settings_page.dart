import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
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
                      mockSignedInFullName
                          .split(' ')
                          .where((part) => part.isNotEmpty)
                          .take(2)
                          .map((part) => part[0])
                          .join(),
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
                          mockSignedInFullName,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          mockSignedInEmail,
                          style: theme.textTheme.bodyMedium,
                        ),
                        // The role line returns in Phase 6, when the signed-in
                        // user is a real `Employee` with a role rather than the
                        // teardown name stub.
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
              count: mockStores.length,
            ),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final store in mockStores)
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
