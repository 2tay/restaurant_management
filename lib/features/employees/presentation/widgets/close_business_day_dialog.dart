import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/employee_status.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

/// "Fermer la journée": the shifts still open on the journée, each with an
/// exit time to enter (now by default), then the confirm.
///
/// Resolves to the exits (attendance id → exit time) on confirm, null on
/// cancel. Writes nothing: the board confirms the PIN and hands the exits to
/// `BusinessDayRepository.close`, which applies them all or none.
///
/// A picked time is the **latest** such time not after [now] — so at 00:40,
/// "23:30" means yesterday evening. It must not fall before the shift's
/// clock-in or its running break's start; the confirm stays disabled until
/// every row is valid.
class CloseBusinessDayDialog extends StatefulWidget {
  const CloseBusinessDayDialog({
    required this.businessDay,
    required this.openShifts,
    required this.employees,
    required this.now,
    super.key,
  });

  final BusinessDay businessDay;

  /// The journée's rows still `working` / `onBreak`.
  final List<Attendance> openShifts;

  /// By id, archived included — an archived employee's open shift still has
  /// to be ended.
  final Map<String, Employee> employees;

  final DateTime now;

  static Future<Map<String, DateTime>?> show(
    BuildContext context, {
    required BusinessDay businessDay,
    required List<Attendance> openShifts,
    required Map<String, Employee> employees,
    required DateTime now,
  }) => showDialog<Map<String, DateTime>>(
    context: context,
    builder: (_) => CloseBusinessDayDialog(
      businessDay: businessDay,
      openShifts: openShifts,
      employees: employees,
      now: now,
    ),
  );

  @override
  State<CloseBusinessDayDialog> createState() => _CloseBusinessDayDialogState();
}

class _CloseBusinessDayDialogState extends State<CloseBusinessDayDialog> {
  late final Map<String, DateTime> _exits = {
    for (final shift in widget.openShifts) shift.id: _minute(widget.now),
  };

  static DateTime _minute(DateTime v) =>
      DateTime(v.year, v.month, v.day, v.hour, v.minute);

  /// The latest [time] not after `now`.
  DateTime _resolve(TimeOfDay time) {
    final now = widget.now;
    final today = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return today.isAfter(now)
        ? DateTime(now.year, now.month, now.day - 1, time.hour, time.minute)
        : today;
  }

  /// Why [exit] is impossible for [shift], or null when it is fine.
  String? _problem(AppLocalizations l10n, Attendance shift, DateTime exit) {
    final session = shift.sessions.lastOrNull;
    if (session == null) return null;
    if (exit.isBefore(session.clockInAt)) {
      return l10n.timeclockCloseDayExitBeforeStart(
        Formatters.time(session.clockInAt),
      );
    }
    for (final pause in session.pauses) {
      if (pause.endAt == null && exit.isBefore(pause.startAt)) {
        return l10n.timeclockCloseDayExitBeforePause(
          Formatters.time(pause.startAt),
        );
      }
    }
    return null;
  }

  Future<void> _pick(Attendance shift) async {
    final current = _exits[shift.id]!;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _exits[shift.id] = _resolve(picked));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final date = Formatters.dateLongWeekday(widget.businessDay.date);
    final dateLower = date.isEmpty
        ? date
        : date[0].toLowerCase() + date.substring(1);
    final valid = widget.openShifts.every(
      (s) => _problem(l10n, s, _exits[s.id]!) == null,
    );

    return AlertDialog(
      scrollable: true,
      insetPadding: context.dialogInsets,
      title: Text(l10n.timeclockCloseDayTitle(dateLower)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizing.dialogMaxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.openShifts.isEmpty
                  ? l10n.timeclockCloseDayAllOut
                  : l10n.timeclockCloseDayStillIn,
            ),
            for (final shift in widget.openShifts) ...[
              const SizedBox(height: AppSpacing.md),
              _ShiftRow(
                key: ValueKey('close-day-shift-${shift.id}'),
                shift: shift,
                employee: widget.employees[shift.employeeId],
                exit: _exits[shift.id]!,
                problem: _problem(l10n, shift, _exits[shift.id]!),
                onPick: () => _pick(shift),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.timeclockCloseDayFinal,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton(
          key: const ValueKey('close-day-confirm'),
          onPressed: valid
              ? () => Navigator.of(context).pop(Map.of(_exits))
              : null,
          child: Text(l10n.timeclockCloseDay),
        ),
      ],
    );
  }
}

/// One open shift: who, where they stand, and their exit time.
class _ShiftRow extends StatelessWidget {
  const _ShiftRow({
    required this.shift,
    required this.employee,
    required this.exit,
    required this.problem,
    required this.onPick,
    super.key,
  });

  final Attendance shift;
  final Employee? employee;
  final DateTime exit;
  final String? problem;
  final VoidCallback onPick;

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
              key: const ValueKey('close-day-exit'),
              onPressed: onPick,
              icon: const Icon(LucideIcons.clock, size: AppSizing.iconSm),
              label: Text(l10n.timeclockCloseDayExit(Formatters.time(exit))),
            ),
          ],
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
