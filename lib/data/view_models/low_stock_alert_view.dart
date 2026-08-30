import 'item_row_view.dart';

/// One article on the low-stock screen, with everything that screen decides
/// from already answered.
///
/// The screen has to say three things per row and Phase 1 asked three questions
/// per row to say them: what it is, whether anybody has already ordered it, and
/// who would fill it. The middle one is the reason this screen exists at all —
/// "low, and somebody has already dealt with it" has to look different from
/// "low, and nobody has".
class LowStockAlertView {
  const LowStockAlertView({
    required this.row,
    required this.onOrderQuantity,
    this.defaultSupplierId,
    this.defaultSupplierName,
  });

  final ItemRowView row;

  /// How much is already on its way across every open commande. Zero means
  /// nobody has acted yet, which is what makes the row urgent.
  final double onOrderQuantity;

  /// Who the establishment usually buys this from — the supplier marked default
  /// among the article's offers, or the preference recorded on the article
  /// itself when it has no offers yet.
  final String? defaultSupplierId;

  /// Null when [defaultSupplierId] is, and also when it names a supplier that
  /// has since been deleted — in which case the row simply offers no ordering
  /// shortcut rather than one that leads nowhere.
  final String? defaultSupplierName;
}
