import '../../../core/utils/busy_calendar.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';

/// "demain", "dans 3 jours", or "en cours" once the period has started.
String busyWhenLabel(AppLocalizations l10n, DateTime today, DateTime start) {
  final days = daysBetween(today, start);
  if (days <= 0) return l10n.busyWhenOngoing;
  if (days == 1) return l10n.busyWhenTomorrow;
  return l10n.busyWhenInDays(days);
}

/// "vendredi 2 octobre", or "du vendredi 2 octobre au dimanche 4 octobre".
///
/// Lower-case, to sit mid-sentence; [capitalized] for the start of one.
String busyPeriodLabel(
  AppLocalizations l10n,
  BusyPeriod period, {
  bool capitalized = false,
}) {
  final start = Formatters.weekdayDayMonth(period.start);
  final label = period.start == period.end
      ? start
      : l10n.calendarPeriodRange(
          start,
          Formatters.weekdayDayMonth(period.end),
        );
  if (!capitalized || label.isEmpty) return label;
  return label[0].toUpperCase() + label.substring(1);
}
