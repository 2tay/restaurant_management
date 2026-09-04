import '../../models/item.dart';

/// One article as the inventory list draws it.
///
/// The list shows a name, a category and a quantity with its unit. Two of those
/// three are lookups, and Phase 1 made them inside the row's `build` — so
/// scrolling a hundred articles was two hundred list scans per frame. Here they
/// are two joins, resolved once for the whole list.
///
/// Both names are already text. The row has no ids to resolve and no way to
/// resolve them, which is the point: a leaf widget that cannot query cannot
/// accidentally query per row.
class ItemRowView {
  const ItemRowView({
    required this.item,
    required this.categoryName,
    required this.unitAbbreviation,
  });

  final Item item;

  /// A dash when the category is gone. It cannot be — `items.categoryId` is
  /// `ON DELETE RESTRICT` — but the join is a left outer one, and a row that
  /// renders nothing at all would be harder to diagnose than a row with a dash.
  final String categoryName;

  final String unitAbbreviation;
}
