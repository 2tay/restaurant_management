import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/current_employee.dart';
import '../../data/device_access.dart';
import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import '../../services/sync_service.dart';
import 'offline_banner.dart';
import 'primary_button.dart';
import 'reconnect_account.dart';

/// Whether the account's session expired and could not be renewed: nothing
/// is sent or received until someone signs the account in again.
final Provider<bool> isSessionExpiredProvider = Provider<bool>((ref) {
  if (!ref.watch(deviceAccessProvider).isAccount) return false;
  final sync = ref.watch(syncControllerProvider);
  return sync.status == SyncStatus.error &&
      sync.problem == SyncOutcome.sessionExpired;
});

/// A red bar above every screen while the session is expired.
///
/// The device keeps working and keeps every change: signing out would lose
/// the ones not sent yet, and stop a delivery or a pointage until the owner
/// comes. But the changes no longer reach the other devices, so unlike
/// [OfflineBanner] this is an error, in red, where everyone sees it. The
/// owner or a manager reconnects from it; anyone else is told whom to ask.
class SessionExpiredBanner extends ConsumerWidget {
  const SessionExpiredBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isSessionExpiredProvider)) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pending = ref.watch(pendingChangesProvider);
    final role = ref.watch(currentEmployeeProvider)?.role;
    final canReconnect =
        role == EmployeeRole.owner || role == EmployeeRole.manager;

    return Material(
      color: AppColors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            const Icon(
              LucideIcons.cloudOff,
              size: AppSizing.iconMd,
              color: AppColors.error,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.sessionBannerTitle,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                  Text(
                    canReconnect
                        ? l10n.offlineBannerPending(pending)
                        : '${l10n.offlineBannerPending(pending)} · '
                              '${l10n.sessionBannerAskOwner}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
            if (canReconnect) ...[
              const SizedBox(width: AppSpacing.md),
              SecondaryButton(
                label: l10n.syncReconnect,
                icon: LucideIcons.logIn,
                tone: SecondaryButtonTone.surface,
                onPressed: () => reconnectAccount(context, ref),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
