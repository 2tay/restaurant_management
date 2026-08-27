/// The bon de réception, as data.
///
/// A *bon de réception* is the buyer's own record of what was actually
/// accepted at the door — not the supplier's bon de livraison, which arrives
/// with the van. Where quantities or prices disagreed it becomes a bon de
/// réception **avec réserves**, and the réserves are the reason it gets emailed
/// back to the supplier at all.
///
/// Everything here is already resolved: names instead of ids, formatted strings
/// instead of `DateTime`s where the document only ever prints them, labels
/// instead of a localisation lookup. That is deliberate. The renderer in
/// `receipt_document_pdf.dart` takes one of these and can be tested with a
/// literal, and the assembly in `features/orders/documents/` is the only part
/// that needs the data layer or a `BuildContext`.
///
/// It is also, structurally, a **projection of an immutable record**. A
/// `GoodsReceipt` is never edited and never deleted, so the same receipt
/// produces the same document forever. Nothing here is stored — regenerate on
/// demand, never cache, and there is no question of which version was sent.
library;

/// One side of the document's header — the store issuing it, or the supplier it
/// concerns.
class ReceiptParty {
  const ReceiptParty({
    required this.name,
    required this.addressLine,
    required this.postalCode,
    required this.city,
    this.phone,
    this.email,
    this.contactName,
    this.vatNumber,
  });

  final String name;
  final String addressLine;
  final String postalCode;
  final String city;
  final String? phone;
  final String? email;
  final String? contactName;

  /// Null renders nothing at all rather than an empty `TVA` line.
  final String? vatNumber;

  /// `1000 Bruxelles` — Belgian order, postal code first.
  String get cityLine => '$postalCode $city'.trim();
}

/// One line of the delivery as it prints.
class ReceiptDocumentLine {
  const ReceiptDocumentLine({
    required this.itemName,
    required this.unit,
    required this.quantityOrdered,
    required this.quantityReceived,
    required this.orderedUnitPrice,
    required this.actualUnitPrice,
    this.wasUnordered = false,
    this.closedShort = false,
    this.note,
  });

  final String itemName;

  /// Unit abbreviation — `kg`, `L`, `pce`.
  final String unit;

  /// What was outstanding when the van arrived, not the original order
  /// quantity. Zero on an unordered line.
  final double quantityOrdered;

  final double quantityReceived;
  final double orderedUnitPrice;
  final double actualUnitPrice;
  final bool wasUnordered;
  final bool closedShort;
  final String? note;

  /// Signed: negative is short, positive is over. Always zero on an unordered
  /// line, which has nothing to be measured against.
  double get gap => wasUnordered ? 0 : quantityReceived - quantityOrdered;

  /// What this line was actually worth, at the price actually charged.
  double get total => quantityReceived * actualUnitPrice;

  /// The delivery note disagreed with the order.
  ///
  /// Uses the same tolerance as the write path in `order_mutations.dart`, so a
  /// line that printed a price réserve is exactly a line that wrote one to the
  /// price history. Unordered lines are excluded: there was no ordered price
  /// for them to differ from.
  bool get priceMoved =>
      !wasUnordered && (actualUnitPrice - orderedUnitPrice).abs() >= 0.001;
}

/// Everything the renderer needs, fully resolved.
class ReceiptDocument {
  const ReceiptDocument({
    required this.labels,
    required this.reference,
    required this.issuer,
    required this.supplier,
    required this.orderReference,
    required this.receivedAt,
    required this.receivedByName,
    required this.lines,
    required this.reserves,
    required this.totalValue,
    required this.generatedAt,
    this.orderSentAt,
    this.note,
  });

  final ReceiptDocumentLabels labels;

  /// `BR-2026-014/2` — derived, see `receiptReference` in `order_status.dart`.
  final String reference;

  final ReceiptParty issuer;
  final ReceiptParty supplier;

  /// The commande this delivery was against — `CMD-2026-014`.
  final String orderReference;

  /// Formatted, because the document only ever prints these.
  final String receivedAt;
  final String? orderSentAt;
  final String generatedAt;

  final String receivedByName;
  final List<ReceiptDocumentLine> lines;

  /// Ready-phrased réserves, in reading order. Empty means a clean delivery,
  /// and the renderer says so explicitly rather than dropping the section.
  final List<String> reserves;

  final double totalValue;

  /// The receipt-level remark, if the receiver left one.
  final String? note;

  /// A filename a human can find again in their downloads folder.
  ///
  /// Built from the reference rather than the id, and stripped of the
  /// separators that are awkward in a filename on Windows.
  String get fileName =>
      '${reference.replaceAll(RegExp(r'[/\\ ]'), '-')}.pdf';
}

/// Every fixed string on the document.
///
/// Passed in rather than looked up so the renderer stays free of
/// `BuildContext`. The values come from the ARB like everything else the user
/// reads — a document is not an excuse to hard-code French into a widget-free
/// file, even though this one is only ever produced in French today.
class ReceiptDocumentLabels {
  const ReceiptDocumentLabels({
    required this.title,
    required this.supplierBlock,
    required this.orderReference,
    required this.orderSent,
    required this.receivedAt,
    required this.receivedBy,
    required this.columnItem,
    required this.columnOrdered,
    required this.columnReceived,
    required this.columnGap,
    required this.columnOrderedPrice,
    required this.columnActualPrice,
    required this.columnTotal,
    required this.unordered,
    required this.reserves,
    required this.noReserves,
    required this.totalLabel,
    required this.noteLabel,
    required this.signatureReceiver,
    required this.signatureDriver,
    required this.footer,
    this.vatNumber,
  });

  final String title;
  final String supplierBlock;
  final String orderReference;
  final String orderSent;
  final String receivedAt;
  final String receivedBy;
  final String columnItem;
  final String columnOrdered;
  final String columnReceived;
  final String columnGap;
  final String columnOrderedPrice;
  final String columnActualPrice;
  final String columnTotal;
  final String unordered;
  final String reserves;
  final String noReserves;
  final String totalLabel;
  final String noteLabel;
  final String signatureReceiver;
  final String signatureDriver;

  /// Already interpolated with the generation date.
  final String footer;

  /// Already interpolated with the number, or null when the store has none.
  final String? vatNumber;
}
