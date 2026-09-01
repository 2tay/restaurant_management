import '../../models/purchase_order.dart';
import '../../models/stock_movement.dart';
import '../../models/supplier_price.dart';

/// One supplier's offer for an article, with the supplier already named.
class SupplierPriceView {
  const SupplierPriceView({required this.price, required this.supplierName});

  final SupplierPrice price;

  /// A dash when the supplier is gone. The link would go with them —
  /// `supplier_prices` cascades — so this is a belt-and-braces default rather
  /// than a state the app can reach.
  final String supplierName;
}

/// Every supplier of one article, and what using the wrong one costs.
///
/// The two travel together because they are the same question asked twice: the
/// list shows which supplier is cheapest, and the number above it says what the
/// gap between that one and the default is worth per unit. Splitting them would
/// let the screen show a callout about a supplier that is not in the table
/// underneath it.
class ItemPricing {
  const ItemPricing({required this.prices, required this.overpayPerUnit});

  /// **Cheapest first.** The order the comparison depends on: the first entry
  /// is the one the overpayment is measured against.
  final List<SupplierPriceView> prices;

  /// How much more the default supplier costs than the cheapest, per unit.
  /// Zero when the establishment is already on the best price, or when there is
  /// nothing to compare.
  final double overpayPerUnit;

  SupplierPriceView? get cheapest => prices.isEmpty ? null : prices.first;

  SupplierPriceView? get defaultPrice {
    for (final entry in prices) {
      if (entry.price.isDefault) return entry;
    }
    return null;
  }
}

/// A commande on a list, with its supplier already named.
class OrderRowView {
  const OrderRowView({
    required this.order,
    required this.supplierName,
    required this.outstandingForItem,
  });

  final PurchaseOrder order;
  final String supplierName;

  /// How much of the article being looked at this commande still owes.
  ///
  /// Zero on the commande lists, where the question is not being asked about
  /// any particular article.
  final double outstandingForItem;
}

/// What is on its way, and from whom.
class ItemOnOrder {
  const ItemOnOrder({required this.quantity, required this.orders});

  /// The total still expected across every open commande. Counted in SQL, not
  /// summed from [orders] — the two spellings of `lineOutstanding` are held to
  /// the same answer by a test.
  final double quantity;

  final List<OrderRowView> orders;

  static const ItemOnOrder none = ItemOnOrder(quantity: 0, orders: []);
}

/// One line of a movement log, with everything it names already resolved.
///
/// The movement log is the app's audit trail, and every row of it refers to
/// three other records: the article, its unit, and either the supplier who
/// delivered it or the commande it answers. Four lookups per row, in a list
/// that can run to hundreds — which is why this exists.
class MovementRowView {
  const MovementRowView({
    required this.movement,
    required this.itemName,
    required this.unitAbbreviation,
    this.supplierName,
    this.orderReference,
  });

  final StockMovement movement;

  /// A dash when the article has been deleted since. Movements outlive the
  /// articles they describe: `stock_movements` cascades from `items`, so this
  /// is reachable only in the window before the cascade — but the log is
  /// evidence, and evidence that refuses to render is worse than a dash.
  final String itemName;

  final String unitAbbreviation;

  /// Null for movements with no supplier — a stock-out, a correction, an
  /// opening balance — and for one whose supplier has since been deleted.
  final String? supplierName;

  /// `CMD-2026-014` when the movement came from a delivery, so a row in the log
  /// points back at the document that caused it.
  final String? orderReference;
}
