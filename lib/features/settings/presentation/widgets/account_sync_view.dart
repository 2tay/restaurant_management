import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
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
    final theme = Theme.of(context);
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

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: AdaptiveRow(
              cells: [
                AdaptiveCell(
                  flex: 1,
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: background,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 26, color: foreground),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: theme.textTheme.titleLarge),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              l10n.offlineBannerPending(pending),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                AdaptiveCell(
                  child: PrimaryButton(
                    label: l10n.syncNow,
                    icon: LucideIcons.refreshCw,
                    isBusy: sync.status == SyncStatus.syncing,
                    onPressed: sync.status == SyncStatus.syncing
                        ? null
                        : () => _syncNow(context, ref),
                  ),
                ),
              ],
            ),
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
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              children: [
                _Stat(
                  label: l10n.syncLastSynced,
                  value: sync.lastSyncAt == null
                      ? l10n.syncLastSyncedNever
                      : Formatters.dateTime(sync.lastSyncAt!),
                ),
                const Divider(height: AppSpacing.xl),
                _Stat(label: l10n.syncPending, value: '$pending'),
                const Divider(height: AppSpacing.xl),
                _Stat(
                  label: l10n.syncPhotosPending,
                  value: '${ref.watch(photoUploadsPendingProvider).value ?? 0}',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              children: [
                _Stat(
                  label: l10n.syncRestaurantLabel,
                  value: access.organizationName ?? '',
                ),
                const Divider(height: AppSpacing.xl),
                _Stat(
                  label: l10n.syncAccountLabel,
                  value: access.accountEmail ?? '',
                ),
                const Divider(height: AppSpacing.xl),
                _Stat(label: l10n.syncDeviceLabel, value: deviceDisplayName()),
              ],
            ),
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
      ),
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

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AdaptiveRow(
      breakpoint: 360,
      crossAxisAlignment: CrossAxisAlignment.start,
      cells: [
        AdaptiveCell(
          flex: 1,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ),
        AdaptiveCell(child: Text(value, style: AppTypography.numeric)),
      ],
    );
  }
}
