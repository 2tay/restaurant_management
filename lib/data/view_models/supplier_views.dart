import '../../models/supplier.dart';
import '../../models/supplier_price.dart';

/// One supplier on the list, with the number of articles they supply.
class SupplierRowView {
  const SupplierRowView({required this.supplier, required this.productCount});

  final Supplier supplier;

  /// How many articles this supplier offers a price for. Counted in the same
  /// query as the supplier, so the number beside a name cannot lag behind it.
  final int productCount;
}

/// One article a supplier offers, from the supplier's side of the link.
///
/// The mirror of `SupplierPriceView`, which looks at the same row from the
/// article's side. Both exist because both screens exist, and each carries the
/// name the other one already knows.
class SupplierProductView {
  const SupplierProductView({
    required this.price,
    required this.itemName,
    required this.unitAbbreviation,
    required this.categoryName,
    required this.cheapestPricePerUnit,
  });

  final SupplierPrice price;
  final String itemName;
  final String unitAbbreviation;

  /// What the article is filed under. Carried because the commande form's item
  /// picker shows it as a secondary label, and that picker is built from
  /// exactly this list — the articles one supplier sells.
  final String categoryName;

  /// The lowest price anybody charges for this article.
  ///
  /// Carried so the row can say whether this supplier is the cheapest without
  /// asking a second question per row — which is what the supplier screens did
  /// in Phase 1, once for every article on the page.
  final double cheapestPricePerUnit;

  /// Within a tenth of a cent of the best price available.
  ///
  /// The same tolerance the cost arithmetic uses. Comparing two doubles for
  /// equality would make a badge flicker on rounding noise.
  bool get isCheapest =>
      (price.pricePerUnit - cheapestPricePerUnit).abs() < 0.001;
}
