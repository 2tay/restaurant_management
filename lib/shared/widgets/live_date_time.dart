import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';

/// `📅 Mar 24/10/2026 | 🕐 12:01`, ticking — the pointage board's header.
///
/// Its own stateful widget so the once-a-second tick redraws this line only,
/// never the grid of cards around it.
class LiveDateTime extends StatefulWidget {
  const LiveDateTime({this.small = false, super.key});

  /// A size down — under the board's title on a phone or a small tablet.
  final bool small;

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
    final theme = Theme.of(context);
    final small = widget.small;
    final valueStyle =
        (small ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)
            ?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600);

    // Text spans rather than a Row of widgets, so a narrow panel (the
    // drawer on a small tablet) wraps the line instead of overflowing it.
    Widget part(IconData icon, List<InlineSpan> value) =>
        Text.rich(
          TextSpan(
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: Icon(
                    icon,
                    size: small ? 14 : AppSizing.iconSm,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextSpan(style: valueStyle, children: value),
            ],
          ),
        );

    final smaller = (valueStyle?.fontSize ?? 14) - 3;
    return Wrap(
      key: const ValueKey('live-date-time'),
      // Same gap as the header's action row, so the pipe after the clock
      // (before full screen) sits like the one between date and time.
      spacing: small ? AppSpacing.sm : AppSpacing.md,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // `Mar 24/10/2026`, the weekday a size smaller — as `WeekdayDate`.
        part(LucideIcons.calendar, [
          TextSpan(
            text: Formatters.weekdayShort(_now),
            style: TextStyle(fontSize: smaller),
          ),
          TextSpan(text: ' ${Formatters.date(_now)}'),
        ]),
        PipeSeparator(small: small),
        part(LucideIcons.clock, [
          TextSpan(text: Formatters.time(_now)),
        ]),
      ],
    );
  }
}

/// The `|` between the items of a header line — date, time, full screen.
class PipeSeparator extends StatelessWidget {
  const PipeSeparator({this.small = false, super.key});

  /// Matches a [LiveDateTime.small] line.
  final bool small;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Text(
      '|',
      style: (small ? theme.bodySmall : theme.bodyMedium)?.copyWith(
        color: AppColors.textSecondary,
      ),
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
