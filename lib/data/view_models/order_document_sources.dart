import '../../models/purchase_order.dart';
import '../../models/store.dart';
import '../../models/supplier.dart';
import 'receipt_document_sources.dart';

/// Everything the bon de commande needs beyond the order itself, gathered
/// in one place by the repository — the same seam as
/// [ReceiptDocumentSources], so the document's assembly stays a pure
/// function that a test can drive with literals.
class OrderDocumentSources {
  const OrderDocumentSources({
    required this.order,
    required this.store,
    required this.supplier,
    required this.items,
  });

  final PurchaseOrder order;

  /// Who is ordering — and where to deliver.
  final Store store;

  final Supplier supplier;

  /// Name and unit for each article on the order. An article deleted since
  /// is absent, and prints as a dash.
  final Map<String, ReceiptDocumentItem> items;
}
