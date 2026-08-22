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
  });

  final String id;
  final String storeId;
  final NotificationKind kind;

  /// Short headline, e.g. "Stock faible : Blanc de poulet".
  final String title;

  /// One sentence of detail.
  final String body;

  final DateTime createdAt;
  final bool isRead;

  /// Lets the notification deep-link to the thing it is about.
  final String? relatedItemId;
  final String? relatedSupplierId;
}
