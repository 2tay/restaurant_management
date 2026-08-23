import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../shared/widgets/widgets.dart';

/// Sync status, and the demo toggle for offline mode.
///
/// Nothing here syncs — Phase 2 owns that — and the screen says so at the
/// bottom rather than presenting fictional timestamps as real.
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

    final isOffline = ref.watch(offlineModeProvider);
    final pending = ref.watch(pendingChangesProvider);

    return ShellPage(
      title: l10n.syncTitle,
      subtitle: l10n.syncSubtitle,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isOffline
                          ? AppColors.offlineContainer
                          : AppColors.inStock.container,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isOffline ? LucideIcons.cloudOff : LucideIcons.cloud,
                      size: 26,
                      color: isOffline
                          ? AppColors.offline
                          : AppColors.inStock.foreground,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOffline ? l10n.syncOffline : l10n.syncOnline,
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          l10n.offlineBannerPending(pending),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  PrimaryButton(
                    label: l10n.syncNow,
                    icon: LucideIcons.refreshCw,
                    onPressed: isOffline
                        ? null
                        : () => AppSnackBar.success(context, l10n.syncStarted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            AppCard(
              child: Column(
                children: [
                  _StatRow(
                    label: l10n.syncLastSynced,
                    value: Formatters.dateTime(hoursAgo(2)),
                  ),
                  const Divider(height: AppSpacing.xl),
                  _StatRow(label: l10n.syncPending, value: '$pending'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            SectionHeader(title: l10n.syncDemoToggle),
            AppCard(
              child: Row(
                children: [
                  Switch(
                    value: isOffline,
                    onChanged: (value) =>
                        ref.read(offlineModeProvider.notifier).set(value),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.syncDemoToggle,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.syncDemoToggleBody,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

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
                      l10n.syncPhase2Note,
                      style: theme.textTheme.bodySmall,
                    ),
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

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(value, style: AppTypography.numeric),
      ],
    );
  }
}
