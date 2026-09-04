import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import 'status_pill.dart';

/// The pointage status indicator — built the same way [StockStatusBadge] is,
/// so the two rules that apply to every status badge in the app hold here too:
///
/// 1. **Colour is never alone.** Every status carries an icon and a label.
/// 2. **The icons are distinguishable by shape**, not just by colour.
///
/// Colours are reused from the existing palette rather than invented.
class AttendanceStatusBadge extends StatelessWidget {
  const AttendanceStatusBadge({required this.status, super.key});

  final AttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = colorsFor(status);

    return StatusPill(
      colors: colors,
      icon: iconFor(status),
      label: attendanceStatusLabel(AppLocalizations.of(context), status),
    );
  }

  static StockStatusColors colorsFor(AttendanceStatus status) => switch (status) {
    AttendanceStatus.notClockedIn => const StockStatusColors(
      solid: AppColors.textSecondary,
      foreground: AppColors.textSecondary,
      container: AppColors.surfaceVariant,
    ),
    AttendanceStatus.working => AppColors.inStock,
    AttendanceStatus.onBreak => AppColors.onBreak,
    AttendanceStatus.done => const StockStatusColors(
      solid: AppColors.offline,
      foreground: AppColors.offline,
      container: AppColors.offlineContainer,
    ),
  };

  static IconData iconFor(AttendanceStatus status) => switch (status) {
    AttendanceStatus.notClockedIn => LucideIcons.circleDashed,
    AttendanceStatus.working => LucideIcons.clock,
    AttendanceStatus.onBreak => LucideIcons.coffee,
    AttendanceStatus.done => LucideIcons.circleCheck,
  };
}

/// Shared status naming, so every screen that shows an [AttendanceStatus]
/// agrees on the wording. Lives beside the badge rather than in `core/utils/`,
/// mirroring `StockStatusBadge`.
String attendanceStatusLabel(AppLocalizations l10n, AttendanceStatus status) =>
    switch (status) {
      AttendanceStatus.notClockedIn => l10n.attendanceStatusNotClockedIn,
      AttendanceStatus.working => l10n.attendanceStatusWorking,
      AttendanceStatus.onBreak => l10n.attendanceStatusOnBreak,
      AttendanceStatus.done => l10n.attendanceStatusDone,
    };
