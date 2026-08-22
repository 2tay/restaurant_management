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
