import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/busy_calendar.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../alerts/presentation/alerts_filter.dart';
import '../busy_labels.dart';

/// The busy-day calendar.
///
/// It opens on the answer rather than the settings: a summary card says when
/// the next busy period is, when its reminder comes, and how many products
/// are short for it, with the way to order them. Under it, the month grid on
/// one side and the three settings on the other — busy weekdays, how early to
/// be reminded, and the special days still to come. On a phone they stack in
/// the order somebody sets them up.
///
/// Every tap saves. There is no "Enregistrer": each control is one value, and
/// the screen redraws from the stream it just wrote to — the summary card
/// included, so the effect of a change is visible where the change is made.
///
/// What a busy day *means* is set on each product, as its "stock minimum en
/// forte affluence"; this screen only says when that minimum applies.
class CalendarPage extends ConsumerWidget {
  const CalendarPage({required this.storeId, super.key});

  final String storeId;

  /// Wide enough for the grid and the settings side by side.
  static const double _twoColumns = 880;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncCalendar = ref.watch(busyCalendarProvider(storeId));

    return ShellPage(
      title: l10n.calendarTitle,
      subtitle: l10n.calendarSubtitle,
      child: AsyncContent<BusyCalendar>(
        value: asyncCalendar,
        onRetry: () => ref.invalidate(busyCalendarProvider(storeId)),
        builder: (context, calendar) => LayoutBuilder(
          builder: (context, constraints) {
            final hero = _SummaryCard(calendar: calendar);
            final weekdays = _WeekdaysCard(calendar: calendar);
            final month = _MonthCard(calendar: calendar);
            final reminder = _ReminderCard(calendar: calendar);
            final upcoming = _UpcomingCard(calendar: calendar);
            const gap = SizedBox(height: AppSpacing.lg);

            if (constraints.maxWidth < _twoColumns || context.isLargeText) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  hero,
                  gap,
                  weekdays,
                  gap,
                  month,
                  gap,
                  reminder,
                  gap,
                  upcoming,
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                hero,
                gap,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: month),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [weekdays, gap, reminder, gap, upcoming],
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Saves through the repository, then asks for the reminder straight away: a
/// holiday marked for tomorrow should not wait for the shell's next check to
/// reach the bell.
Future<void> _save(
  WidgetRef ref,
  String storeId,
  Future<void> Function() write,
) async {
  await write();
  await ref.read(calendarRepositoryProvider).checkReminder(storeId);
}

// -----------------------------------------------------------------------------
// The summary card.
// -----------------------------------------------------------------------------

/// The next busy period, in the terms the owner acts on: how long until it
/// starts, when the reminder comes, and how much there is to buy.
///
/// Amber while the reminder is on — that is the moment to order — and teal
/// the rest of the time. With nothing busy at all it says so, and how to fix
/// it, rather than showing an empty countdown.
class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({required this.calendar});

  final BusyCalendar calendar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final period = nextBusyPeriod(today, calendar);

    if (period == null) {
      return AppCard(
        child: Row(
          children: [
            const _Medallion(
              icon: LucideIcons.calendarX,
              colors: StockStatusColors(
                solid: AppColors.neutral400,
                foreground: AppColors.textSecondary,
                container: AppColors.surfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.calendarHeroNoneTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    l10n.calendarHeroNoneBody,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final days = daysBetween(today, period.start);
    final ongoing = days <= 0;
    final reminding = activeBusyWarning(today, calendar) != null;
    final colors = reminding ? AppColors.lowStock : _upcoming;
    final reminderStart = reminderStartOf(period, calendar);
    final short = ref.watch(busyAlertsProvider(calendar.storeId)).value?.length;

    final countdown = _Countdown(days: days, colors: colors);

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              (ongoing
                      ? l10n.calendarHeroOngoingLabel
                      : l10n.calendarHeroNextLabel)
                  .toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
              ),
            ),
            // Once the period has started, "en cours" already says it.
            if (reminding && !ongoing)
              _Badge(label: l10n.calendarHeroReminderActive, colors: colors),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(busyPeriodShort(period), style: AppTypography.numericHero),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.xs,
          children: [
            if (!ongoing)
              _Fact(
                icon: LucideIcons.bellRing,
                label: reminderStart.isAfter(today)
                    ? l10n.calendarHeroReminderOn(_shortDate(reminderStart))
                    : l10n.calendarHeroReminderSince(_shortDate(reminderStart)),
              ),
            if (short != null)
              _Fact(
                icon: short == 0
                    ? LucideIcons.circleCheck
                    : LucideIcons.package,
                label: l10n.calendarHeroShortCount(short),
                color: short == 0
                    ? AppColors.inStock.foreground
                    : reminding
                    ? AppColors.lowStock.foreground
                    : null,
                strong: short > 0,
              ),
          ],
        ),
      ],
    );

    final action = short == null || short == 0
        ? null
        : (reminding
              ? PrimaryButton(
                  label: l10n.calendarHeroShowProducts,
                  icon: LucideIcons.arrowRight,
                  onPressed: () => _openBusyList(context, ref),
                )
              : SecondaryButton(
                  label: l10n.calendarHeroShowProducts,
                  icon: LucideIcons.arrowRight,
                  onPressed: () => _openBusyList(context, ref),
                ));

    return AppCard(
      accentColor: colors.solid,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600 || context.isLargeText) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    countdown,
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(child: details),
                  ],
                ),
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  action,
                ],
              ],
            );
          }
          return Row(
            children: [
              countdown,
              const SizedBox(width: AppSpacing.xl),
              Expanded(child: details),
              if (action != null) ...[
                const SizedBox(width: AppSpacing.lg),
                action,
              ],
            ],
          );
        },
      ),
    );
  }

  /// "Jeu 1 oct." — short enough to sit beside an icon.
  static String _shortDate(DateTime day) =>
      '${Formatters.weekdayShort(day)} ${Formatters.dayMonth(day)}';

  /// The alerts screen, already on its "Jours chargés" tab.
  void _openBusyList(BuildContext context, WidgetRef ref) {
    ref.read(alertsFilterProvider.notifier).setSeverity(AlertSeverity.busy);
    context.goSection(Routes.toAlerts(calendar.storeId));
  }
}

/// The summary card's colours while no reminder is on: the primary teal,
/// as a tint — nothing needs doing yet.
const StockStatusColors _upcoming = StockStatusColors(
  solid: AppColors.primary600,
  foreground: AppColors.onPrimaryContainer,
  container: AppColors.primaryContainer,
);

/// "4 jours" in a tinted square, or "En cours" once the period has started.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.days, required this.colors});

  final int days;
  final StockStatusColors colors;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ongoing = days <= 0;

    return Container(
      constraints: const BoxConstraints(minWidth: 88, minHeight: 88),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.container,
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (ongoing)
            Icon(
              LucideIcons.flame,
              size: AppSizing.iconLg,
              color: colors.foreground,
            )
          else
            Text(
              '$days',
              style: AppTypography.numericLarge.copyWith(
                color: colors.foreground,
              ),
            ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            ongoing
                ? l10n.calendarCountdownNow
                : l10n.calendarCountdownUnit(days),
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// An icon and a short statement, in a row of them under the headline.
class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    this.color,
    this.strong = false,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppSizing.iconSm, color: foreground),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: foreground,
              fontWeight: strong ? FontWeight.w600 : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.colors});

  final String label;
  final StockStatusColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.container,
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: colors.solid,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Medallion extends StatelessWidget {
  const _Medallion({required this.icon, required this.colors});

  final IconData icon;
  final StockStatusColors colors;

  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(color: colors.container, shape: BoxShape.circle),
    child: Icon(icon, size: AppSizing.iconMd, color: colors.foreground),
  );
}

// -----------------------------------------------------------------------------
// Card chrome.
// -----------------------------------------------------------------------------

/// Icon, title and one line of help, with an optional note on the right.
class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.icon,
    required this.title,
    this.body,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: body == null
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: AppRadius.mdAll,
          ),
          child: Icon(
            icon,
            size: AppSizing.iconSm,
            color: AppColors.primary600,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              if (body != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(body!, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          trailing!,
        ],
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Weekdays and reminder.
// -----------------------------------------------------------------------------

class _WeekdaysCard extends ConsumerWidget {
  const _WeekdaysCard({required this.calendar});

  final BusyCalendar calendar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(calendarRepositoryProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHeader(
            icon: LucideIcons.repeat,
            title: l10n.calendarWeekdaysTitle,
          ),
          const SizedBox(height: AppSpacing.lg),
          _SegmentedBar(
            segments: [
              for (
                var weekday = DateTime.monday;
                weekday <= DateTime.sunday;
                weekday++
              )
                _Segment(
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

class _ReminderCard extends ConsumerWidget {
  const _ReminderCard({required this.calendar});

  final BusyCalendar calendar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(calendarRepositoryProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHeader(
            icon: LucideIcons.bellRing,
            title: l10n.calendarReminderTitle,
          ),
          const SizedBox(height: AppSpacing.lg),
          _SegmentedBar(
            segments: [
              for (final days in BusyCalendarRules.reminderChoices)
                _Segment(
                  label: l10n.calendarReminderShort(days),
                  semanticLabel: l10n.calendarReminderDays(days),
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

/// A row of equal toggles, each of them on or off — the weekdays and the
/// reminder choices. Equal widths, so the row reads as one control.
class _SegmentedBar extends StatelessWidget {
  const _SegmentedBar({required this.segments});

  final List<_Segment> segments;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, segment) in segments.indexed) ...[
          if (i > 0) const SizedBox(width: AppSpacing.xs),
          Expanded(child: segment),
        ],
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
    this.semanticLabel,
  });

  final String label;
  final String? semanticLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: AnimatedContainer(
          duration: AppMotion.duration(context, AppMotion.fast),
          height: AppSizing.minTapTarget,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary600 : AppColors.surface,
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: selected ? AppColors.primary600 : AppColors.border,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: theme.textTheme.labelLarge?.copyWith(
                color: selected ? AppColors.white : AppColors.textPrimary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// The month grid.
// -----------------------------------------------------------------------------

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

  void _show(DateTime month) =>
      setState(() => _month = DateTime(month.year, month.month));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final calendar = widget.calendar;
    final repository = ref.read(calendarRepositoryProvider);
    final thisMonth = DateTime(today.year, today.month);

    // Monday-first, like every calendar on the wall here. Blank cells pad the
    // first week to its Monday and the last to its Sunday.
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
    bool busyAt(int index) {
      final day = index >= 0 && index < cells.length ? cells[index] : null;
      return day != null && isBusyDay(day, calendar);
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHeader(
            icon: LucideIcons.calendarDays,
            title: l10n.calendarDatesTitle,
            body: l10n.calendarDatesBody,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  Formatters.monthYear(_month),
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_month != thisMonth)
                TextButton(
                  onPressed: () => _show(thisMonth),
                  child: Text(l10n.calendarToday),
                ),
              IconButton(
                // No going back past the current month: a busy day that is
                // over is not something to plan for.
                onPressed: _month.isAfter(thisMonth)
                    ? () => _show(DateTime(_month.year, _month.month - 1))
                    : null,
                tooltip: l10n.calendarPreviousMonth,
                icon: const Icon(LucideIcons.chevronLeft),
              ),
              IconButton(
                onPressed: () => _show(DateTime(_month.year, _month.month + 1)),
                tooltip: l10n.calendarNextMonth,
                icon: const Icon(LucideIcons.chevronRight),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (
                var weekday = DateTime.monday;
                weekday <= DateTime.sunday;
                weekday++
              )
                Expanded(
                  child: Text(
                    Formatters.weekdayShort(DateTime(2024, 1, weekday)),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: theme.textTheme.labelSmall?.copyWith(
                      // The weekly busy days are named in colour here too, so
                      // the grid explains its own tinted columns.
                      color: calendar.weekdays.contains(weekday)
                          ? AppColors.primary600
                          : AppColors.textSecondary,
                      fontWeight: calendar.weekdays.contains(weekday)
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (var row = 0; row < cells.length; row += 7)
            Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: switch (cells[row + col]) {
                      null => const SizedBox(height: _DayCell.height),
                      final day => _DayCell(
                        day: day,
                        isToday: day == today,
                        isPast: day.isBefore(today),
                        special: calendar.dates.contains(day),
                        weekly: calendar.weekdays.contains(day.weekday),
                        reminder:
                            !day.isBefore(today) &&
                            isReminderDay(day, calendar),
                        // Consecutive busy days in a row join into one band,
                        // so a weekend reads as a period, not three dates.
                        joinsPrevious: col > 0 && busyAt(row + col - 1),
                        joinsNext: col < 6 && busyAt(row + col + 1),
                        onTap: () => _save(
                          ref,
                          calendar.storeId,
                          () => repository.toggleDate(calendar.storeId, day),
                        ),
                      ),
                    },
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: [
              _Legend(
                swatch: _swatch(AppColors.primaryContainer),
                label: l10n.calendarLegendWeekly,
              ),
              _Legend(
                swatch: _swatch(AppColors.primary600),
                label: l10n.calendarLegendSpecial,
              ),
              _Legend(
                swatch: const _ReminderDot(),
                label: l10n.calendarLegendReminder,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _swatch(Color color) => Container(
    width: 14,
    height: 14,
    decoration: BoxDecoration(color: color, borderRadius: AppRadius.smAll),
  );
}

/// One day of the month grid.
///
/// A special date is filled, a weekly busy day is tinted, and a day that is
/// both reads as special — the tap on it can only remove the special mark, so
/// that is the one it has to show. A reminder day carries an amber dot. Past
/// days are faded and cannot be tapped.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isPast,
    required this.special,
    required this.weekly,
    required this.reminder,
    required this.joinsPrevious,
    required this.joinsNext,
    required this.onTap,
  });

  static const double height = 48;

  final DateTime day;
  final bool isToday;
  final bool isPast;
  final bool special;
  final bool weekly;
  final bool reminder;
  final bool joinsPrevious;
  final bool joinsNext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final busy = special || weekly;

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

    // Rounded only at the ends of a run of busy days.
    const radius = Radius.circular(AppRadius.md);
    final shape = BorderRadius.horizontal(
      left: busy && joinsPrevious ? Radius.zero : radius,
      right: busy && joinsNext ? Radius.zero : radius,
    );

    final tooltip = special
        ? l10n.calendarLegendSpecial
        : weekly
        ? l10n.calendarLegendWeekly
        : reminder
        ? l10n.calendarLegendReminder
        : null;

    Widget cell = Padding(
      padding: EdgeInsets.only(
        top: AppSpacing.xxs,
        bottom: AppSpacing.xxs,
        left: busy && joinsPrevious ? 0 : AppSpacing.xxs,
        right: busy && joinsNext ? 0 : AppSpacing.xxs,
      ),
      child: Semantics(
        button: !isPast,
        selected: special,
        label: [Formatters.dateLong(day), ?tooltip].join(', '),
        excludeSemantics: true,
        child: Material(
          color: background,
          borderRadius: shape,
          child: InkWell(
            onTap: isPast ? null : onTap,
            borderRadius: shape,
            child: Container(
              height: height - AppSpacing.xxs * 2,
              decoration: isToday
                  ? BoxDecoration(
                      borderRadius: shape,
                      border: Border.all(
                        color: special
                            ? AppColors.primary700
                            : AppColors.primary600,
                        width: 2,
                      ),
                    )
                  : null,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    '${day.day}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      fontWeight: isToday || special
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  if (reminder)
                    const Positioned(bottom: 5, child: _ReminderDot()),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (isPast) cell = Opacity(opacity: 0.4, child: cell);
    if (tooltip != null && !isPast) {
      cell = Tooltip(message: tooltip, child: cell);
    }
    return cell;
  }
}

class _ReminderDot extends StatelessWidget {
  const _ReminderDot();

  @override
  Widget build(BuildContext context) => Container(
    width: 6,
    height: 6,
    decoration: BoxDecoration(
      color: AppColors.lowStock.solid,
      shape: BoxShape.circle,
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.swatch, required this.label});

  final Widget swatch;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 14, child: Center(child: swatch)),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// The special days still to come.
// -----------------------------------------------------------------------------

/// The one-off dates ahead, soonest first, each with a way to take it off —
/// so a holiday marked three months out does not have to be found by paging
/// through the grid to be removed.
class _UpcomingCard extends ConsumerWidget {
  const _UpcomingCard({required this.calendar});

  final BusyCalendar calendar;

  static const int _shown = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final repository = ref.read(calendarRepositoryProvider);

    final upcoming = calendar.dates.where((d) => !d.isBefore(today)).toList()
      ..sort();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHeader(
            icon: LucideIcons.star,
            title: l10n.calendarUpcomingTitle,
            trailing: upcoming.isEmpty
                ? null
                : Text(
                    '${upcoming.length}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (upcoming.isEmpty)
            Text(l10n.calendarUpcomingEmpty, style: theme.textTheme.bodySmall)
          else ...[
            for (final (i, day) in upcoming.take(_shown).indexed) ...[
              if (i > 0) const Divider(height: 1),
              _UpcomingRow(
                day: day,
                today: today,
                onRemove: () => _save(
                  ref,
                  calendar.storeId,
                  () => repository.toggleDate(calendar.storeId, day),
                ),
              ),
            ],
            if (upcoming.length > _shown) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.calendarUpcomingMore(upcoming.length - _shown),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({
    required this.day,
    required this.today,
    required this.onRemove,
  });

  final DateTime day;
  final DateTime today;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          // A tear-off calendar leaf: the day, and the month above it.
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: AppRadius.mdAll,
            ),
            child: Column(
              children: [
                Text(
                  Formatters.dayMonth(day).split(' ').last.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
                Text(
                  '${day.day}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Formatters.weekdayLong(day),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  relativeDayLabel(l10n, today, day),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: l10n.calendarRemoveDate,
            icon: const Icon(
              LucideIcons.x,
              size: AppSizing.iconSm,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
