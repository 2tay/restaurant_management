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

/// How much of an article to put on a commande: enough to fill the shelf.
///
/// `maxStock - quantity`, rounded up to something a person would actually
/// order. The commande form pre-fills every line with this, whether the line
/// came from the suggestion panel, the "ajouter un article" button, or the
/// picker changing on a line that already existed.
///
/// Ordering the *shortfall below the threshold* instead — which is what the
/// form did before there was a maximum — refills an article to exactly its
/// alert line, where the next portion sold makes it low again and it reappears
/// on the next commande. Topping up to the maximum is the whole point of
/// having one.
///
/// Falls back to that older figure when no maximum has been declared, which is
/// what [Item.maxStock] of zero means: articles that predate the field, and
/// anything the user has left alone, keep ordering exactly as they did.
///
/// Never returns zero, even for a shelf that is already full — somebody
/// putting an article on a commande on purpose means to order some of it, and
/// a line defaulting to nothing is a line they have to fix by hand. It is the
/// pre-filled figure, not a limit: the stepper is right there.
///
/// It ignores what is already on order. Two commandes raised the same morning
/// for the same article will each suggest the full top-up. `onOrderQuantity`
/// is the figure that would fix it, and wiring it in is deliberately left for
/// its own change.
double topUpQuantity(Item item) {
  final target = item.maxStock > 0
      ? item.maxStock - item.quantity
      // The pre-maximum rule, kept whole: back up to the threshold, or one
      // threshold's worth for an article that is not actually low.
      : (item.lowStockThreshold - item.quantity > 0
            ? item.lowStockThreshold - item.quantity
            : item.lowStockThreshold);

  return target <= 0 ? 1 : target.ceilToDouble();
}
