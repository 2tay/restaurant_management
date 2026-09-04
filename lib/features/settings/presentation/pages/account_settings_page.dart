import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/employee_status.dart';
import '../../../../core/utils/permissions.dart';
import '../../../../data/current_employee.dart';
import '../../../../data/providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import 'store_settings_page.dart' show settingsTabs;

/// The signed-in employee's own profile, security and linked stores.
class AccountSettingsPage extends ConsumerWidget {
  const AccountSettingsPage({required this.storeId, super.key});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // The session is resolved synchronously (`currentEmployeeProvider` is a
    // `Notifier` hydrated before the first frame); only the establishment list
    // is a query.
    final user = ref.watch(currentEmployeeProvider);
    final stores = ref.watch(storesProvider);

    return ShellPage(
      tabs: SectionTabs(
        currentPath: Routes.toAccountSettings(storeId),
        tabs: settingsTabs(l10n, storeId),
      ),
      title: l10n.accountSettingsTitle,
      child: AsyncContent<List<Store>>(
        value: stores,
        skeleton: const SkeletonList(rows: 3, rowHeight: 140),
        onRetry: () => ref.invalidate(storesProvider),
        builder: (context, stores) {
          // No signed-in employee. Phase 2 always has one by the time this
          // screen is reachable — the guard sees to that — so this is the
          // branch Phase 3 will reach when nobody is signed in.
          if (user == null) return const ErrorState();
          // The owner spans stores; everyone else is scoped to their own.
          final visible = visibleStores(user, stores);
          return _body(context, l10n, theme, user, visible);
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    Employee user,
    List<Store> stores,
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: l10n.accountProfile),
          AppCard(
            // Identity block and the edit action; the action takes its own
            // line rather than squeezing the name on a phone.
            child: AdaptiveRow(
              cells: [
                AdaptiveCell(
                  flex: 1,
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
                    ],
                  ),
                ),
                AdaptiveCell(
                  child: SecondaryButton(
                    label: l10n.actionEdit,
                    icon: LucideIcons.pencil,
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          SectionHeader(title: l10n.accountSecurity),
          AppCard(
            child: AdaptiveRow(
              cells: [
                AdaptiveCell(
                  flex: 1,
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
                    ],
                  ),
                ),
                AdaptiveCell(
                  child: SecondaryButton(
                    label: l10n.accountChangePassword,
                    onPressed: () => context.goSection(Routes.forgotPassword),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          SectionHeader(title: l10n.accountLinkedStores, count: stores.length),
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
