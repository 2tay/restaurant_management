import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/device_access.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/account_sync_view.dart';
import '../widgets/settings_tabs.dart';

/// Sync status.
///
/// On a device signed in to a restaurant account, the real thing: what the
/// sync service is doing, when it last sent, what is waiting and what the
/// server refused ([AccountSyncView], SYNC_PLAN.md Phase 5).
///
/// On a device with no account (an install from before accounts), nothing
/// syncs and the screen says so: what is waiting, and where to connect the
/// account that will send it.
class SyncStatusPage extends ConsumerWidget {
  const SyncStatusPage({required this.storeId, super.key});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (ref.watch(deviceAccessProvider).isAccount) {
      return ShellPage(
        tabs: SettingsTabs(
          storeId: storeId,
          currentPath: Routes.toSyncStatus(storeId),
        ),
        tabsAboveTitle: true,
        title: l10n.syncTitle,
        subtitle: l10n.syncSubtitle,
        child: const AccountSyncView(),
      );
    }

    final pending = ref.watch(pendingChangesProvider);

    return ShellPage(
      tabs: SettingsTabs(
        storeId: storeId,
        currentPath: Routes.toSyncStatus(storeId),
      ),
      tabsAboveTitle: true,
      title: l10n.syncTitle,
      subtitle: l10n.syncSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ResponsiveCardGrid(
            maxColumns: 2,
            equalRowHeights: true,
            children: [
              IconInfoCard(
                icon: LucideIcons.cloudUpload,
                title: l10n.syncPending,
                value: '$pending',
                valueIsFigure: true,
                highlighted: pending > 0,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: AppRadius.mdAll,
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.info,
                  size: AppSizing.iconMd,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.syncLocalOnlyNote,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
