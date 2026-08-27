/// A stocked product.
///
/// Note what is **absent**: there is no `price` field, and that is deliberate.
/// One product can be supplied by several suppliers, each at their own price,
/// so price is an attribute of the item–supplier link rather than of the item.
/// See `SupplierPrice`.
///
/// Making the wrong model impossible to write is more reliable than documenting
/// the rule and hoping.
///
/// [averageCost] is **not** a counter-example to that rule. Price and cost
/// answer two different questions pointing in two different directions in time:
/// a price is what the *next* unit will cost, a cost is what the units *already
/// on the shelf* were paid for. Conflating them is what made the valuation
/// report revalue last week's stock at this morning's delivery price.
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
    this.averageCost,
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

  /// What one unit of the stock currently on hand actually cost, in EUR.
  ///
  /// The weighted average of everything that came in and has not yet gone out.
  /// A delivery remixes it — old stock keeps the cost it was bought at, and the
  /// new units join at the price paid. Stock leaving never moves it: consuming
  /// stock cannot change what the remaining stock cost you.
  ///
  /// This is the number the stock valuation is built on, and it is the reason
  /// the valuation is a fact rather than an estimate.
  ///
  /// Null means **unknown**, not zero: an item created with no cost and no
  /// supplier on file contributes nothing to the valuation. Understating beats
  /// inventing, which is the same rule the valuation followed before.
  ///
  /// Stored rather than derived, for the same reason [quantity] is: it depends
  /// on the *order* movements happened in, so deriving it would mean replaying
  /// the whole log on every read. Like [quantity], it stays rebuildable — every
  /// movement records the cost it applied and the average it produced.
  final double? averageCost;

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
  /// [averageCost] cannot be cleared back to null through here, and that is
  /// accepted rather than worked around: a cost is unknown only until the first
  /// movement that knows one, and it never becomes unknown again.
  Item copyWith({
    String? name,
    String? categoryId,
    String? unitId,
    double? quantity,
    double? lowStockThreshold,
    DateTime? updatedAt,
    double? averageCost,
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
      averageCost: averageCost ?? this.averageCost,
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
