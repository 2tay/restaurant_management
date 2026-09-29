/// When an establishment expects to be busy, and how early it wants to hear
/// about it.
///
/// Two halves: the weekdays that are busy every week, and one-off dates — a
/// public holiday, a festival. Either one makes a day busy. On a busy day a
/// product is expected to hold its busy-day minimum
/// (`holidayMinimumOf` in `core/utils/stock_status.dart`) rather than the
/// ordinary one; see `core/utils/busy_calendar.dart` for the rules.
///
/// Immutable, no logic — same contract as every other model.
class BusyCalendar {
  const BusyCalendar({
    required this.storeId,
    required this.weekdays,
    required this.dates,
    required this.reminderDays,
  });

  final String storeId;

  /// ISO weekday numbers: `DateTime.monday` (1) to `DateTime.sunday` (7).
  final Set<int> weekdays;

  /// The one-off busy dates, each a local midnight (`DateTime(y, m, d)`).
  final Set<DateTime> dates;

  /// How many days before a busy period the reminder starts.
  final int reminderDays;
}
