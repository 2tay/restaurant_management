import 'purchase_order_line.dart';

/// Where a commande is in its life.
///
/// The order of the values is the order of the flow, so `index` can be used for
/// sorting a mixed list without a lookup table.
///
/// The rule the whole feature hangs on: **none of these transitions move
/// stock.** A commande is a document sent to a supplier. Goods arriving is a
/// separate event — see `GoodsReceipt` — and that event is the only thing that
/// changes what is on the shelf.
enum PurchaseOrderStatus {
  /// Being built. Not sent, so still fully editable and deletable.
  draft,

  /// Sent to the supplier, nothing received yet. Locked: the supplier already
  /// has the document, so changing it here would make the two disagree.
  sent,

  /// Some lines received, some still outstanding.
  partial,

  /// Fully received, or closed short by the receiver. Final.
  received,

  /// Cancelled before anything was received. Final.
  cancelled,
}

/// A purchase order — a commande — to exactly one supplier.
///
/// Single-supplier is structural rather than a convention: a commande is a
/// document that gets sent to somebody, and "somebody" has to be one company.
/// It is also what lets the line builder filter the item picker and auto-fill
/// prices, which is most of what makes the create screen quick to use.
class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.storeId,
    required this.supplierId,
    required this.reference,
    required this.status,
    required this.createdAt,
    required this.lines,
    this.sentAt,
    this.closedAt,
    this.note,
  });

  final String id;
  final String storeId;

  /// Exactly one. See the class doc.
  final String supplierId;

  /// The human-readable number staff quote on the phone — `CMD-2026-014`.
  /// Not the id: ids are for the machine and change shape in Phase 2.
  final String reference;

  final PurchaseOrderStatus status;

  /// When the draft was started.
  final DateTime createdAt;

  /// When it was sent to the supplier. Null while still a draft — and the
  /// clock the stale-partial warning counts from once receiving begins.
  final DateTime? sentAt;

  /// When it reached a final status, received or cancelled.
  final DateTime? closedAt;

  final List<PurchaseOrderLine> lines;

  final String? note;

  /// Rebuilt rather than mutated, which is what kept the model immutable while
  /// the storage underneath it changed completely. The repository writes a row
  /// and hands back a rebuilt commande; no call site noticed the difference.
  ///
  /// This is a constructor convenience, not business logic — the rules that
  /// decide *which* status to move to live in `core/utils/order_status.dart`.
  PurchaseOrder copyWith({
    PurchaseOrderStatus? status,
    DateTime? sentAt,
    DateTime? closedAt,
    List<PurchaseOrderLine>? lines,
    String? supplierId,
    String? note,
  }) {
    return PurchaseOrder(
      id: id,
      storeId: storeId,
      supplierId: supplierId ?? this.supplierId,
      reference: reference,
      status: status ?? this.status,
      createdAt: createdAt,
      sentAt: sentAt ?? this.sentAt,
      closedAt: closedAt ?? this.closedAt,
      lines: lines ?? this.lines,
      note: note ?? this.note,
    );
  }
}
