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
}
