import '../../models/goods_receipt.dart';
import '../../models/goods_receipt_line.dart';
import '../../models/purchase_order.dart';
import '../../models/purchase_order_line.dart';

/// One line of a commande, with the article it names already resolved.
class OrderLineView {
  const OrderLineView({
    required this.line,
    required this.itemName,
    required this.unitAbbreviation,
  });

  final PurchaseOrderLine line;

  /// A dash when the article has been deleted since. The app refuses to delete
  /// an article that sits on an open commande, so this is reachable only for a
  /// closed one — where the line is history and has to stay readable.
  final String itemName;

  final String unitAbbreviation;
}

/// One delivery against a commande, with its quotable number.
class ReceiptRowView {
  const ReceiptRowView({required this.receipt, required this.reference});

  final GoodsReceipt receipt;

  /// `BR-2026-014/2`. Derived from the receipt's position among its commande's
  /// deliveries, which is why it cannot be a getter on the model.
  final String reference;
}

/// Everything the commande detail screen shows.
///
/// One bundle rather than four watches. The screen has a header, a table of
/// lines and a list of deliveries, and all three are about the same document —
/// a header that had arrived before its lines would show a total that the table
/// underneath it did not add up to.
class OrderDetailView {
  const OrderDetailView({
    required this.order,
    required this.supplierName,
    required this.lines,
    required this.receipts,
  });

  final PurchaseOrder order;
  final String supplierName;

  /// In the commande's own order — the order the supplier reads.
  final List<OrderLineView> lines;

  /// **Oldest first**, which is what the `/2` in a receipt reference counts.
  final List<ReceiptRowView> receipts;
}

/// One line of a delivery, with the article it names already resolved.
class ReceiptLineView {
  const ReceiptLineView({
    required this.line,
    required this.itemName,
    required this.unitAbbreviation,
  });

  final GoodsReceiptLine line;
  final String itemName;
  final String unitAbbreviation;
}

/// Everything the bon de réception screen shows.
///
/// A receipt is append-only: once written it never changes, and neither does
/// its position among its commande's deliveries. That is why this is fetched
/// once rather than watched — there is nothing here for a later write to move.
class ReceiptDetailView {
  const ReceiptDetailView({
    required this.receipt,
    required this.reference,
    required this.orderReference,
    required this.lines,
  });

  final GoodsReceipt receipt;

  /// `BR-2026-014/2`.
  final String reference;

  /// `CMD-2026-014` — the commande this delivery answers. A dash if that
  /// commande has gone, which the app does not allow while receipts exist.
  final String orderReference;

  final List<ReceiptLineView> lines;
}
