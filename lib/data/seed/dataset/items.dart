import '../../../models/item.dart';
import 'categories.dart';
import 'reference.dart';
import 'stores.dart';
import 'suppliers.dart';
import 'units.dart';

abstract final class ItemIds {
  // Fruits & Légumes
  static const String tomates = 'item-tomates';
  static const String pommesTerre = 'item-pommes-terre';
  static const String oignons = 'item-oignons';
  static const String carottes = 'item-carottes';
  static const String salade = 'item-salade';
  static const String champignons = 'item-champignons';
  static const String citrons = 'item-citrons';
  static const String persil = 'item-persil';

  // Viandes
  static const String poulet = 'item-poulet';
  static const String carbonade = 'item-carbonade';
  static const String lard = 'item-lard';
  static const String jambonArdenne = 'item-jambon-ardenne';
  static const String boulettes = 'item-boulettes';
  static const String filetAmericain = 'item-filet-americain';

  // Poissons
  static const String cabillaud = 'item-cabillaud';
  static const String moules = 'item-moules';
  static const String crevettes = 'item-crevettes';

  // Produits laitiers
  static const String beurre = 'item-beurre';
  static const String creme = 'item-creme';
  static const String gouda = 'item-gouda';
  static const String oeufs = 'item-oeufs';
  static const String lait = 'item-lait';

  // Boissons
  static const String jupiler = 'item-jupiler';
  static const String chimay = 'item-chimay';
  static const String duvel = 'item-duvel';
  static const String cola = 'item-cola';
  static const String eauPlate = 'item-eau-plate';
  static const String vinRouge = 'item-vin-rouge';
  static const String cafe = 'item-cafe';

  // Épicerie sèche
  static const String huileOlive = 'item-huile-olive';
  static const String farine = 'item-farine';
  static const String sel = 'item-sel';
  static const String poivre = 'item-poivre';
  static const String riz = 'item-riz';
  static const String vinaigre = 'item-vinaigre';
  static const String mayonnaise = 'item-mayonnaise';

  // Surgelés
  static const String frites = 'item-frites';
  static const String petitsPois = 'item-petits-pois';

  // Liège
  static const String liegeBoulets = 'item-liege-boulets';
  static const String liegeFrites = 'item-liege-frites';
  static const String liegeJupiler = 'item-liege-jupiler';
  static const String liegeSirop = 'item-liege-sirop';
  static const String liegeOignons = 'item-liege-oignons';
  static const String liegeCafe = 'item-liege-cafe';
}

/// The stocked items.
///
/// Quantities are set deliberately so all three stock statuses appear on the
/// first screen of the inventory list, and so the alerts screen has real
/// content without looking like the store is falling apart:
///
/// - 2 items at zero (rupture)
/// - 6 items at or below threshold (stock faible)
/// - the rest comfortably in stock
///
/// `StoreIds.saintGilles` has no items at all, on purpose — it is how the empty
/// states get demoed.
///
/// ## Why `averageCost` is a literal here
///
/// Every item carries a cost that is deliberately **not** its default
/// supplier's current price — mostly a little under it, a few exactly on it, a
/// couple above where the supplier has since come down. That is what stock
/// bought before the last round of price changes actually looks like, and it
/// means the valuation visibly is not `quantity × today's price`, which is the
/// entire point of the figure.
///
/// It is written out rather than replayed from `mockStockMovements`, because
/// that log covers about three weeks and does not reach back to each item's
/// opening balance. Replaying a partial history would produce a confident wrong
/// number, which is worse than an obviously seeded one.
///
/// **This is a seed shortcut, not the migration strategy.** Against real
/// storage the log runs from each article's first day and every stock-in
/// already records the price paid, so the correct backfill there is to replay
/// it. See `PLAN_STOCK_COST.md`.
final List<Item> mockItems = [
  // ---------------------------------------------------------------------------
  // Fruits & Légumes
  // ---------------------------------------------------------------------------
  Item(
    id: ItemIds.tomates,
    storeId: StoreIds.sablon,
    name: 'Tomates',
    categoryId: CategoryIds.legumes,
    unitId: UnitIds.kg,
    quantity: 4,
    lowStockThreshold: 5,
    updatedAt: hoursAgo(3),
    averageCost: 2.98,
    defaultSupplierId: SupplierIds.maraicher,
  ),
  Item(
    id: ItemIds.pommesTerre,
    storeId: StoreIds.sablon,
    name: 'Pommes de terre Bintje',
    categoryId: CategoryIds.legumes,
    unitId: UnitIds.kg,
    quantity: 85,
    lowStockThreshold: 25,
    updatedAt: daysAgo(1),
    averageCost: 1.01,
    defaultSupplierId: SupplierIds.maraicher,
  ),
  Item(
    id: ItemIds.oignons,
    storeId: StoreIds.sablon,
    name: 'Oignons jaunes',
    categoryId: CategoryIds.legumes,
    unitId: UnitIds.kg,
    quantity: 22,
    lowStockThreshold: 10,
    updatedAt: daysAgo(2),
    averageCost: 1.40,
    defaultSupplierId: SupplierIds.maraicher,
  ),
  Item(
    id: ItemIds.carottes,
    storeId: StoreIds.sablon,
    name: 'Carottes',
    categoryId: CategoryIds.legumes,
    unitId: UnitIds.kg,
    quantity: 18,
    lowStockThreshold: 8,
    updatedAt: daysAgo(2),
    averageCost: 1.25,
    defaultSupplierId: SupplierIds.maraicher,
  ),
  Item(
    id: ItemIds.salade,
    storeId: StoreIds.sablon,
    name: 'Salade iceberg',
    categoryId: CategoryIds.legumes,
    unitId: UnitIds.piece,
    quantity: 14,
    lowStockThreshold: 6,
    updatedAt: hoursAgo(20),
    averageCost: 1.16,
    defaultSupplierId: SupplierIds.maraicher,
  ),
  Item(
    id: ItemIds.champignons,
    storeId: StoreIds.sablon,
    name: 'Champignons de Paris',
    categoryId: CategoryIds.legumes,
    unitId: UnitIds.kg,
    quantity: 9.5,
    lowStockThreshold: 4,
    updatedAt: daysAgo(1),
    averageCost: 4.19,
    defaultSupplierId: SupplierIds.maraicher,
  ),
  Item(
    id: ItemIds.citrons,
    storeId: StoreIds.sablon,
    name: 'Citrons',
    categoryId: CategoryIds.legumes,
    unitId: UnitIds.kg,
    quantity: 2,
    lowStockThreshold: 3,
    updatedAt: daysAgo(3),
    averageCost: 3.33,
    defaultSupplierId: SupplierIds.grossisteCentral,
  ),
  Item(
    id: ItemIds.persil,
    storeId: StoreIds.sablon,
    name: 'Persil plat',
    categoryId: CategoryIds.legumes,
    unitId: UnitIds.botte,
    quantity: 0,
    lowStockThreshold: 4,
    updatedAt: daysAgo(1),
    averageCost: 1.25,
    defaultSupplierId: SupplierIds.maraicher,
    note: 'Rupture chez le maraîcher — recommander mardi.',
  ),

  // ---------------------------------------------------------------------------
  // Viandes
  // ---------------------------------------------------------------------------
  Item(
    id: ItemIds.poulet,
    storeId: StoreIds.sablon,
    name: 'Blanc de poulet',
    categoryId: CategoryIds.viandes,
    unitId: UnitIds.kg,
    quantity: 6,
    lowStockThreshold: 8,
    updatedAt: hoursAgo(5),
    averageCost: 11.01,
    defaultSupplierId: SupplierIds.grossisteCentral,
  ),
  Item(
    id: ItemIds.carbonade,
    storeId: StoreIds.sablon,
    name: 'Carbonade de bœuf',
    categoryId: CategoryIds.viandes,
    unitId: UnitIds.kg,
    quantity: 24,
    lowStockThreshold: 10,
    updatedAt: daysAgo(1),
    averageCost: 14.48,
    defaultSupplierId: SupplierIds.boucherie,
  ),
  Item(
    id: ItemIds.lard,
    storeId: StoreIds.sablon,
    name: 'Lard fumé',
    categoryId: CategoryIds.viandes,
    unitId: UnitIds.kg,
    quantity: 11,
    lowStockThreshold: 5,
    updatedAt: daysAgo(2),
    averageCost: 9.11,
    defaultSupplierId: SupplierIds.boucherie,
  ),
  Item(
    id: ItemIds.jambonArdenne,
    storeId: StoreIds.sablon,
    name: "Jambon d'Ardenne",
    categoryId: CategoryIds.viandes,
    unitId: UnitIds.kg,
    quantity: 7.5,
    lowStockThreshold: 3,
    updatedAt: daysAgo(4),
    averageCost: 19.71,
    defaultSupplierId: SupplierIds.boucherie,
  ),
  Item(
    id: ItemIds.boulettes,
    storeId: StoreIds.sablon,
    name: 'Boulettes de viande',
    categoryId: CategoryIds.viandes,
    unitId: UnitIds.piece,
    quantity: 120,
    lowStockThreshold: 40,
    updatedAt: daysAgo(1),
    averageCost: 0.95,
    defaultSupplierId: SupplierIds.boucherie,
  ),
  Item(
    id: ItemIds.filetAmericain,
    storeId: StoreIds.sablon,
    name: 'Filet américain préparé',
    categoryId: CategoryIds.viandes,
    unitId: UnitIds.kg,
    quantity: 5.5,
    lowStockThreshold: 2,
    updatedAt: hoursAgo(8),
    averageCost: 16.22,
    defaultSupplierId: SupplierIds.boucherie,
  ),

  // ---------------------------------------------------------------------------
  // Poissons & Fruits de mer
  // ---------------------------------------------------------------------------
  Item(
    id: ItemIds.cabillaud,
    storeId: StoreIds.sablon,
    name: 'Filet de cabillaud',
    categoryId: CategoryIds.poissons,
    unitId: UnitIds.kg,
    quantity: 8,
    lowStockThreshold: 4,
    updatedAt: hoursAgo(11),
    averageCost: 19.43,
    defaultSupplierId: SupplierIds.maree,
  ),
  Item(
    id: ItemIds.moules,
    storeId: StoreIds.sablon,
    name: 'Moules de Zélande',
    categoryId: CategoryIds.poissons,
    unitId: UnitIds.kg,
    quantity: 32,
    lowStockThreshold: 15,
    updatedAt: hoursAgo(11),
    averageCost: 5.82,
    defaultSupplierId: SupplierIds.maree,
  ),
  Item(
    id: ItemIds.crevettes,
    storeId: StoreIds.sablon,
    name: 'Crevettes grises',
    categoryId: CategoryIds.poissons,
    unitId: UnitIds.kg,
    quantity: 0,
    lowStockThreshold: 2,
    updatedAt: daysAgo(2),
    averageCost: 41.16,
    defaultSupplierId: SupplierIds.maree,
    note: 'Prix très élevé cette semaine — retirer de la carte du jour.',
  ),

  // ---------------------------------------------------------------------------
  // Produits laitiers
  // ---------------------------------------------------------------------------
  Item(
    id: ItemIds.beurre,
    storeId: StoreIds.sablon,
    name: 'Beurre de ferme',
    categoryId: CategoryIds.laitiers,
    unitId: UnitIds.kg,
    quantity: 3,
    lowStockThreshold: 4,
    updatedAt: hoursAgo(6),
    averageCost: 7.20,
    barcode: '5412033201148',
    defaultSupplierId: SupplierIds.cremerie,
  ),
  Item(
    id: ItemIds.creme,
    storeId: StoreIds.sablon,
    name: 'Crème fraîche 35%',
    categoryId: CategoryIds.laitiers,
    unitId: UnitIds.litre,
    quantity: 16,
    lowStockThreshold: 6,
    updatedAt: daysAgo(1),
    averageCost: 3.65,
    barcode: '5412033207195',
    defaultSupplierId: SupplierIds.cremerie,
  ),
  Item(
    id: ItemIds.gouda,
    storeId: StoreIds.sablon,
    name: 'Gouda jeune',
    categoryId: CategoryIds.laitiers,
    unitId: UnitIds.kg,
    quantity: 6.8,
    lowStockThreshold: 3,
    updatedAt: daysAgo(3),
    averageCost: 9.59,
    barcode: '5400101340077',
    defaultSupplierId: SupplierIds.cremerie,
  ),
  Item(
    id: ItemIds.oeufs,
    storeId: StoreIds.sablon,
    name: 'Œufs de poules élevées au sol',
    categoryId: CategoryIds.laitiers,
    unitId: UnitIds.piece,
    quantity: 240,
    lowStockThreshold: 90,
    updatedAt: daysAgo(2),
    averageCost: 0.30,
    barcode: '5410063011229',
    defaultSupplierId: SupplierIds.cremerie,
  ),
  Item(
    id: ItemIds.lait,
    storeId: StoreIds.sablon,
    name: 'Lait entier',
    categoryId: CategoryIds.laitiers,
    unitId: UnitIds.litre,
    quantity: 28,
    lowStockThreshold: 12,
    updatedAt: daysAgo(1),
    averageCost: 0.92,
    barcode: '5400101122086',
    defaultSupplierId: SupplierIds.cremerie,
  ),

  // ---------------------------------------------------------------------------
  // Boissons
  // ---------------------------------------------------------------------------
  Item(
    id: ItemIds.jupiler,
    storeId: StoreIds.sablon,
    name: 'Jupiler 33 cl',
    categoryId: CategoryIds.boissons,
    unitId: UnitIds.bac,
    quantity: 2,
    lowStockThreshold: 3,
    updatedAt: hoursAgo(2),
    averageCost: 21.50,
    barcode: '5412345001019',
    defaultSupplierId: SupplierIds.brasseurs,
  ),
  Item(
    id: ItemIds.chimay,
    storeId: StoreIds.sablon,
    name: 'Chimay Bleue 33 cl',
    categoryId: CategoryIds.boissons,
    unitId: UnitIds.caisse,
    quantity: 7,
    lowStockThreshold: 2,
    updatedAt: daysAgo(4),
    averageCost: 37.06,
    barcode: '5410908000114',
    defaultSupplierId: SupplierIds.brasseurs,
  ),
  Item(
    id: ItemIds.duvel,
    storeId: StoreIds.sablon,
    name: 'Duvel 33 cl',
    categoryId: CategoryIds.boissons,
    unitId: UnitIds.caisse,
    quantity: 5,
    lowStockThreshold: 2,
    updatedAt: daysAgo(4),
    averageCost: 35.91,
    barcode: '5411681000107',
    defaultSupplierId: SupplierIds.brasseurs,
  ),
  Item(
    id: ItemIds.cola,
    storeId: StoreIds.sablon,
    name: 'Coca-Cola 33 cl',
    categoryId: CategoryIds.boissons,
    unitId: UnitIds.bac,
    quantity: 9,
    lowStockThreshold: 4,
    updatedAt: daysAgo(3),
    averageCost: 17.06,
    barcode: '5449000000996',
    defaultSupplierId: SupplierIds.grossisteCentral,
  ),
  Item(
    id: ItemIds.eauPlate,
    storeId: StoreIds.sablon,
    name: 'Eau plate 50 cl',
    categoryId: CategoryIds.boissons,
    unitId: UnitIds.caisse,
    quantity: 12,
    lowStockThreshold: 5,
    updatedAt: daysAgo(3),
    averageCost: 7.74,
    barcode: '5410316901017',
    defaultSupplierId: SupplierIds.grossisteCentral,
  ),
  Item(
    id: ItemIds.vinRouge,
    storeId: StoreIds.sablon,
    name: 'Vin rouge Côtes du Rhône',
    categoryId: CategoryIds.boissons,
    unitId: UnitIds.piece,
    quantity: 34,
    lowStockThreshold: 12,
    updatedAt: daysAgo(7),
    averageCost: 6.80,
    barcode: '3263280120158',
    defaultSupplierId: SupplierIds.horecaSelect,
  ),
  Item(
    id: ItemIds.cafe,
    storeId: StoreIds.sablon,
    name: 'Café en grains',
    categoryId: CategoryIds.boissons,
    unitId: UnitIds.kg,
    quantity: 13,
    lowStockThreshold: 5,
    updatedAt: daysAgo(5),
    averageCost: 15.05,
    barcode: '5410127310014',
    defaultSupplierId: SupplierIds.horecaSelect,
  ),

  // ---------------------------------------------------------------------------
  // Épicerie sèche
  // ---------------------------------------------------------------------------
  Item(
    id: ItemIds.huileOlive,
    storeId: StoreIds.sablon,
    name: "Huile d'olive extra vierge",
    categoryId: CategoryIds.epicerie,
    unitId: UnitIds.litre,
    quantity: 4,
    lowStockThreshold: 5,
    updatedAt: daysAgo(2),
    averageCost: 9.08,
    barcode: '8410660301123',
    defaultSupplierId: SupplierIds.grossisteCentral,
  ),
  Item(
    id: ItemIds.farine,
    storeId: StoreIds.sablon,
    name: 'Farine T55',
    categoryId: CategoryIds.epicerie,
    unitId: UnitIds.kg,
    quantity: 45,
    lowStockThreshold: 15,
    updatedAt: daysAgo(6),
    averageCost: 0.79,
    defaultSupplierId: SupplierIds.grossisteCentral,
  ),
  Item(
    id: ItemIds.sel,
    storeId: StoreIds.sablon,
    name: 'Sel fin',
    categoryId: CategoryIds.epicerie,
    unitId: UnitIds.kg,
    quantity: 12,
    lowStockThreshold: 3,
    updatedAt: daysAgo(12),
    averageCost: 0.62,
    defaultSupplierId: SupplierIds.grossisteCentral,
  ),
  Item(
    id: ItemIds.poivre,
    storeId: StoreIds.sablon,
    name: 'Poivre noir moulu',
    categoryId: CategoryIds.epicerie,
    unitId: UnitIds.kg,
    quantity: 2.4,
    lowStockThreshold: 1,
    updatedAt: daysAgo(12),
    averageCost: 24.00,
    barcode: '5410041001225',
    defaultSupplierId: SupplierIds.grossisteCentral,
  ),
  Item(
    id: ItemIds.riz,
    storeId: StoreIds.sablon,
    name: 'Riz long grain',
    categoryId: CategoryIds.epicerie,
    unitId: UnitIds.kg,
    quantity: 26,
    lowStockThreshold: 10,
    updatedAt: daysAgo(8),
    averageCost: 1.87,
    barcode: '5400141002218',
    defaultSupplierId: SupplierIds.grossisteCentral,
  ),
  Item(
    id: ItemIds.vinaigre,
    storeId: StoreIds.sablon,
    name: 'Vinaigre de vin rouge',
    categoryId: CategoryIds.epicerie,
    unitId: UnitIds.litre,
    quantity: 8,
    lowStockThreshold: 3,
    updatedAt: daysAgo(9),
    averageCost: 2.42,
    barcode: '3011360001238',
    defaultSupplierId: SupplierIds.grossisteCentral,
  ),
  Item(
    id: ItemIds.mayonnaise,
    storeId: StoreIds.sablon,
    name: 'Mayonnaise',
    categoryId: CategoryIds.epicerie,
    unitId: UnitIds.litre,
    quantity: 15,
    lowStockThreshold: 6,
    updatedAt: daysAgo(5),
    averageCost: 3.78,
    barcode: '5410316414012',
    defaultSupplierId: SupplierIds.grossisteCentral,
  ),

  // ---------------------------------------------------------------------------
  // Surgelés
  // ---------------------------------------------------------------------------
  Item(
    id: ItemIds.frites,
    storeId: StoreIds.sablon,
    name: 'Frites surgelées',
    categoryId: CategoryIds.surgeles,
    unitId: UnitIds.kg,
    quantity: 96,
    lowStockThreshold: 40,
    updatedAt: hoursAgo(4),
    averageCost: 1.81,
    barcode: '5411188112204',
    defaultSupplierId: SupplierIds.grossisteCentral,
  ),
  Item(
    id: ItemIds.petitsPois,
    storeId: StoreIds.sablon,
    name: 'Petits pois surgelés',
    categoryId: CategoryIds.surgeles,
    unitId: UnitIds.kg,
    quantity: 18,
    lowStockThreshold: 8,
    updatedAt: daysAgo(4),
    averageCost: 2.20,
    barcode: '5410041220114',
    defaultSupplierId: SupplierIds.grossisteCentral,
  ),

  // ---------------------------------------------------------------------------
  // Le Comptoir de Liège — a thinner set, so switching stores visibly changes
  // what is on screen.
  // ---------------------------------------------------------------------------
  Item(
    id: ItemIds.liegeBoulets,
    storeId: StoreIds.liege,
    name: 'Boulets liégeois',
    categoryId: CategoryIds.liegeCuisine,
    unitId: UnitIds.liegePiece,
    quantity: 64,
    lowStockThreshold: 30,
    updatedAt: hoursAgo(6),
    averageCost: 1.55,
    defaultSupplierId: SupplierIds.liegeGrossiste,
  ),
  Item(
    id: ItemIds.liegeSirop,
    storeId: StoreIds.liege,
    name: 'Sirop de Liège',
    categoryId: CategoryIds.liegeCuisine,
    unitId: UnitIds.liegeKg,
    quantity: 1.5,
    lowStockThreshold: 2,
    updatedAt: daysAgo(3),
    averageCost: 8.57,
    barcode: '5411661000123',
    defaultSupplierId: SupplierIds.liegeGrossiste,
  ),
  Item(
    id: ItemIds.liegeFrites,
    storeId: StoreIds.liege,
    name: 'Frites surgelées',
    categoryId: CategoryIds.liegeCuisine,
    unitId: UnitIds.liegeKg,
    quantity: 52,
    lowStockThreshold: 25,
    updatedAt: daysAgo(1),
    averageCost: 1.77,
    barcode: '5411188112204',
    defaultSupplierId: SupplierIds.liegeGrossiste,
  ),
  Item(
    id: ItemIds.liegeOignons,
    storeId: StoreIds.liege,
    name: 'Oignons jaunes',
    categoryId: CategoryIds.liegeCuisine,
    unitId: UnitIds.liegeKg,
    quantity: 14,
    lowStockThreshold: 6,
    updatedAt: daysAgo(2),
    averageCost: 1.36,
    defaultSupplierId: SupplierIds.liegeGrossiste,
  ),
  Item(
    id: ItemIds.liegeJupiler,
    storeId: StoreIds.liege,
    name: 'Jupiler 33 cl',
    categoryId: CategoryIds.liegeBoissons,
    unitId: UnitIds.liegeBac,
    quantity: 11,
    lowStockThreshold: 4,
    updatedAt: hoursAgo(9),
    averageCost: 21.50,
    barcode: '5412345001019',
    defaultSupplierId: SupplierIds.liegeBrasseurs,
  ),
  Item(
    id: ItemIds.liegeCafe,
    storeId: StoreIds.liege,
    name: 'Café en grains',
    categoryId: CategoryIds.liegeBoissons,
    unitId: UnitIds.liegeKg,
    quantity: 0,
    lowStockThreshold: 3,
    updatedAt: daysAgo(1),
    averageCost: 17.47,
    barcode: '5410127310014',
    defaultSupplierId: SupplierIds.liegeGrossiste,
  ),
];
