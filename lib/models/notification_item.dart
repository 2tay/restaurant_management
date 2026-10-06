import 'employee.dart';

/// Whoever is looking at the feed: a signalement is read per person, so the
/// feed needs to know who.
typedef NotificationViewer = ({String id, EmployeeRole role});

/// What a notification is about.
enum NotificationKind {
  /// An item dropped to or below its threshold.
  lowStock,

  /// An item hit zero.
  outOfStock,

  /// A supplier's price for an item changed.
  priceChange,

  /// A stock adjustment moved a large quantity — worth a second look.
  largeAdjustment,

  /// A delivery was recorded.
  delivery,

  /// A busy period on the calendar is coming, and some products are below
  /// their busy-day minimum.
  busyDays,

  /// A signalement about the staff (SYNC_PERSONNEL_PLAN.md): something sync
  /// settled that a manager and the owner should check — a double pointage,
  /// a double payment. Always filed, no preference switches it off, and read
  /// separately by a manager and by the owner.
  personnel,
}

/// One entry in the notifications centre.
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.storeId,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.relatedItemId,
    this.relatedSupplierId,
    this.relatedEmployeeId,
    this.relatedTarget,
  });

  final String id;
  final String storeId;
  final NotificationKind kind;

  /// Short headline, e.g. "Stock faible : Blanc de poulet".
  final String title;

  /// One sentence of detail.
  final String body;

  final DateTime createdAt;

  /// Read **by whoever is looking**: for a signalement, by their role (a
  /// manager, the owner); for anything else, by anyone.
  final bool isRead;

  /// Lets the notification deep-link to the thing it is about.
  final String? relatedItemId;
  final String? relatedSupplierId;
  final String? relatedEmployeeId;

  /// `payroll` when a signalement opens the employee's payroll; null opens
  /// their pointage history.
  final String? relatedTarget;
}
