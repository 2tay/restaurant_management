import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/attendance_status.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../models/models.dart';

/// The day's timestamps split by session, for the pointage drawers (tableau
/// de pointage and historique).
///
/// One session reads as a plain timeline — no "Session" heading for a day
/// that only has the one. Two or more each get a centred `Session N° x` on a
/// full-width dashed rule, with room between sessions. A full-width dashed
/// rule closes the list. The day's alerts (a break over the allowance) live in the
/// drawer's own Alertes section; a late Reprise dot still turns amber.
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
    final numbered = sessions.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < sessions.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.xxl),
          if (numbered) ...[
            _SessionHeading(label: l10n.timeclockSessionTitle(i + 1)),
            const SizedBox(height: AppSpacing.lg),
          ],
          _EventRail(sessions: [sessions[i]], maxBreakMinutes: maxBreakMinutes),
        ],
        const SizedBox(height: AppSpacing.xl),
        const _DashStroke(key: ValueKey('attendance-sessions-end')),
      ],
    );
  }
}

/// `- - - - Session N° 1 - - - -`, the dashes running to both edges.
class _SessionHeading extends StatelessWidget {
  const _SessionHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Expanded(child: _DashStroke()),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        const Expanded(child: _DashStroke()),
      ],
    );
  }
}

/// A 1dp dashed stroke, as wide as its parent allows.
class _DashStroke extends StatelessWidget {
  const _DashStroke({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: double.infinity,
    height: 1,
    child: CustomPaint(painter: _DashPainter(AppColors.borderStrong)),
  );
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);

  final Color color;

  static const double _dash = 4;
  static const double _gap = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += _dash + _gap) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + _dash).clamp(0, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
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
            child: Text(
              event.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
