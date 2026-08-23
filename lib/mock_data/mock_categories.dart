import '../models/category.dart';
import 'mock_stores.dart';

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

const List<Category> mockCategories = [
  Category(
    id: CategoryIds.legumes,
    storeId: StoreIds.sablon,
    name: 'Fruits & Légumes',
  ),
  Category(id: CategoryIds.viandes, storeId: StoreIds.sablon, name: 'Viandes'),
  Category(
    id: CategoryIds.poissons,
    storeId: StoreIds.sablon,
    name: 'Poissons & Fruits de mer',
  ),
  Category(
    id: CategoryIds.laitiers,
    storeId: StoreIds.sablon,
    name: 'Produits laitiers',
  ),
  Category(
    id: CategoryIds.boissons,
    storeId: StoreIds.sablon,
    name: 'Boissons',
  ),
  Category(
    id: CategoryIds.epicerie,
    storeId: StoreIds.sablon,
    name: 'Épicerie sèche',
  ),
  Category(
    id: CategoryIds.surgeles,
    storeId: StoreIds.sablon,
    name: 'Surgelés',
  ),
  Category(
    id: CategoryIds.liegeBoissons,
    storeId: StoreIds.liege,
    name: 'Boissons',
  ),
  Category(
    id: CategoryIds.liegeCuisine,
    storeId: StoreIds.liege,
    name: 'Cuisine',
  ),
];
