/// Shared time anchor for the mock dataset.
///
/// Every date in `mock_data/` is expressed as an offset from [mockNow] rather
/// than as a literal, so the demo always looks current — a prototype showing
/// "dernière livraison il y a 8 mois" undermines itself in front of a client.
///
/// The cost is that dates are non-deterministic, so tests must not assert on
/// them.
final DateTime mockNow = DateTime.now();

DateTime daysAgo(int days) => mockNow.subtract(Duration(days: days));

DateTime hoursAgo(int hours) => mockNow.subtract(Duration(hours: hours));

DateTime monthsAgo(int months) => mockNow.subtract(Duration(days: months * 30));

/// Midnight, [days] ago — the value a `TimeEntry.date` is normalized to,
/// since a work day is filed under a date rather than a timestamp.
DateTime dayOnly(int days) {
  final day = daysAgo(days);
  return DateTime(day.year, day.month, day.day);
}

/// A specific clock time, [days] ago. For mock data that needs a precise time
/// of day — a clock-in, a break — rather than just an offset from now.
DateTime timeOnDay(int days, int hour, [int minute = 0]) {
  final day = daysAgo(days);
  return DateTime(day.year, day.month, day.day, hour, minute);
}
