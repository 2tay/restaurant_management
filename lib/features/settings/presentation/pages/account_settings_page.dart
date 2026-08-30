import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../team/presentation/pages/team_list_page.dart';
import 'store_settings_page.dart';

/// The signed-in user's own profile, security and linked stores.
class AccountSettingsPage extends ConsumerWidget {
  const AccountSettingsPage({required this.storeId, super.key});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final data = asyncAll2(
      ref.watch(currentUserProvider),
      ref.watch(storesProvider),
      (user, stores) => (user: user, stores: stores),
    );

    return ShellPage(
      tabs: SectionTabs(
        currentPath: Routes.toAccountSettings(storeId),
        tabs: settingsTabs(l10n, storeId),
      ),
      title: l10n.accountSettingsTitle,
      child: AsyncContent<({TeamMember? user, List<Store> stores})>(
        value: data,
        skeleton: const SkeletonList(rows: 3, rowHeight: 140),
        onRetry: () {
          ref.invalidate(currentUserProvider);
          ref.invalidate(storesProvider);
        },
        builder: (context, data) => _body(context, l10n, theme, data),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    ({TeamMember? user, List<Store> stores}) data,
  ) {
    final user = data.user;
    final stores = data.stores;
    // No current member. Phase 2 always has one — the seed writes it — so this
    // is the branch Phase 3 will reach when nobody is signed in.
    if (user == null) return const ErrorState();

    return ConstrainedBox(
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
                    user.fullName
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
                      Text(user.fullName, style: theme.textTheme.titleMedium),
                      Text(user.email, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        roleLabel(l10n, user.role),
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
    );
  }
}
