import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/busy_calendar.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../busy_labels.dart';

/// The busy-day calendar.
///
/// Three cards, in the order somebody sets them up: the weekdays that are busy
/// every week (Friday to Sunday until changed), the one-off dates on a month
/// grid, and how early to be reminded. A line underneath says what that adds
/// up to — the next busy period and the day its reminder starts — so the owner
/// can check the result without waiting for it.
///
/// Every tap saves. There is no "Enregistrer": each control is one value, and
/// the screen redraws from the stream it just wrote to.
///
/// What a busy day *means* is set on each product, as its "stock minimum en
/// forte affluence"; this screen only says when that minimum applies.
class CalendarPage extends ConsumerWidget {
  const CalendarPage({required this.storeId, super.key});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncCalendar = ref.watch(busyCalendarProvider(storeId));

    return ShellPage(
      title: l10n.calendarTitle,
      subtitle: l10n.calendarSubtitle,
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: AsyncContent<BusyCalendar>(
            value: asyncCalendar,
            onRetry: () => ref.invalidate(busyCalendarProvider(storeId)),
            builder: (context, calendar) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WeekdaysCard(calendar: calendar),
                const SizedBox(height: AppSpacing.lg),
                _MonthCard(calendar: calendar),
                const SizedBox(height: AppSpacing.lg),
                _ReminderCard(calendar: calendar),
                const SizedBox(height: AppSpacing.lg),
                _Summary(calendar: calendar),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Saves through the repository, then asks for the reminder straight away: a
/// holiday marked for tomorrow should not wait for the shell's next hourly
/// check to reach the bell.
Future<void> _save(
  WidgetRef ref,
  String storeId,
  Future<void> Function() write,
) async {
  await write();
  await ref.read(calendarRepositoryProvider).checkReminder(storeId);
}

// -----------------------------------------------------------------------------
// The cards.
// -----------------------------------------------------------------------------

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppSizing.iconMd, color: AppColors.primary600),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(body, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeekdaysCard extends ConsumerWidget {
  const _WeekdaysCard({required this.calendar});

  final BusyCalendar calendar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(calendarRepositoryProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            icon: LucideIcons.calendarDays,
            title: l10n.calendarWeekdaysTitle,
            body: l10n.calendarWeekdaysBody,
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (var weekday = DateTime.monday;
                  weekday <= DateTime.sunday;
                  weekday++)
                _ChoiceChip(
                  // 1 January 2024 was a Monday, so day `weekday` of that
                  // month has that weekday — the formatter names it.
                  label: Formatters.weekdayShort(DateTime(2024, 1, weekday)),
                  selected: calendar.weekdays.contains(weekday),
                  onTap: () => _save(
                    ref,
                    calendar.storeId,
                    () => repository.toggleWeekday(calendar.storeId, weekday),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthCard extends ConsumerStatefulWidget {
  const _MonthCard({required this.calendar});

  final BusyCalendar calendar;

  @override
  ConsumerState<_MonthCard> createState() => _MonthCardState();
}

class _MonthCardState extends ConsumerState<_MonthCard> {
  /// The first of the month on screen.
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final today = ref.read(todayProvider);
    _month = DateTime(today.year, today.month);
  }

  void _shift(int months) =>
      setState(() => _month = DateTime(_month.year, _month.month + months));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final calendar = widget.calendar;
    final repository = ref.read(calendarRepositoryProvider);

    // Monday-first, like every calendar on the wall here. Blank cells pad the
    // first week to its Monday.
    final leading = _month.weekday - DateTime.monday;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = <DateTime?>[
      for (var i = 0; i < leading; i++) null,
      for (var d = 1; d <= daysInMonth; d++)
        DateTime(_month.year, _month.month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    // No going back past the current month: a busy day that is over is not
    // something to plan for.
    final canGoBack =
        _month.isAfter(DateTime(today.year, today.month));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(
            icon: LucideIcons.calendarPlus,
            title: l10n.calendarDatesTitle,
            body: l10n.calendarDatesBody,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              IconButton(
                onPressed: canGoBack ? () => _shift(-1) : null,
                tooltip: l10n.calendarPreviousMonth,
                icon: const Icon(LucideIcons.chevronLeft),
              ),
              Expanded(
                child: Text(
                  Formatters.monthYear(_month),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              IconButton(
                onPressed: () => _shift(1),
                tooltip: l10n.calendarNextMonth,
                icon: const Icon(LucideIcons.chevronRight),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (var weekday = DateTime.monday;
                  weekday <= DateTime.sunday;
                  weekday++)
                Expanded(
                  child: Text(
                    Formatters.weekdayShort(DateTime(2024, 1, weekday)),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (var row = 0; row < cells.length; row += 7)
            Row(
              children: [
                for (final day in cells.sublist(row, row + 7))
                  Expanded(
                    child: day == null
                        ? const SizedBox(height: 44)
                        : _DayCell(
                            day: day,
                            isToday: day == today,
                            isPast: day.isBefore(today),
                            special: calendar.dates.contains(day),
                            weekly: calendar.weekdays.contains(day.weekday),
                            onTap: () => _save(
                              ref,
                              calendar.storeId,
                              () => repository.toggleDate(calendar.storeId, day),
                            ),
                          ),
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: [
              _Legend(
                color: AppColors.primaryContainer,
                label: l10n.calendarLegendWeekly,
              ),
              _Legend(
                color: AppColors.primary600,
                label: l10n.calendarLegendSpecial,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One day of the month grid.
///
/// A special date is filled, a weekly busy day is tinted, and a day that is
/// both reads as special — the tap on it can only remove the special mark, so
/// that is the one it has to show. Past days are shown but cannot be tapped.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isPast,
    required this.special,
    required this.weekly,
    required this.onTap,
  });

  final DateTime day;
  final bool isToday;
  final bool isPast;
  final bool special;
  final bool weekly;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color background;
    final Color foreground;
    if (special) {
      background = AppColors.primary600;
      foreground = AppColors.white;
    } else if (weekly) {
      background = AppColors.primaryContainer;
      foreground = AppColors.onPrimaryContainer;
    } else {
      background = Colors.transparent;
      foreground = AppColors.textPrimary;
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Semantics(
        button: !isPast,
        selected: special,
        label: Formatters.dateLong(day),
        child: InkWell(
          onTap: isPast ? null : onTap,
          borderRadius: AppRadius.mdAll,
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              borderRadius: AppRadius.mdAll,
              border: isToday
                  ? Border.all(color: AppColors.primary600, width: 2)
                  : null,
            ),
            child: Text(
              '${day.day}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isPast ? AppColors.textDisabled : foreground,
                fontWeight: isToday || special
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, borderRadius: AppRadius.mdAll),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ReminderCard extends ConsumerWidget {
  const _ReminderCard({required this.calendar});

  final BusyCalendar calendar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(calendarRepositoryProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            icon: LucideIcons.bellRing,
            title: l10n.calendarReminderTitle,
            body: l10n.calendarReminderBody,
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final days in BusyCalendarRules.reminderChoices)
                _ChoiceChip(
                  label: l10n.calendarReminderDays(days),
                  selected: calendar.reminderDays == days,
                  onTap: () => _save(
                    ref,
                    calendar.storeId,
                    () => repository.setReminderDays(calendar.storeId, days),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What the three cards add up to, in one sentence.
class _Summary extends ConsumerWidget {
  const _Summary({required this.calendar});

  final BusyCalendar calendar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final period = nextBusyPeriod(today, calendar);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          LucideIcons.info,
          size: AppSizing.iconSm,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            period == null
                ? l10n.calendarNoPeriod
                : l10n.calendarNextPeriod(
                    busyPeriodLabel(l10n, period),
                    Formatters.weekdayDayMonth(
                      reminderStartOf(period, calendar),
                    ),
                  ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// A pill that is on or off — the weekdays and the reminder choices.
class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillAll,
        child: AnimatedContainer(
          duration: AppMotion.duration(context, AppMotion.fast),
          constraints: const BoxConstraints(minHeight: AppSizing.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryContainer : AppColors.surface,
            borderRadius: AppRadius.pillAll,
            border: Border.all(
              color: selected ? AppColors.primary600 : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(
                  LucideIcons.check,
                  size: AppSizing.iconSm,
                  color: AppColors.onPrimaryContainer,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected
                      ? AppColors.onPrimaryContainer
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
