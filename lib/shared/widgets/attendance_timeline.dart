import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/attendance_status.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../models/models.dart';

/// The day's events down a thin rail — Arrivée, Début pause, Reprise, Départ.
/// Built straight from the timestamps already on the row; no new data.
class AttendanceTimeline extends StatelessWidget {
  const AttendanceTimeline({required this.entry, this.maxBreakMinutes, super.key});

  final Attendance entry;

  /// When given, a break that ran over the allowance is marked amber.
  final int? maxBreakMinutes;

  @override
  Widget build(BuildContext context) =>
      _EventRail(sessions: entry.sessions, maxBreakMinutes: maxBreakMinutes);
}

/// The day's timestamps split by session, for the pointage board's drawer.
///
/// One session reads as a plain timeline — no "Session" heading for a day
/// that only has the one. Two or more each get a `Session N° x` divider. Under
/// each session, a line per break that ran past the allowance; nothing at all
/// when every break was within it.
class AttendanceSessions extends StatelessWidget {
  const AttendanceSessions({
    required this.entry,
    required this.maxBreakMinutes,
    super.key,
  });

  final Attendance entry;
  final int maxBreakMinutes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sessions = entry.sessions;
    if (sessions.isEmpty) return const SizedBox.shrink();

    Widget block(AttendanceSession session) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _EventRail(sessions: [session], maxBreakMinutes: maxBreakMinutes),
        for (final pause in session.pauses)
          if (breakOverrun(pause, maxBreakMinutes) > Duration.zero)
            _PauseAlert(
              text: l10n.timeclockPauseOverrun(
                Formatters.time(pause.startAt),
                Formatters.duration(breakOverrun(pause, maxBreakMinutes)),
              ),
            ),
      ],
    );

    if (sessions.length == 1) return block(sessions.single);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < sessions.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.lg),
          _SessionHeading(label: l10n.timeclockSessionTitle(i + 1)),
          const SizedBox(height: AppSpacing.md),
          block(sessions[i]),
        ],
      ],
    );
  }
}

/// `──── Session N° 1 ────`
class _SessionHeading extends StatelessWidget {
  const _SessionHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Container(height: 1, color: AppColors.border),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        line,
      ],
    );
  }
}

class _PauseAlert extends StatelessWidget {
  const _PauseAlert({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.lowStock.foreground.withValues(alpha: 0.1),
        borderRadius: AppRadius.smAll,
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
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// Arrivée · Pause · Reprise · … · Départ down a thin rail. A break that ran
/// over the allowance turns its Reprise dot amber.
class _EventRail extends StatelessWidget {
  const _EventRail({required this.sessions, required this.maxBreakMinutes});

  final List<AttendanceSession> sessions;
  final int? maxBreakMinutes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final events = <_Event>[];

    for (final session in sessions) {
      events.add(_Event(session.clockInAt, l10n.timeclockLogArrival, AppColors.inStock.solid));
      for (final pause in session.pauses) {
        events.add(_Event(pause.startAt, l10n.timeclockLogBreak, AppColors.onBreak.solid));
        if (pause.endAt != null) {
          final over = maxBreakMinutes != null &&
              breakOverrun(pause, maxBreakMinutes!) > Duration.zero;
          events.add(
            _Event(
              pause.endAt!,
              l10n.timeclockLogResume,
              over ? AppColors.lowStock.solid : AppColors.inStock.solid,
            ),
          );
        }
      }
      if (session.clockOutAt != null) {
        events.add(_Event(session.clockOutAt!, l10n.timeclockLogDeparture, AppColors.textSecondary));
      }
    }

    if (events.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < events.length; i++)
          _Row(event: events[i], isLast: i == events.length - 1),
      ],
    );
  }
}

class _Event {
  const _Event(this.at, this.label, this.color);
  final DateTime at;
  final String label;
  final Color color;
}

class _Row extends StatelessWidget {
  const _Row({required this.event, required this.isLast});

  final _Event event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              Formatters.time(event.at),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Column(
            children: [
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: event.color,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 1.5, color: AppColors.border),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
            child: Text(event.label, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
