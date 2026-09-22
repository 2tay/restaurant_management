/// The bon de commande sent to a supplier, as resolved data.
///
/// Every string is final — names looked up, dates formatted, labels
/// translated — so the renderer does nothing but lay it out, and a test can
/// build one from literals. The same split as [ReceiptDocument].
library;

import 'receipt_document.dart';

/// One line of the order: what, how much, at what price.
class OrderDocumentLine {
  const OrderDocumentLine({
    required this.itemName,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
  });

  final String itemName;
  final String unit;
  final double quantity;
  final double unitPrice;

  double get total => quantity * unitPrice;
}

class OrderDocument {
  const OrderDocument({
    required this.labels,
    required this.reference,
    required this.issuer,
    required this.supplier,
    required this.createdAt,
    required this.lines,
    required this.totalValue,
    required this.generatedAt,
    this.sentAt,
    this.isDraft = false,
    this.note,
  });

  final OrderDocumentLabels labels;
  final String reference;

  /// The store placing the order — and where to deliver.
  final ReceiptParty issuer;
  final ReceiptParty supplier;

  final String createdAt;
  final String? sentAt;
  final String generatedAt;

  /// Not sent yet: the PDF says so across its header, so a draft printed to
  /// check it is never mistaken for the order itself.
  final bool isDraft;

  final List<OrderDocumentLine> lines;
  final double totalValue;
  final String? note;

  /// `CMD-2026-014.pdf` — the reference, safe as a file name.
  String get fileName => '${reference.replaceAll(RegExp(r'[/\\ ]'), '-')}.pdf';
}

class OrderDocumentLabels {
  const OrderDocumentLabels({
    required this.title,
    required this.draft,
    required this.supplierBlock,
    required this.deliverTo,
    required this.orderDate,
    required this.sentAt,
    required this.columnItem,
    required this.columnQuantity,
    required this.columnUnitPrice,
    required this.columnTotal,
    required this.totalLabel,
    required this.noteLabel,
    required this.closing,
    required this.footer,
  });

  final String title;
  final String draft;
  final String supplierBlock;
  final String deliverTo;
  final String orderDate;
  final String sentAt;
  final String columnItem;
  final String columnQuantity;
  final String columnUnitPrice;
  final String columnTotal;
  final String totalLabel;
  final String noteLabel;

  /// The one sentence addressed to the supplier, above the footer.
  final String closing;
  final String footer;
}
