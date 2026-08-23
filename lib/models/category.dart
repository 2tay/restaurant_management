/// A product category — "Fruits & Légumes", "Viandes", "Boissons".
///
/// Categories are created by the user inside the app, never hardcoded. Every
/// category dropdown offers an inline "+ Créer" option, and there is a full
/// management screen at `features/catalog`.
class Category {
  const Category({required this.id, required this.storeId, required this.name});

  final String id;
  final String storeId;
  final String name;

  /// Rebuilt rather than mutated, so the in-memory layer can replace the
  /// element in the mock list on a rename. A constructor convenience, not
  /// logic.
  Category copyWith({String? name}) =>
      Category(id: id, storeId: storeId, name: name ?? this.name);
}
