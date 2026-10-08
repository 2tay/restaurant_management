import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/device_access.dart';
import '../../../../data/providers.dart';
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
/// In the demo, nothing syncs and the screen says so, with the offline
/// toggle and the demo reset. Neither is offered on an account device: the
/// reset would erase real data.
///
/// The offline toggle is the one the brief asks for explicitly: it lets the
/// offline experience be demoed on demand instead of by turning off the
/// tablet's wifi in front of a client.
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

    final isOffline = ref.watch(offlineModeProvider);
    final pending = ref.watch(pendingChangesProvider);
    final seededAt = ref.watch(seededAtProvider).value;

    return ShellPage(
      tabs: SettingsTabs(
        storeId: storeId,
        currentPath: Routes.toSyncStatus(storeId),
      ),
      tabsAboveTitle: true,
      title: l10n.syncTitle,
      subtitle: l10n.syncSubtitle,
      // Full width like the account view: the state across the page, then one
      // card per fact or setting, two per line.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SyncStatusBanner(
            icon: isOffline ? LucideIcons.cloudOff : LucideIcons.cloud,
            foreground: isOffline
                ? AppColors.offline
                : AppColors.inStock.foreground,
            background: isOffline
                ? AppColors.offlineContainer
                : AppColors.inStock.container,
            label: isOffline ? l10n.syncOffline : l10n.syncOnline,
            detail: l10n.offlineBannerPending(pending),
            onSync: isOffline
                ? null
                : () => AppSnackBar.success(context, l10n.syncStarted),
          ),
          const SizedBox(height: AppSpacing.xl),
          ResponsiveCardGrid(
            maxColumns: 2,
            equalRowHeights: true,
            children: [
              IconInfoCard(
                icon: LucideIcons.history,
                title: l10n.syncLastSynced,
                // The instant the local dataset was written, not an
                // invented one. Nothing has ever synchronised.
                value: seededAt == null ? '—' : Formatters.dateTime(seededAt),
                valueIsFigure: true,
              ),
              IconInfoCard(
                icon: LucideIcons.cloudUpload,
                title: l10n.syncPending,
                value: '$pending',
                valueIsFigure: true,
                highlighted: pending > 0,
              ),
              // The whole card toggles, as on the notification settings.
              IconInfoCard(
                icon: LucideIcons.wifiOff,
                title: l10n.syncDemoToggle,
                value: l10n.syncDemoToggleBody,
                highlighted: isOffline,
                onTap: () =>
                    ref.read(offlineModeProvider.notifier).set(!isOffline),
                trailing: Switch(
                  value: isOffline,
                  onChanged: (value) =>
                      ref.read(offlineModeProvider.notifier).set(value),
                ),
              ),
              _DemoReset(storeId: storeId),
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

/// Puts the demo data back to how it shipped.
///
/// It lives on this screen rather than behind a developer flag because it is
/// not a developer tool — a client demo gets walked several times in one
/// sitting, and the second walkthrough should not start from the first one's
/// leftovers. The only other way back is a hot restart, which is not something
/// to do in front of anybody.
///
/// This screen already exists to say "none of this is real yet", so it is the
/// honest place for it.
class _DemoReset extends ConsumerWidget {
  const _DemoReset({required this.storeId});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // Always offered now. Phase 1 disabled it until something had been
    // edited, which it could tell because every change lived in the same
    // process and vanished on restart. Changes outlive the session from this
    // phase on, so "has anything been touched?" is a question about the whole
    // history of the file rather than about this run — and a reset is
    // meaningful either way, since it puts the demo back to the dataset
    // whatever state it is in.
    return IconInfoCard(
      icon: LucideIcons.undo2,
      title: l10n.demoResetTitle,
      value: l10n.demoResetBody,
      // Its glyph alone: the card is half the page at best, and the words
      // ran off its edge at large text sizes. The tooltip names it.
      trailing: IconButton(
        onPressed: () => _confirm(context, ref, l10n),
        tooltip: l10n.demoResetConfirmAction,
        icon: const Icon(LucideIcons.undo2),
        color: AppColors.outOfStock.foreground,
        style: IconButton.styleFrom(
          backgroundColor: AppColors.outOfStock.container,
        ),
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: l10n.demoResetConfirmTitle,
      message: l10n.demoResetConfirmBody,
      confirmLabel: l10n.demoResetConfirmAction,
    );
    if (!confirmed || !context.mounted) return;

    // Wipes and re-seeds in one transaction. Every screen watching a query
    // follows, because every table changed.
    await ref.read(demoRepositoryProvider).resetDemo();

    if (!context.mounted) return;
    AppSnackBar.success(context, l10n.demoResetDone);
  }
}
