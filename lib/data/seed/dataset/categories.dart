import '../../../models/category.dart';
import 'stores.dart';

abstract final class CategoryIds {
  static const String legumes = 'cat-legumes';
  static const String viandes = 'cat-viandes';
  static const String poissons = 'cat-poissons';
  static const String laitiers = 'cat-laitiers';
  static const String boissons = 'cat-boissons';
  static const String epicerie = 'cat-epicerie';
  static const String surgeles = 'cat-surgeles';

  // Liège keeps its own categories — categories are per-store, so the second
  // location having a different set is the correct behaviour, not a bug.
  static const String liegeBoissons = 'cat-liege-boissons';
  static const String liegeCuisine = 'cat-liege-cuisine';
}

final List<Category> mockCategories = [
  const Category(
    id: CategoryIds.legumes,
    storeId: StoreIds.sablon,
    name: 'Fruits & Légumes',
  ),
  const Category(
    id: CategoryIds.viandes,
    storeId: StoreIds.sablon,
    name: 'Viandes',
  ),
  const Category(
    id: CategoryIds.poissons,
    storeId: StoreIds.sablon,
    name: 'Poissons & Fruits de mer',
  ),
  const Category(
    id: CategoryIds.laitiers,
    storeId: StoreIds.sablon,
    name: 'Produits laitiers',
  ),
  const Category(
    id: CategoryIds.boissons,
    storeId: StoreIds.sablon,
    name: 'Boissons',
  ),
  const Category(
    id: CategoryIds.epicerie,
    storeId: StoreIds.sablon,
    name: 'Épicerie sèche',
  ),
  const Category(
    id: CategoryIds.surgeles,
    storeId: StoreIds.sablon,
    name: 'Surgelés',
  ),
  const Category(
    id: CategoryIds.liegeBoissons,
    storeId: StoreIds.liege,
    name: 'Boissons',
  ),
  const Category(
    id: CategoryIds.liegeCuisine,
    storeId: StoreIds.liege,
    name: 'Cuisine',
  ),
];
