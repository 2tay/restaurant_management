import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/device_access.dart';
import '../../../../data/providers.dart';
import '../../../../data/repositories/sync_error_repository.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/sync_service.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/presentation/widgets/auth_notice.dart';

/// The sync page of an account device (SYNC_PLAN.md, Phase 5): what the sync
/// service is doing, when it last sent, what waits, and what the server
/// refused. The full design of this page is Phase 10.
class AccountSyncView extends ConsumerWidget {
  const AccountSyncView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sync = ref.watch(syncControllerProvider);
    final pending = ref.watch(pendingChangesProvider);
    final rejected = ref.watch(syncErrorsProvider).value ?? const [];
    final access = ref.watch(deviceAccessProvider);

    final (
      IconData icon,
      Color foreground,
      Color background,
      String label,
    ) = switch (sync.status) {
      SyncStatus.idle => (
        LucideIcons.cloudCheck,
        AppColors.inStock.foreground,
        AppColors.inStock.container,
        l10n.syncStateIdle,
      ),
      SyncStatus.syncing => (
        LucideIcons.refreshCw,
        AppColors.primary600,
        AppColors.primaryContainer,
        l10n.syncStateSyncing,
      ),
      SyncStatus.offline => (
        LucideIcons.cloudOff,
        AppColors.offline,
        AppColors.offlineContainer,
        l10n.syncStateOffline,
      ),
      SyncStatus.error => (
        LucideIcons.cloudAlert,
        AppColors.outOfStock.foreground,
        AppColors.outOfStock.container,
        l10n.syncStateError,
      ),
      SyncStatus.disabled => (
        LucideIcons.cloud,
        AppColors.textSecondary,
        AppColors.surfaceVariant,
        l10n.syncStateDisabled,
      ),
    };

    // Full width: the state is the point of the page. The figures under it
    // are cards, two per line, as on the notification settings.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SyncStatusBanner(
          icon: icon,
          foreground: foreground,
          background: background,
          label: label,
          detail: l10n.offlineBannerPending(pending),
          busy: sync.status == SyncStatus.syncing,
          onSync: sync.status == SyncStatus.syncing
              ? null
              : () => _syncNow(context, ref),
        ),
        if (_problemText(l10n, sync) case final problem?) ...[
          const SizedBox(height: AppSpacing.lg),
          AuthNotice.error(problem),
          if (sync.problem == SyncOutcome.sessionExpired) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: SecondaryButton(
                label: l10n.syncReconnect,
                icon: LucideIcons.logIn,
                onPressed: () => _reconnect(context, ref),
              ),
            ),
          ],
        ],
        const SizedBox(height: AppSpacing.xl),
        ResponsiveCardGrid(
          maxColumns: 2,
          equalRowHeights: true,
          children: [
            IconInfoCard(
              icon: LucideIcons.history,
              title: l10n.syncLastSynced,
              value: sync.lastSyncAt == null
                  ? l10n.syncLastSyncedNever
                  : Formatters.dateTime(sync.lastSyncAt!),
              valueIsFigure: true,
            ),
            IconInfoCard(
              icon: LucideIcons.cloudUpload,
              title: l10n.syncPending,
              value: '$pending',
              valueIsFigure: true,
              highlighted: pending > 0,
            ),
            IconInfoCard(
              icon: LucideIcons.image,
              title: l10n.syncPhotosPending,
              value: '${ref.watch(photoUploadsPendingProvider).value ?? 0}',
              valueIsFigure: true,
            ),
            IconInfoCard(
              icon: LucideIcons.store,
              title: l10n.syncRestaurantLabel,
              value: access.organizationName ?? '',
              valueIsFigure: true,
            ),
            IconInfoCard(
              icon: LucideIcons.mail,
              title: l10n.syncAccountLabel,
              value: access.accountEmail ?? '',
              valueIsFigure: true,
            ),
            IconInfoCard(
              icon: LucideIcons.tablet,
              title: l10n.syncDeviceLabel,
              value: deviceDisplayName(),
              valueIsFigure: true,
            ),
          ],
        ),
        if (rejected.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: l10n.syncRejectedTitle,
            count: rejected.length,
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final error in rejected)
                  ListTile(
                    leading: Icon(
                      error.isResolution
                          ? LucideIcons.gitMerge
                          : LucideIcons.circleAlert,
                      color: error.isResolution
                          ? AppColors.lowStock.foreground
                          : AppColors.outOfStock.foreground,
                    ),
                    title: Text(l10n.syncTableName(error.table)),
                    subtitle: Text(
                      '${_reasonText(l10n, error)} · '
                      '${Formatters.dateTime(error.rejectedAt)}',
                    ),
                    trailing: TextButton(
                      onPressed: () => ref
                          .read(syncErrorRepositoryProvider)
                          .dismiss(error.id),
                      child: Text(l10n.syncRejectedDismiss),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static String? _problemText(AppLocalizations l10n, SyncState sync) =>
      switch (sync.status) {
        SyncStatus.offline => l10n.syncProblemOffline,
        SyncStatus.error => switch (sync.problem) {
          SyncOutcome.sessionExpired => l10n.syncProblemSessionExpired,
          SyncOutcome.deviceRemoved => l10n.syncProblemDeviceRemoved,
          _ => l10n.syncProblemFailed,
        },
        _ => null,
      };

  static String _reasonText(AppLocalizations l10n, RejectedChange error) =>
      switch (error.reason) {
        'deleted' => l10n.syncReasonDeleted,
        'status_backwards' => l10n.syncReasonStatusBackwards,
        'status_closed' => l10n.syncReasonStatusClosed,
        'already_paid' => l10n.syncReasonAlreadyPaid,
        'day_already_paid' => l10n.syncReasonDayAlreadyPaid,
        'paid_day_frozen' => l10n.syncReasonPaidDayFrozen,
        'no_access' => l10n.syncReasonNoAccess,
        'owner_only' => l10n.syncReasonOwnerOnly,
        'store_changed' => l10n.syncReasonStoreChanged,
        'receive_conflict' => l10n.syncReasonReceiveConflict,
        'resolved_double_clock_in' => l10n.syncResolvedDoubleClockIn(
          (error.details['employee'] as String?) ?? '',
          switch (DateTime.tryParse((error.details['date'] as String?) ?? '')) {
            final date? => Formatters.date(date),
            null => '',
          },
        ),
        'resolved_double_business_day' => l10n.syncResolvedDoubleBusinessDay(
          switch (DateTime.tryParse((error.details['date'] as String?) ?? '')) {
            final date? => Formatters.date(date),
            null => '',
          },
        ),
        'resolved_duplicate_link' => l10n.syncResolvedDuplicateLink,
        _ => l10n.syncReasonInvalid,
      };

  Future<void> _syncNow(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final result = await ref.read(syncControllerProvider.notifier).syncNow();
    if (!context.mounted || result.outcome != SyncOutcome.done) return;
    if (result.rejected > 0) {
      AppSnackBar.warning(
        context,
        l10n.syncDoneWithRejections(result.rejected),
      );
    } else {
      AppSnackBar.success(context, l10n.syncDone);
    }
  }

  /// Signs the account in again after its session expired, without wiping
  /// anything, then resumes sending.
  Future<void> _reconnect(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final email = ref.read(deviceAccessProvider).accountEmail ?? '';
    final password = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.syncReconnectTitle),
        content: AppTextField(
          label: l10n.syncReconnectBody(email),
          controller: password,
          obscureText: true,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.syncReconnect),
          ),
        ],
      ),
    );
    final typed = password.text;
    password.dispose();
    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(accountBackendProvider)
          .signIn(email: email, password: typed);
      await ref.read(syncControllerProvider.notifier).syncNow();
    } catch (error) {
      if (context.mounted) {
        AppSnackBar.warning(context, accountErrorMessage(l10n, error));
      }
    }
  }
}

/// The sync state across the whole page width: a tinted round icon, the state
/// and what waits, and « Synchroniser maintenant » — reduced to its icon, still
/// green, below a medium screen ([ResponsiveContext.isSmallScreen]) so the
/// state keeps the line.
///
/// Shared by the account view and the demo page.
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({
    required this.icon,
    required this.foreground,
    required this.background,
    required this.label,
    required this.detail,
    required this.onSync,
    this.busy = false,
    super.key,
  });

  final IconData icon;
  final Color foreground;
  final Color background;
  final String label;
  final String detail;

  /// Null disables the button.
  final VoidCallback? onSync;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final small = context.isSmallScreen;

    final Widget button = small
        ? Tooltip(
            message: l10n.syncNow,
            child: Semantics(
              label: l10n.syncNow,
              button: true,
              child: FilledButton(
                key: const ValueKey('sync-now'),
                onPressed: busy ? null : onSync,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  fixedSize: const Size.square(AppSizing.minTapTarget),
                ),
                child: busy
                    ? const SizedBox.square(
                        dimension: AppSizing.iconSm,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.refreshCw, size: AppSizing.iconMd),
              ),
            ),
          )
        : PrimaryButton(
            key: const ValueKey('sync-now'),
            label: l10n.syncNow,
            icon: LucideIcons.refreshCw,
            isBusy: busy,
            onPressed: onSync,
          );

    return AppCard(
      bordered: false,
      child: Row(
        children: [
          Container(
            width: small ? 44 : 56,
            height: small ? 44 : 56,
            decoration: BoxDecoration(color: background, shape: BoxShape.circle),
            child: Icon(icon, size: small ? 22 : 26, color: foreground),
          ),
          SizedBox(width: small ? AppSpacing.md : AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: small
                      ? theme.textTheme.titleMedium
                      : theme.textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(detail, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          button,
        ],
      ),
    );
  }
}
