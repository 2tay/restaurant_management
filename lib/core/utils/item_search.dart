import '../../models/item.dart';

/// Whether an item matches a search box.
///
/// Written once and shared by the inventory list and global search, so "pasting
/// a barcode finds the item" cannot be true on one screen and false on the
/// other. [query] must already be trimmed and lower-cased.
///
/// Name matching is a substring; barcode matching is exact, because a partial
/// barcode is not a barcode and offering fuzzy matches for one would be worse
/// than offering nothing.
///
/// Stays a Dart predicate over already-loaded items rather than becoming a SQL
/// `LIKE`. Two reasons: `LOWER()` in SQLite folds ASCII only, so searching
/// "épicerie" would stop matching "Épicerie"; and a leading-wildcard `LIKE`
/// cannot use an index anyway, so the database would be scanning the same rows
/// the caller already has.
bool itemMatchesSearch(Item item, String query) {
  if (query.isEmpty) return true;
  if (item.name.toLowerCase().contains(query)) return true;
  return item.barcode != null && item.barcode!.toLowerCase() == query;
}
