import '../../models/item.dart';

/// Derives an item's [StockStatus] from its quantity and threshold.
///
/// This is the one piece of derivation Phase 1 keeps, and it lives here rather
/// than on [Item] for a reason: the brief bans methods with logic on the models
/// so that Phase 2 can bolt persistence onto them untouched. It is presentation
/// logic — how a number should *look* — not a business rule.
StockStatus stockStatusOf(Item item) {
  if (item.quantity <= 0) return StockStatus.outOfStock;
  if (item.quantity <= item.lowStockThreshold) return StockStatus.lowStock;
  return StockStatus.inStock;
}

/// True when the item needs attention on the alerts screen.
bool needsAttention(Item item) => stockStatusOf(item) != StockStatus.inStock;
