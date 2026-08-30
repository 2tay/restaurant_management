import '../../models/purchase_order.dart';
import '../../models/store.dart';
import '../../models/supplier.dart';

/// An article as the bon de réception needs it: a name and a unit.
///
/// A record rather than a class because it is two strings that travel together
/// and never gain behaviour. Both are already resolved — the document works in
/// text, not in ids.
typedef ReceiptDocumentItem = ({String name, String unit});

/// Everything outside a `GoodsReceipt` that the bon de réception needs.
///
/// The receipt itself records what arrived and what it cost, but a document also
/// carries the establishment's letterhead, the supplier's address, the commande
/// it answers, and a name for every article on it. In Phase 1 the assembly
/// looked all of that up itself, from lists that were always in memory; there
/// is no such thing now, so the lookups are gathered once, here, and the
/// assembly becomes a pure function of the receipt and this.
///
/// That split is what makes the document testable without a database, and it is
/// the same seam `receipt_export.dart` already claimed to be — it just could not
/// keep the promise while it was calling `MockQueries` itself.
class ReceiptDocumentSources {
  const ReceiptDocumentSources({
    required this.order,
    required this.store,
    required this.supplier,
    required this.reference,
    required this.items,
  });

  /// The commande the delivery answers. Its lines carry the agreed prices,
  /// which is what a price réserve is measured against.
  final PurchaseOrder order;

  /// The issuer's letterhead.
  final Store store;

  final Supplier supplier;

  /// The quotable number — `BR-2026-014/2`. Derived from the receipt's position
  /// among its commande's deliveries, which only the data layer can resolve.
  final String reference;

  /// Keyed by article id. An article deleted since the delivery is simply
  /// absent: the document renders a dash rather than refusing to print, because
  /// a receipt is evidence and the evidence outlives the catalogue entry.
  final Map<String, ReceiptDocumentItem> items;
}
