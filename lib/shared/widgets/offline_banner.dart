import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/device_access.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../services/sync_service.dart';

/// Number of local changes waiting to sync: the size of the outbox, live.
///
/// Every change to shared data queues itself (SYNC_PLAN.md, Phase 2). Zero
/// while the count is still loading, which is also what an empty queue reads
/// as.
final Provider<int> pendingChangesProvider = Provider<int>(
  (ref) => ref.watch(outboxPendingCountProvider).value ?? 0,
);

/// Whether the app should say it is offline (SYNC_PLAN.md, Phase 10).
///
/// The last sync could not reach the server. A device with no account never
/// syncs, so it is never offline in this sense.
final Provider<bool> isOfflineProvider = Provider<bool>((ref) {
  if (!ref.watch(deviceAccessProvider).isAccount) return false;
  return ref.watch(syncControllerProvider).status == SyncStatus.offline;
});

/// A slim persistent bar shown above the content area when offline.
///
/// Deliberately steel rather than red. For this app offline is the normal
/// working state in a basement kitchen with bad wifi, not an error — styling it
/// as a failure would train staff to ignore it.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isOfflineProvider);
    if (!isOffline) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final pending = ref.watch(pendingChangesProvider);

    return Material(
      color: AppColors.offlineContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            const Icon(
              LucideIcons.wifiOff,
              size: AppSizing.iconMd,
              color: AppColors.offline,
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              l10n.offlineBannerServer,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AppColors.offline),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '·',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AppColors.offline),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Wrapped so a long plural form doesn't overflow on a 7" tablet.
            Expanded(
              child: Text(
                l10n.offlineBannerPending(pending),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.offline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
