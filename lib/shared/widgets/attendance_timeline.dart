import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final events = <_Event>[];

    if (entry.clockInAt != null) {
      events.add(_Event(entry.clockInAt!, l10n.timeclockLogArrival, AppColors.inStock.solid));
    }
    for (final pause in entry.pauses) {
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
    if (entry.clockOutAt != null) {
      events.add(_Event(entry.clockOutAt!, l10n.timeclockLogDeparture, AppColors.textSecondary));
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
