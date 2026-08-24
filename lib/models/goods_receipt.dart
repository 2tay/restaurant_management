import 'goods_receipt_line.dart';

/// One delivery actually arriving against a commande.
///
/// **This is the only thing in the app that moves stock through an order.**
/// Creating an order for 50 kg of tomatoes does not put 50 kg on the shelf;
/// confirming a receipt does, by generating a Stock In movement per line.
///
/// A confirmed receipt is a permanent record: never edited, never deleted.
/// Corrections happen as a fresh stock adjustment, so the trail stays readable
/// — current quantity → movement → receipt → order → supplier.
class GoodsReceipt {
  const GoodsReceipt({
    required this.id,
    required this.orderId,
    required this.storeId,
    required this.receivedAt,
    required this.receivedByName,
    required this.lines,
    this.note,
  });

  final String id;

  /// The commande this delivery was against.
  final String orderId;

  final String storeId;

  final DateTime receivedAt;

  /// Display name of whoever stood at the door and checked it in. Receiving
  /// moves both stock and money, so who confirmed it is part of the record.
  final String receivedByName;

  final List<GoodsReceiptLine> lines;

  final String? note;
}
