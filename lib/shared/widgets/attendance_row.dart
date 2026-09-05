import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/attendance_status.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import 'adaptive_row.dart';
import 'app_card.dart';
import 'attendance_status_badge.dart';

/// One day's attendance line: date, the timestamps as a readable strip,
/// worked duration, the status badge and a late marker.
///
/// Shared by the employee detail page (one person, [employeeName] omitted)
/// and Phase 4's Historique table ([employeeName] set, [asCard] on so each
/// row is its own card in a separated list — the same shape `MovementRow`
/// uses).
class AttendanceRow extends StatelessWidget {
  const AttendanceRow({
    required this.attendance,
    required this.scheduledStartMinutes,
    required this.maxBreakMinutes,
    this.employeeName,
    this.asCard = false,
    super.key,
  });

  final Attendance attendance;

  /// The resolved start of day this row is measured against, for the late
  /// marker. See `resolvedSchedule`.
  final int scheduledStartMinutes;

  /// The store's break allowance, for the "pause dépassée" marker.
  final int maxBreakMinutes;

  final String? employeeName;
  final bool asCard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final worked = workedDuration(attendance);
    final late = isLate(attendance, scheduledStartMinutes);
    final lateBreak = hasLateBreak(attendance, maxBreakMinutes);
    final name = employeeName;

    final markers = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (late)
          Tooltip(
            message: l10n.attendanceLate,
            child: Icon(
              LucideIcons.triangleAlert,
              size: AppSizing.iconSm,
              color: AppColors.lowStock.foreground,
            ),
          ),
        if (lateBreak) ...[
          if (late) const SizedBox(width: AppSpacing.xs),
          Tooltip(
            message: l10n.attendanceBreakOverrun,
            child: Icon(
              LucideIcons.coffee,
              size: AppSizing.iconSm,
              color: AppColors.lowStock.foreground,
            ),
          ),
        ],
      ],
    );

    // Flex shares rather than fixed widths. This was five `SizedBox`es adding
    // up to ~546dp plus gaps, which is correct at the 1280dp baseline and
    // overflows below about 700 — and the whole row is inside a detail pane on
    // the split view, which is narrower still. Proportions keep the columns
    // lining up down the list without promising a width the window may not
    // have; below [AdaptiveRow]'s breakpoint each part takes its own line.
    //
    // Six columns need more room than the default phone threshold to stay
    // legible, so the breakpoint is raised to the width the fixed layout
    // actually needed.
    final content = AdaptiveRow(
      breakpoint: 640,
      spacing: AppSpacing.md,
      cells: [
        if (name != null)
          AdaptiveCell(
            flex: 4,
            child: Text(
              name,
              style: theme.textTheme.bodyLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        AdaptiveCell(
          flex: 3,
          child: Text(
            Formatters.date(attendance.date),
            style: theme.textTheme.bodyLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        AdaptiveCell(
          flex: 5,
          child: Text(
            _timesLine(),
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        AdaptiveCell(
          flex: 2,
          child: Text(
            worked == null ? '—' : Formatters.duration(worked),
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        AdaptiveCell(
          flex: 4,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AttendanceStatusBadge(status: attendance.status),
          ),
        ),
        AdaptiveCell(child: markers),
      ],
    );

    if (asCard) {
      return AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: content,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: content,
    );
  }

  String _timesLine() {
    final parts = <String>[];
    if (attendance.clockInAt != null) {
      parts.add(Formatters.time(attendance.clockInAt!));
    }
    for (final pause in attendance.pauses) {
      final end = pause.endAt == null ? '…' : Formatters.time(pause.endAt!);
      parts.add('${Formatters.time(pause.startAt)}–$end');
    }
    if (attendance.clockOutAt != null) {
      parts.add(Formatters.time(attendance.clockOutAt!));
    }
    return parts.isEmpty ? '—' : parts.join(' · ');
  }
}
