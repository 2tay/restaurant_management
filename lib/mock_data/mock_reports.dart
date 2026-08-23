import '../models/report_figures.dart';
import 'mock_reference.dart';
import 'mock_suppliers.dart';

/// Pre-computed report figures.
///
/// Hardcoded rather than aggregated. The numbers are internally consistent with
/// `mock_items` and `mock_supplier_prices`, so nothing on screen contradicts
/// anything else — as long as nothing moves.
///
/// **The valuation figures below are no longer used.** Phase 1.7 made stock
/// mutable, and a frozen total that does not follow a delivery makes the
/// dashboard contradict the inventory two taps away. Valuation is now derived
/// in `MockQueries.stockValuation` and friends. These are kept only as the
/// reference the seeded dataset was balanced against.
///
/// The trend series are still static, and still used. Deriving usage and waste
/// from the movement log is a real piece of work rather than a line change, and
/// the movement log only covers the last few weeks in detail — a derived
/// six-month trend would be mostly flat zero, which would look like a bug
/// rather than like honesty. Phase 2 aggregates them properly.

/// Total stock value across the Sablon inventory, in EUR.
const double mockStockValuationTotal = 4812.65;

/// Stock valuation broken down by category, largest first.
const List<ValuationRow> mockValuationByCategory = [
  ValuationRow(
    label: 'Boissons',
    itemCount: 7,
    totalValue: 1486.30,
    shareOfTotal: 0.309,
  ),
  ValuationRow(
    label: 'Viandes',
    itemCount: 6,
    totalValue: 1122.45,
    shareOfTotal: 0.233,
  ),
  ValuationRow(
    label: 'Épicerie sèche',
    itemCount: 7,
    totalValue: 704.20,
    shareOfTotal: 0.146,
  ),
  ValuationRow(
    label: 'Poissons & Fruits de mer',
    itemCount: 3,
    totalValue: 352.80,
    shareOfTotal: 0.073,
  ),
  ValuationRow(
    label: 'Produits laitiers',
    itemCount: 5,
    totalValue: 349.516,
    shareOfTotal: 0.073,
  ),
  ValuationRow(
    label: 'Surgelés',
    itemCount: 2,
    totalValue: 217.20,
    shareOfTotal: 0.045,
  ),
  ValuationRow(
    label: 'Fruits & Légumes',
    itemCount: 8,
    totalValue: 580.19,
    shareOfTotal: 0.121,
  ),
];

/// The most valuable individual items, for the drilled-down valuation view.
const List<ValuationRow> mockValuationByItem = [
  ValuationRow(
    label: 'Chimay Bleue 33 cl',
    itemCount: 7,
    totalValue: 270.20,
    shareOfTotal: 0.056,
  ),
  ValuationRow(
    label: 'Vin rouge Côtes du Rhône',
    itemCount: 34,
    totalValue: 231.20,
    shareOfTotal: 0.048,
  ),
  ValuationRow(
    label: 'Café en grains',
    itemCount: 13,
    totalValue: 227.50,
    shareOfTotal: 0.047,
  ),
  ValuationRow(
    label: 'Moules de Zélande',
    itemCount: 32,
    totalValue: 204.80,
    shareOfTotal: 0.043,
  ),
  ValuationRow(
    label: 'Frites surgelées',
    itemCount: 96,
    totalValue: 177.60,
    shareOfTotal: 0.037,
  ),
  ValuationRow(
    label: 'Duvel 33 cl',
    itemCount: 5,
    totalValue: 171.00,
    shareOfTotal: 0.036,
  ),
  ValuationRow(
    label: "Jambon d'Ardenne",
    itemCount: 7,
    totalValue: 168.00,
    shareOfTotal: 0.035,
  ),
  ValuationRow(
    label: 'Carbonade de bœuf',
    itemCount: 24,
    totalValue: 340.80,
    shareOfTotal: 0.071,
  ),
];

/// Daily consumption value over the last 30 days, oldest first.
///
/// The weekly rhythm is deliberate: Belgian restaurant weeks peak Friday and
/// Saturday and dip Monday. A flat line would look synthetic on a chart.
final List<TrendPoint> mockUsageTrend = [
  TrendPoint(date: daysAgo(29), value: 182.40),
  TrendPoint(date: daysAgo(28), value: 96.10),
  TrendPoint(date: daysAgo(27), value: 141.75),
  TrendPoint(date: daysAgo(26), value: 168.30),
  TrendPoint(date: daysAgo(25), value: 264.90),
  TrendPoint(date: daysAgo(24), value: 312.55),
  TrendPoint(date: daysAgo(23), value: 228.70),
  TrendPoint(date: daysAgo(22), value: 174.20),
  TrendPoint(date: daysAgo(21), value: 88.45),
  TrendPoint(date: daysAgo(20), value: 152.60),
  TrendPoint(date: daysAgo(19), value: 179.85),
  TrendPoint(date: daysAgo(18), value: 289.30),
  TrendPoint(date: daysAgo(17), value: 341.20),
  TrendPoint(date: daysAgo(16), value: 245.65),
  TrendPoint(date: daysAgo(15), value: 191.40),
  TrendPoint(date: daysAgo(14), value: 102.30),
  TrendPoint(date: daysAgo(13), value: 158.90),
  TrendPoint(date: daysAgo(12), value: 187.25),
  TrendPoint(date: daysAgo(11), value: 296.80),
  TrendPoint(date: daysAgo(10), value: 358.40),
  TrendPoint(date: daysAgo(9), value: 261.15),
  TrendPoint(date: daysAgo(8), value: 203.70),
  TrendPoint(date: daysAgo(7), value: 94.85),
  TrendPoint(date: daysAgo(6), value: 166.20),
  TrendPoint(date: daysAgo(5), value: 194.55),
  TrendPoint(date: daysAgo(4), value: 305.10),
  TrendPoint(date: daysAgo(3), value: 372.90),
  TrendPoint(date: daysAgo(2), value: 274.35),
  TrendPoint(date: daysAgo(1), value: 218.60),
  TrendPoint(date: daysAgo(0), value: 143.25),
];

/// Waste and spoilage as a share of consumption, weekly, oldest first.
final List<TrendPoint> mockWasteTrend = [
  TrendPoint(date: daysAgo(28), value: 0.041),
  TrendPoint(date: daysAgo(21), value: 0.036),
  TrendPoint(date: daysAgo(14), value: 0.058),
  TrendPoint(date: daysAgo(7), value: 0.047),
  TrendPoint(date: daysAgo(0), value: 0.032),
];

/// Headline figures for the reports dashboard tiles.
const double mockUsageLast30Days = 6216.85;
const double mockWasteShareLast30Days = 0.043;
const double mockWasteValueLast30Days = 267.30;

/// Price comparison for blanc de poulet — the report's default view.
///
/// The default supplier is 1,35 €/kg above the cheapest. At roughly 30 kg a
/// week that is about 2 100 € a year on one item, which is the number that
/// sells this feature.
final List<PriceComparisonRow> mockPriceComparisonPoulet = [
  PriceComparisonRow(
    supplierId: SupplierIds.boucherie,
    supplierName: 'Boucherie Lambrechts',
    pricePerUnit: 11.45,
    lastUpdated: daysAgo(52),
    isDefault: false,
    isCheapest: true,
  ),
  PriceComparisonRow(
    supplierId: SupplierIds.grossisteCentral,
    supplierName: 'Grossiste Central Bruxelles',
    pricePerUnit: 12.80,
    lastUpdated: daysAgo(24),
    isDefault: true,
    isCheapest: false,
  ),
  PriceComparisonRow(
    supplierId: SupplierIds.horecaSelect,
    supplierName: 'Horeca Select',
    pricePerUnit: 13.20,
    lastUpdated: daysAgo(38),
    isDefault: false,
    isCheapest: false,
  ),
];

/// Comparison for an item where the store is already on the best price — the
/// report needs both outcomes or it reads as alarmist.
final List<PriceComparisonRow> mockPriceComparisonTomates = [
  PriceComparisonRow(
    supplierId: SupplierIds.maraicher,
    supplierName: 'Maraîcher Vandenbroucke',
    pricePerUnit: 3.20,
    lastUpdated: daysAgo(9),
    isDefault: true,
    isCheapest: true,
  ),
  PriceComparisonRow(
    supplierId: SupplierIds.grossisteCentral,
    supplierName: 'Grossiste Central Bruxelles',
    pricePerUnit: 3.95,
    lastUpdated: daysAgo(30),
    isDefault: false,
    isCheapest: false,
  ),
  PriceComparisonRow(
    supplierId: SupplierIds.horecaSelect,
    supplierName: 'Horeca Select',
    pricePerUnit: 4.10,
    lastUpdated: daysAgo(41),
    isDefault: false,
    isCheapest: false,
  ),
];

/// Estimated annual saving if every item switched to its cheapest supplier.
/// Shown on the reports dashboard as the hook into the comparison report.
const double mockPotentialAnnualSaving = 3480.00;
