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
    this.barcode,
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

  /// The product's barcode, if it has one.
  ///
  /// Optional and usually absent: produce, meat, fish and bread arrive loose
  /// or in the supplier's own crates and carry nothing to scan. Roughly half
  /// the catalogue — beverages and packaged dry goods — has one.
  ///
  /// Unique across the items of a store, enforced when the item form saves.
  /// Empty input stores as null rather than as an empty string, so "no
  /// barcode" is one value rather than two.
  ///
  /// Lookups by barcode return a **collection**, never a single item — see
  /// `MockQueries.itemsWithBarcode`. Multiple barcodes per item (a case and a
  /// single unit of the same beer) is a likely next requirement, and a
  /// collection-shaped lookup makes that a model change instead of a rewrite
  /// of every call site.
  final String? barcode;

  final String? note;

  /// Rebuilt rather than mutated, so the in-memory layer can replace the
  /// element in the mock list when a receipt moves stock.
  ///
  /// A constructor convenience, not logic — the brief's ban on methods that
  /// decide things still holds.
  Item copyWith({
    String? name,
    String? categoryId,
    String? unitId,
    double? quantity,
    double? lowStockThreshold,
    DateTime? updatedAt,
    String? defaultSupplierId,
    String? barcode,
    String? note,
  }) {
    return Item(
      id: id,
      storeId: storeId,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      unitId: unitId ?? this.unitId,
      quantity: quantity ?? this.quantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      updatedAt: updatedAt ?? this.updatedAt,
      defaultSupplierId: defaultSupplierId ?? this.defaultSupplierId,
      barcode: barcode ?? this.barcode,
      note: note ?? this.note,
    );
  }
}

/// How an item's quantity reads against its threshold.
///
/// Always rendered with an icon and a label alongside the colour — see
/// `StockStatusBadge`.
enum StockStatus { inStock, lowStock, outOfStock }
