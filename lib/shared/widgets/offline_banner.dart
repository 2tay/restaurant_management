import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/device_access.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../services/sync_service.dart';

/// Whether the app is pretending to be offline.
///
/// Local UI state, which is the only thing Riverpod is permitted to hold in
/// Phase 1. There is no connectivity check behind it — the sync status screen
/// exposes a toggle so the offline experience can be demoed on demand rather
/// than by unplugging the tablet's wifi mid-presentation.
///
/// Written as a [Notifier] rather than the older `StateProvider`, which
/// Riverpod 3 moved out of the main package.
class OfflineMode extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;

  // ignore: use_setters_to_change_properties
  void set(bool value) => state = value;
}

final offlineModeProvider = NotifierProvider<OfflineMode, bool>(
  OfflineMode.new,
);

/// Number of local changes waiting to sync: the size of the outbox, live.
///
/// Every change to shared data queues itself (SYNC_PLAN.md, Phase 2), demo
/// mode included, so the number moves during a walkthrough and the demo reset
/// puts it back to zero. Zero while the count is still loading, which is also
/// what an empty queue reads as.
final Provider<int> pendingChangesProvider = Provider<int>(
  (ref) => ref.watch(outboxPendingCountProvider).value ?? 0,
);

/// Whether the app should say it is offline (SYNC_PLAN.md, Phase 10).
///
/// On a restaurant's account device, the truth: the last sync could not reach
/// the server. In the demo, which never syncs, the switch on the sync page
/// that lets a walkthrough show the offline experience on demand.
final Provider<bool> isOfflineProvider = Provider<bool>((ref) {
  if (ref.watch(deviceAccessProvider).isAccount) {
    return ref.watch(syncControllerProvider).status == SyncStatus.offline;
  }
  return ref.watch(offlineModeProvider);
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
    final isAccount = ref.watch(deviceAccessProvider).isAccount;

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
              isAccount ? l10n.offlineBannerServer : l10n.offlineBannerTitle,
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
