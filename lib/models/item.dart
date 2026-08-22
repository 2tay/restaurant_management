/// A stocked product.
///
/// Note what is **absent**: there is no `cost` or `price` field, and that is
/// deliberate. One product can be supplied by several suppliers, each at their
/// own price, so price is an attribute of the item–supplier link rather than of
/// the item. See `SupplierPrice`.
///
/// Making the wrong model impossible to write is more reliable than documenting
/// the rule and hoping.
class Item {
  const Item({
    required this.id,
    required this.storeId,
    required this.name,
    required this.categoryId,
    required this.unitId,
    required this.quantity,
    required this.lowStockThreshold,
    required this.updatedAt,
    this.defaultSupplierId,
    this.note,
  });

  final String id;
  final String storeId;
  final String name;
  final String categoryId;
  final String unitId;

  /// Current quantity on hand, in the item's unit.
  final double quantity;

  /// At or below this, the item reads as "Stock faible". At zero it reads as
  /// "Rupture de stock". See `core/utils/stock_status.dart`.
  final double lowStockThreshold;

  final DateTime updatedAt;

  /// The supplier pre-selected when receiving a delivery. Optional — an item
  /// can have several suppliers and no declared preference.
  final String? defaultSupplierId;

  final String? note;
}

/// How an item's quantity reads against its threshold.
///
/// Always rendered with an icon and a label alongside the colour — see
/// `StockStatusBadge`.
enum StockStatus { inStock, lowStock, outOfStock }
