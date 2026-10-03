import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/employee_status.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import 'attendance_status_badge.dart';
import 'employee_avatar.dart';

/// One shift still open, with the exit time a manager enters in the
/// employee's place: who, where they stand, the « Sortie à HH:MM » button
/// that opens the time picker, then [note] and [problem] under it.
///
/// Shared by « Fermer la journée » (one row per shift still in) and
/// « Corriger la sortie » in the history (the one forgotten day).
class OpenShiftExitRow extends StatelessWidget {
  const OpenShiftExitRow({
    required this.shift,
    required this.employee,
    required this.exit,
    required this.onPick,
    this.problem,
    this.note,
    this.buttonKey,
    super.key,
  });

  final Attendance shift;

  /// Null when the row's employee is gone — the name reads « — ».
  final Employee? employee;

  /// Null until one is picked — the button then reads « Choisir l'heure ».
  final DateTime? exit;
  final VoidCallback onPick;

  /// Why [exit] is impossible, in red — null when it is fine.
  final String? problem;

  /// A quiet line under the button — « le lendemain » for an exit past
  /// midnight.
  final String? note;

  /// The exit button's key, for the tests.
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final person = employee;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name and badge, the exit time beside them — or under them when the
        // dialog is narrow.
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (person != null) ...[
                  EmployeeAvatar(employee: person, size: 32),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Flexible(
                  child: Text(
                    person == null ? '—' : employeeDisplayName(person),
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AttendanceStatusBadge(status: shift.status),
              ],
            ),
            OutlinedButton.icon(
              key: buttonKey,
              onPressed: onPick,
              icon: const Icon(LucideIcons.clock, size: AppSizing.iconSm),
              label: Text(
                exit == null
                    ? l10n.attendanceCorrectExitPick
                    : l10n.timeclockCloseDayExit(Formatters.time(exit!)),
              ),
            ),
          ],
        ),
        if (note case final text?)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        if (problem case final message?)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error),
            ),
          ),
      ],
    );
  }
}
