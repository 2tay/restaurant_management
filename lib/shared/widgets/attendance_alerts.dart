import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/attendance_status.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../models/models.dart';

/// The short name of one anomaly — the attendance table's "Alertes" column.
String attendanceAnomalyLabel(AppLocalizations l10n, AttendanceAnomaly a) =>
    switch (a) {
      AttendanceAnomaly.retard => l10n.attendanceLate,
      AttendanceAnomaly.pauseDepassee => l10n.attendanceBreakOverrun,
      AttendanceAnomaly.oubliDePointage => l10n.attendanceAnomalyMissingPunch,
    };

/// The full sentence for one anomaly — the detail drawer. Carries the amount
/// where there is one ("Retard de 20 min").
String attendanceAnomalyDetail(
  AppLocalizations l10n,
  AttendanceAnomaly a,
  Attendance entry, {
  required int startMinutes,
  required int maxBreakMinutes,
}) => switch (a) {
  AttendanceAnomaly.retard => l10n.attendanceAnomalyRetardDetail(
    Formatters.duration(lateBy(entry, startMinutes) ?? Duration.zero),
  ),
  AttendanceAnomaly.pauseDepassee => l10n.attendanceAnomalyBreakDetail(
    Formatters.duration(totalBreakOverrun(entry, maxBreakMinutes)),
  ),
  AttendanceAnomaly.oubliDePointage => l10n.attendanceAnomalyMissingPunchDetail,
};

/// The anomalies of a day, or a dash. Compact amber chips in a table cell;
/// icon + full sentence rows when [detailed] (the drawer).
class AttendanceAlerts extends StatelessWidget {
  const AttendanceAlerts({
    required this.entry,
    required this.startMinutes,
    required this.maxBreakMinutes,
    this.detailed = false,
    this.now,
    super.key,
  });

  final Attendance entry;
  final int startMinutes;
  final int maxBreakMinutes;
  final bool detailed;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final anomalies = attendanceAnomalies(
      entry,
      startMinutes: startMinutes,
      maxBreakMinutes: maxBreakMinutes,
      now: now,
    );

    if (anomalies.isEmpty) {
      return Text(
        '—',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
      );
    }

    if (detailed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final a in anomalies)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.lowStock.foreground.withValues(alpha: 0.1),
                  borderRadius: AppRadius.mdAll,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      LucideIcons.triangleAlert,
                      size: AppSizing.iconSm,
                      color: AppColors.lowStock.foreground,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        attendanceAnomalyDetail(
                          l10n,
                          a,
                          entry,
                          startMinutes: startMinutes,
                          maxBreakMinutes: maxBreakMinutes,
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final a in anomalies)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.lowStock.container,
              borderRadius: AppRadius.pillAll,
            ),
            child: Text(
              attendanceAnomalyLabel(l10n, a),
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.lowStock.foreground,
              ),
            ),
          ),
      ],
    );
  }
}
