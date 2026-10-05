import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/attendance_status.dart';
import '../../core/utils/employee_status.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import 'attendance_alerts.dart';
import 'attendance_status_badge.dart';
import 'attendance_timeline.dart';
import 'day_summary_table.dart';
import 'employee_avatar.dart';

/// One day of pointage, as both pointage drawers show it — the history's and
/// the board's:
///
/// 1. who (avatar, name, the bare PIN when [showPin]) with the day's status;
/// 2. the day ([date], or whatever [dateLine] puts in its place — the board's
///    ticking date and time), and a line saying what the rest shows;
/// 3. the sessions, untitled;
/// 4. a line introducing the day's summary, then a two-by-two table — time
///    worked, and the breaks;
/// 5. « Alertes », only when there is at least one.
class AttendanceDayDetail extends StatelessWidget {
  const AttendanceDayDetail({
    required this.entry,
    required this.maxBreakMinutes,
    this.employee,
    this.showPin = true,
    this.dateLine,
    this.now,
    this.exitAuthors = const {},
    this.openBusinessDay,
    super.key,
  });

  final Attendance entry;
  final int maxBreakMinutes;

  /// Null when the row's employee is gone — the status badge stands alone.
  final Employee? employee;

  /// False on the shared kiosk, where the PIN is what confirms an action.
  final bool showPin;

  /// Replaces the plain [AttendanceDayDate] of the row's date.
  final Widget? dateLine;

  /// Pins "today" for the oubli-de-pointage rule in tests.
  final DateTime? now;

  /// Display names by employee id — see [AttendanceSessions.exitAuthors].
  final Map<String, String> exitAuthors;

  /// The open journée's date, so a shift still in service past midnight is
  /// not shown as an oubli de pointage — see [attendanceAnomalies].
  final DateTime? openBusinessDay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final worked = workedDuration(entry);
    final hasAlerts = attendanceAnomalies(
      entry,
      maxBreakMinutes: maxBreakMinutes,
      now: now,
      openBusinessDay: openBusinessDay,
    ).isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AttendanceIdentityRow(
          employee: employee,
          status: entry.status,
          showPin: showPin,
        ),
        const SizedBox(height: AppSpacing.xl),
        dateLine ?? AttendanceDayDate(date: entry.date),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.attendanceDayIntro,
          key: const ValueKey('attendance-day-intro'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        AttendanceSessions(
          entry: entry,
          maxBreakMinutes: maxBreakMinutes,
          exitAuthors: exitAuthors,
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          l10n.attendanceDaySummary,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        DaySummaryTable(
          key: const ValueKey('attendance-day-summary'),
          rows: [
            DaySummaryRow(
              valueKey: const ValueKey('attendance-day-worked'),
              label: l10n.attendanceTotalWorked,
              value: worked == null ? '—' : Formatters.duration(worked),
            ),
            DaySummaryRow(
              valueKey: const ValueKey('attendance-day-pauses'),
              label: l10n.attendancePausesCount(totalPauseCount(entry)),
              value: Formatters.duration(totalBreak(entry)),
            ),
          ],
        ),
        if (hasAlerts) ...[
          const SizedBox(height: AppSpacing.xxl),
          _SectionTitle(l10n.attendanceColumnFlags),
          const SizedBox(height: AppSpacing.md),
          AttendanceAlerts(
            key: const ValueKey('attendance-day-alerts'),
            entry: entry,
            maxBreakMinutes: maxBreakMinutes,
            detailed: true,
            now: now,
            openBusinessDay: openBusinessDay,
          ),
        ],
      ],
    );
  }
}

/// Avatar, name and — when [showPin] — the bare PIN under it, the day's
/// status at the right: its pointage status, or whatever [badge] puts there
/// instead (the payment drawer's paid / unpaid).
class AttendanceIdentityRow extends StatelessWidget {
  const AttendanceIdentityRow({
    required this.employee,
    this.status,
    this.badge,
    this.showPin = true,
    super.key,
  }) : assert(status != null || badge != null);

  final Employee? employee;
  final AttendanceStatus? status;

  /// Replaces the [AttendanceStatusBadge] of [status].
  final Widget? badge;
  final bool showPin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trailing = badge ?? AttendanceStatusBadge(status: status!);
    final who = employee;
    if (who == null) {
      return Align(alignment: Alignment.centerRight, child: trailing);
    }
    return Row(
      children: [
        EmployeeAvatar(employee: who),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(employeeDisplayName(who), style: theme.textTheme.titleSmall),
              if (showPin)
                Text(
                  maskedPin(who.pin),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        trailing,
      ],
    );
  }
}

/// `📅 Jeudi 24/12/2026`, with room for more after it ([trailing] — the
/// board's live time).
class AttendanceDayDate extends StatelessWidget {
  const AttendanceDayDate({required this.date, this.trailing, super.key});

  final DateTime date;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      key: const ValueKey('attendance-day-date'),
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.calendar,
              size: AppSizing.iconSm,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              Formatters.dateLongWeekday(date),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        ?trailing,
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.titleSmall);
}
