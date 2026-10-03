import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

/// « Corriger la sortie »: the exit time of a day left open — the employee
/// forgot to clock out, and the journée it belonged to is long gone.
///
/// Resolves to the exit on confirm, null on cancel. Writes nothing: the
/// history confirms the PIN and hands the time to
/// `AttendanceRepository.correctExit`.
///
/// A picked time is its **first** occurrence after the clock-in — a shift
/// lasts less than a day, so for a clock-in at 18:00, « 00:30 » means the next
/// day, said under the button. It must not fall before the running break's
/// start nor after [now]; the confirm stays disabled until a valid time is
/// picked.
class CorrectExitDialog extends StatefulWidget {
  const CorrectExitDialog({
    required this.entry,
    required this.employee,
    required this.now,
    super.key,
  });

  final Attendance entry;
  final Employee? employee;
  final DateTime now;

  static Future<DateTime?> show(
    BuildContext context, {
    required Attendance entry,
    required Employee? employee,
    required DateTime now,
  }) => showDialog<DateTime>(
    context: context,
    builder: (_) =>
        CorrectExitDialog(entry: entry, employee: employee, now: now),
  );

  @override
  State<CorrectExitDialog> createState() => _CorrectExitDialogState();
}

class _CorrectExitDialogState extends State<CorrectExitDialog> {
  DateTime? _exit;

  AttendanceSession? get _session => widget.entry.sessions.lastOrNull;

  /// The first [time] at or after the clock-in.
  DateTime _resolve(TimeOfDay time) {
    final start = _session!.clockInAt;
    final sameDay = DateTime(
      start.year,
      start.month,
      start.day,
      time.hour,
      time.minute,
    );
    return sameDay.isBefore(start)
        ? DateTime(start.year, start.month, start.day + 1, time.hour, time.minute)
        : sameDay;
  }

  /// Why [exit] is impossible, or null when it is fine.
  String? _problem(AppLocalizations l10n, DateTime exit) {
    if (exit.isAfter(widget.now)) return l10n.attendanceCorrectExitFuture;
    for (final pause in _session!.pauses) {
      if (pause.endAt == null && exit.isBefore(pause.startAt)) {
        return l10n.timeclockCloseDayExitBeforePause(
          Formatters.time(pause.startAt),
        );
      }
    }
    return null;
  }

  /// « le lendemain, mardi 21 septembre » when the exit is past midnight.
  String? _note(AppLocalizations l10n, DateTime exit) {
    final start = _session!.clockInAt;
    if (exit.day == start.day &&
        exit.month == start.month &&
        exit.year == start.year) {
      return null;
    }
    return l10n.attendanceCorrectExitNextDay(
      _lowerFirst(Formatters.dateLongWeekday(exit)),
    );
  }

  Future<void> _pick() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_exit ?? _session!.clockInAt),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _exit = _resolve(picked));
  }

  static String _lowerFirst(String s) =>
      s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final session = _session;
    final exit = _exit;
    final problem = exit == null ? null : _problem(l10n, exit);
    final valid = session != null && exit != null && problem == null;

    return AlertDialog(
      scrollable: true,
      insetPadding: context.dialogInsets,
      title: Text(l10n.attendanceCorrectExit),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizing.dialogMaxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.attendanceCorrectExitBody(
                _lowerFirst(Formatters.dateLongWeekday(widget.entry.date)),
                session == null ? '—' : Formatters.time(session.clockInAt),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OpenShiftExitRow(
              buttonKey: const ValueKey('correct-exit-time'),
              shift: widget.entry,
              employee: widget.employee,
              exit: exit,
              note: exit == null ? null : _note(l10n, exit),
              problem: problem,
              onPick: _pick,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.attendanceCorrectExitSigned,
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
          key: const ValueKey('correct-exit-confirm'),
          onPressed: valid ? () => Navigator.of(context).pop(exit) : null,
          child: Text(l10n.attendanceCorrectExit),
        ),
      ],
    );
  }
}
