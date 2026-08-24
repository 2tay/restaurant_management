import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/models.dart';

/// The pointage board's status indicator — built the same way
/// [StockStatusBadge] is, so the two rules that apply to every status badge
/// in the app hold here too:
///
/// 1. **Colour is never alone.** Every status carries an icon and a label.
/// 2. **The icons are distinguishable by shape**, not just by colour.
///
/// Colours are reused from the existing palette rather than invented —
/// `onShift` reads as [AppColors.inStock], `onBreak` reuses the same amber
/// [AppColors.lowStock] already means elsewhere in the app, and
/// `clockedOut` reuses the calm, informational [AppColors.offline] rather
/// than teal, which the palette reserves for primary actions only.
///
/// The wording itself is not decided here — [timeEntryStatusLabel] is the one
/// place that names a [TimeEntryStatus], and every screen showing one,
/// including this badge, calls it rather than re-deciding the strings.
class TimeEntryStatusBadge extends StatelessWidget {
  const TimeEntryStatusBadge({required this.status, super.key});

  final TimeEntryStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = colorsFor(status);
    final icon = iconFor(status);
    final label = timeEntryStatusLabel(AppLocalizations.of(context), status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.container,
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizing.iconSm, color: colors.foreground),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: colors.foreground),
          ),
        ],
      ),
    );
  }

  static StockStatusColors colorsFor(TimeEntryStatus status) =>
      switch (status) {
        TimeEntryStatus.notClockedIn => const StockStatusColors(
          solid: AppColors.textSecondary,
          foreground: AppColors.textSecondary,
          container: AppColors.surfaceVariant,
        ),
        TimeEntryStatus.onShift => AppColors.inStock,
        TimeEntryStatus.onBreak => AppColors.lowStock,
        TimeEntryStatus.clockedOut => const StockStatusColors(
          solid: AppColors.offline,
          foreground: AppColors.offline,
          container: AppColors.offlineContainer,
        ),
      };

  static IconData iconFor(TimeEntryStatus status) => switch (status) {
    TimeEntryStatus.notClockedIn => LucideIcons.circleDashed,
    TimeEntryStatus.onShift => LucideIcons.clock,
    TimeEntryStatus.onBreak => LucideIcons.coffee,
    TimeEntryStatus.clockedOut => LucideIcons.circleCheck,
  };
}

/// Shared status naming, so every screen that shows a [TimeEntryStatus]
/// agrees on the wording — the history list's plain pill and this badge both
/// call it rather than each deciding the strings independently.
///
/// Lives beside [TimeEntryStatusBadge] rather than in `core/utils/` because
/// that mirrors `StockStatusBadge`: the mapping from status to what the user
/// reads lives with the widget that renders it most prominently, not buried
/// in a derivation file.
String timeEntryStatusLabel(AppLocalizations l10n, TimeEntryStatus status) =>
    switch (status) {
      TimeEntryStatus.notClockedIn => l10n.timeEntryStatusNotClockedIn,
      TimeEntryStatus.onShift => l10n.timeEntryStatusOnShift,
      TimeEntryStatus.onBreak => l10n.timeEntryStatusOnBreak,
      TimeEntryStatus.clockedOut => l10n.timeEntryStatusClockedOut,
    };
