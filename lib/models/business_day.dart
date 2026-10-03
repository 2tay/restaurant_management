/// One journée de service — opened (by hand, or by the first Pointer), then
/// closed by hand. Every attendance clocked while it is open carries its
/// [date], even after midnight.
///
/// Immutable, no logic — same contract as every other model.
class BusinessDay {
  const BusinessDay({
    required this.id,
    required this.storeId,
    required this.date,
    required this.openedAt,
    this.openedByEmployeeId,
    this.closedAt,
    this.closedByEmployeeId,
  });

  final String id;
  final String storeId;

  /// The calendar day the journée opened on (midnight-normalised).
  final DateTime date;

  final DateTime openedAt;
  final String? openedByEmployeeId;

  /// Null while the journée is open.
  final DateTime? closedAt;
  final String? closedByEmployeeId;
}
