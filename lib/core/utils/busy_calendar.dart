import '../../models/busy_calendar.dart';
import '../../models/item.dart';
import 'stock_status.dart';

/// The defaults of the busy-day calendar. The schema's column defaults in
/// `tables/stores.dart` are these numbers, so change both together.
abstract final class BusyCalendarRules {
  /// Friday, Saturday and Sunday — the weekend rush.
  static const Set<int> defaultWeekdays = {
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  };

  static const int defaultReminderDays = 1;

  /// The choices the calendar screen offers.
  static const List<int> reminderChoices = [1, 2, 3, 5, 7];

  /// How far ahead to look for the next busy day. A year, so a single holiday
  /// marked eleven months out with no busy weekday is still found.
  static const int searchHorizonDays = 366;

  /// The longest a single busy period can run. Only reached when every
  /// weekday is ticked, where "the period" would otherwise never end.
  static const int maxPeriodDays = 31;
}

/// A run of consecutive busy days, both ends included, each a local midnight.
typedef BusyPeriod = ({DateTime start, DateTime end});

/// [value] at local midnight.
DateTime dayOf(DateTime value) => DateTime(value.year, value.month, value.day);

/// Whole calendar days from [from] to [to], ignoring the time of day.
///
/// Counted in UTC so a daylight-saving change between the two dates cannot
/// turn a 23-hour day into "zero days".
int daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

DateTime _addDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

/// Whether [date] is busy: its weekday is ticked, or it is marked on its own.
bool isBusyDay(DateTime date, BusyCalendar calendar) =>
    calendar.weekdays.contains(date.weekday) ||
    calendar.dates.contains(dayOf(date));

/// The busy period that contains [today], or else the next one to come.
///
/// Consecutive busy days are one period: Friday–Sunday is one weekend, and a
/// holiday on the Thursday before it makes Thursday–Sunday. Null when nothing
/// is busy within [BusyCalendarRules.searchHorizonDays].
BusyPeriod? nextBusyPeriod(DateTime today, BusyCalendar calendar) {
  final from = dayOf(today);

  DateTime? first;
  for (var i = 0; i <= BusyCalendarRules.searchHorizonDays; i++) {
    final day = _addDays(from, i);
    if (isBusyDay(day, calendar)) {
      first = day;
      break;
    }
  }
  if (first == null) return null;

  // Already inside a period: it started before today.
  var start = first;
  if (start == from) {
    for (var i = 0; i < BusyCalendarRules.maxPeriodDays; i++) {
      final before = _addDays(start, -1);
      if (!isBusyDay(before, calendar)) break;
      start = before;
    }
  }

  var end = first;
  for (var i = 0; i < BusyCalendarRules.maxPeriodDays; i++) {
    final after = _addDays(end, 1);
    if (!isBusyDay(after, calendar)) break;
    end = after;
  }

  return (start: start, end: end);
}

/// The busy period to warn about today, or null when there is none yet.
///
/// A period is warned about from [BusyCalendar.reminderDays] days before its
/// first day until its last day: the stock still matters while it is running.
BusyPeriod? activeBusyWarning(DateTime today, BusyCalendar calendar) {
  final period = nextBusyPeriod(today, calendar);
  if (period == null) return null;
  return daysBetween(today, period.start) <= calendar.reminderDays
      ? period
      : null;
}

/// The first day of the reminder for [period].
///
/// [BusyCalendar.reminderDays] before it starts, but never before the day
/// after the previous busy period ends. With a weekend every week and a
/// seven-day reminder, next weekend's reminder would otherwise begin inside
/// this one — and whatever was said about this weekend would pass for it.
DateTime reminderStartOf(BusyPeriod period, BusyCalendar calendar) {
  var day = period.start;
  for (var i = 0; i < calendar.reminderDays; i++) {
    final before = _addDays(day, -1);
    if (isBusyDay(before, calendar)) break;
    day = before;
  }
  return day;
}

/// Whether [day] falls in the reminder for the busy period after it: not busy
/// itself, but inside that period's reminder days. The calendar marks these,
/// so the owner sees when the warning will come as well as what it is for.
bool isReminderDay(DateTime day, BusyCalendar calendar) {
  if (isBusyDay(day, calendar)) return false;
  final period = nextBusyPeriod(day, calendar);
  if (period == null) return false;
  return !dayOf(day).isBefore(reminderStartOf(period, calendar));
}

/// How much a product is short of its busy-day minimum, or zero.
double busyShortfallOf(Item item) {
  final gap = holidayMinimumOf(item) - item.quantity;
  return gap > 0 ? gap : 0;
}

/// How much to put on a commande ahead of busy days: the ordinary top-up,
/// or enough to reach the busy-day minimum when that is more — a product
/// whose maximum sits under its busy-day minimum would otherwise be ordered
/// short of the very figure it is on the list for.
double busyTopUpQuantity(Item item) {
  final shortfall = busyShortfallOf(item).ceilToDouble();
  final topUp = topUpQuantity(item);
  return shortfall > topUp ? shortfall : topUp;
}

/// Whether a product is below its busy-day minimum.
bool isBelowBusyMinimum(Item item) => busyShortfallOf(item) > 0;
