import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';

/// `Date : Mar 24/10/2026 · Heure : 12:01`, ticking — the pointage board's
/// header.
///
/// Its own stateful widget so the once-a-second tick redraws this line only,
/// never the grid of cards around it.
class LiveDateTime extends StatefulWidget {
  const LiveDateTime({super.key});

  @override
  State<LiveDateTime> createState() => _LiveDateTimeState();
}

class _LiveDateTimeState extends State<LiveDateTime> {
  late DateTime _now = DateTime.now();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      color: AppColors.textSecondary,
    );
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    );

    // Text spans rather than a Row of widgets, so a narrow panel (the
    // drawer on a small tablet) wraps the line instead of overflowing it.
    Widget part(IconData icon, String label, List<InlineSpan> value) =>
        Text.rich(
          TextSpan(
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: Icon(
                    icon,
                    size: AppSizing.iconSm,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextSpan(text: '$label : ', style: labelStyle),
              TextSpan(style: valueStyle, children: value),
            ],
          ),
        );

    final smaller = (valueStyle?.fontSize ?? 14) - 3;
    return Wrap(
      key: const ValueKey('live-date-time'),
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // `Mar 24/10/2026`, the weekday a size smaller — as `WeekdayDate`.
        part(LucideIcons.calendar, l10n.liveDateLabel, [
          TextSpan(
            text: Formatters.weekdayShort(_now),
            style: TextStyle(fontSize: smaller),
          ),
          TextSpan(text: ' ${Formatters.date(_now)}'),
        ]),
        part(LucideIcons.clock, l10n.liveTimeLabel, [
          TextSpan(text: Formatters.time(_now)),
        ]),
      ],
    );
  }
}

/// `🕐 15:30`, ticking — beside the day's date in the board's drawer
/// (`AttendanceDayDate.trailing`), in the same weight as the date.
class LiveTime extends StatefulWidget {
  const LiveTime({super.key});

  @override
  State<LiveTime> createState() => _LiveTimeState();
}

class _LiveTimeState extends State<LiveTime> {
  late DateTime _now = DateTime.now();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('live-time'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          LucideIcons.clock,
          size: AppSizing.iconSm,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          Formatters.time(_now),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
