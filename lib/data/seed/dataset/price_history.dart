import '../../../models/price_history_entry.dart';
import 'items.dart';
import 'reference.dart';
import 'suppliers.dart';

/// Recorded price changes, scoped to an item–supplier pair.
///
/// The blanc de poulet / Grossiste Central series is the demo narrative: four
/// increases over six months, 11,20 € to 12,80 €, a 14% climb nobody noticed
/// because each individual step looked small. That is the argument for the
/// whole feature, so it is the series the price history screen should open on.
///
/// Prices also fall (cabillaud, tomates) — a history that only ever goes up
/// looks staged.
final List<PriceHistoryEntry> mockPriceHistory = [
  // ---------------------------------------------------------------------------
  // Blanc de poulet — Grossiste Central. The slow climb.
  // ---------------------------------------------------------------------------
  PriceHistoryEntry(
    id: 'ph-poulet-1',
    itemId: ItemIds.poulet,
    supplierId: SupplierIds.grossisteCentral,
    oldPrice: 11.20,
    newPrice: 11.55,
    changedAt: monthsAgo(6),
    changedByName: 'Marc Delvaux',
  ),
  PriceHistoryEntry(
    id: 'ph-poulet-2',
    itemId: ItemIds.poulet,
    supplierId: SupplierIds.grossisteCentral,
    oldPrice: 11.55,
    newPrice: 11.95,
    changedAt: monthsAgo(4),
    changedByName: 'Amélie Vandenberghe',
  ),
  PriceHistoryEntry(
    id: 'ph-poulet-3',
    itemId: ItemIds.poulet,
    supplierId: SupplierIds.grossisteCentral,
    oldPrice: 11.95,
    newPrice: 12.40,
    changedAt: monthsAgo(2),
    changedByName: 'Amélie Vandenberghe',
  ),
  PriceHistoryEntry(
    id: 'ph-poulet-4',
    itemId: ItemIds.poulet,
    supplierId: SupplierIds.grossisteCentral,
    oldPrice: 12.40,
    newPrice: 12.80,
    changedAt: daysAgo(24),
    changedByName: 'Amélie Vandenberghe',
  ),

  // Same item, the cheaper supplier — much flatter. Side by side, this is the
  // comparison that makes the case.
  PriceHistoryEntry(
    id: 'ph-poulet-b1',
    itemId: ItemIds.poulet,
    supplierId: SupplierIds.boucherie,
    oldPrice: 11.20,
    newPrice: 11.45,
    changedAt: daysAgo(52),
    changedByName: 'Marc Delvaux',
  ),

  // ---------------------------------------------------------------------------
  // Huile d'olive — a sharp jump, the kind that should have triggered an alert.
  // ---------------------------------------------------------------------------
  PriceHistoryEntry(
    id: 'ph-huile-1',
    itemId: ItemIds.huileOlive,
    supplierId: SupplierIds.grossisteCentral,
    oldPrice: 7.40,
    newPrice: 8.10,
    changedAt: monthsAgo(3),
    changedByName: 'Marc Delvaux',
  ),
  PriceHistoryEntry(
    id: 'ph-huile-2',
    itemId: ItemIds.huileOlive,
    supplierId: SupplierIds.grossisteCentral,
    oldPrice: 8.10,
    newPrice: 8.90,
    changedAt: daysAgo(18),
    changedByName: 'Amélie Vandenberghe',
  ),

  // ---------------------------------------------------------------------------
  // Prices that fell.
  // ---------------------------------------------------------------------------
  PriceHistoryEntry(
    id: 'ph-cabillaud-1',
    itemId: ItemIds.cabillaud,
    supplierId: SupplierIds.maree,
    oldPrice: 21.00,
    newPrice: 19.40,
    changedAt: daysAgo(34),
    changedByName: 'Marc Delvaux',
  ),
  PriceHistoryEntry(
    id: 'ph-cabillaud-2',
    itemId: ItemIds.cabillaud,
    supplierId: SupplierIds.maree,
    oldPrice: 19.40,
    newPrice: 18.50,
    changedAt: daysAgo(7),
    changedByName: 'Marc Delvaux',
  ),
  PriceHistoryEntry(
    id: 'ph-tomates-1',
    itemId: ItemIds.tomates,
    supplierId: SupplierIds.maraicher,
    oldPrice: 4.10,
    newPrice: 3.55,
    changedAt: daysAgo(38),
    changedByName: 'Luc Vandenbroucke',
  ),
  PriceHistoryEntry(
    id: 'ph-tomates-2',
    itemId: ItemIds.tomates,
    supplierId: SupplierIds.maraicher,
    oldPrice: 3.55,
    newPrice: 3.20,
    changedAt: daysAgo(9),
    changedByName: 'Amélie Vandenberghe',
  ),

  // ---------------------------------------------------------------------------
  // Crevettes — the spike behind the "retirer de la carte du jour" note on the
  // item itself.
  // ---------------------------------------------------------------------------
  PriceHistoryEntry(
    id: 'ph-crevettes-1',
    itemId: ItemIds.crevettes,
    supplierId: SupplierIds.maree,
    oldPrice: 31.50,
    newPrice: 36.00,
    changedAt: daysAgo(21),
    changedByName: 'Marc Delvaux',
  ),
  PriceHistoryEntry(
    id: 'ph-crevettes-2',
    itemId: ItemIds.crevettes,
    supplierId: SupplierIds.maree,
    oldPrice: 36.00,
    newPrice: 42.00,
    changedAt: daysAgo(4),
    changedByName: 'Marc Delvaux',
  ),

  // ---------------------------------------------------------------------------
  // Assorted, so most items have at least something to show.
  // ---------------------------------------------------------------------------
  PriceHistoryEntry(
    id: 'ph-beurre-1',
    itemId: ItemIds.beurre,
    supplierId: SupplierIds.cremerie,
    oldPrice: 6.80,
    newPrice: 7.20,
    changedAt: daysAgo(16),
    changedByName: 'Sylvie Dupont',
  ),
  PriceHistoryEntry(
    id: 'ph-jupiler-1',
    itemId: ItemIds.jupiler,
    supplierId: SupplierIds.brasseurs,
    oldPrice: 20.40,
    newPrice: 21.50,
    changedAt: daysAgo(11),
    changedByName: 'Marc Delvaux',
  ),
  PriceHistoryEntry(
    id: 'ph-frites-1',
    itemId: ItemIds.frites,
    supplierId: SupplierIds.grossisteCentral,
    oldPrice: 1.70,
    newPrice: 1.85,
    changedAt: daysAgo(30),
    changedByName: 'Amélie Vandenberghe',
  ),
  PriceHistoryEntry(
    id: 'ph-carbonade-1',
    itemId: ItemIds.carbonade,
    supplierId: SupplierIds.boucherie,
    oldPrice: 13.60,
    newPrice: 14.20,
    changedAt: daysAgo(19),
    changedByName: 'Nathalie Lambrechts',
  ),
  PriceHistoryEntry(
    id: 'ph-gouda-1',
    itemId: ItemIds.gouda,
    supplierId: SupplierIds.cremerie,
    oldPrice: 9.10,
    newPrice: 9.40,
    changedAt: daysAgo(22),
    changedByName: 'Sylvie Dupont',
  ),
  // Written by confirming a delivery, not by editing a price screen. This is
  // the entry the receiving flow produces when the delivery note disagrees
  // with the ordered price.
  PriceHistoryEntry(
    id: 'ph-creme-receipt',
    itemId: ItemIds.creme,
    supplierId: SupplierIds.cremerie,
    oldPrice: 3.60,
    newPrice: 4.25,
    changedAt: daysAgo(11),
    changedByName: 'Marc Delvaux',
  ),
  PriceHistoryEntry(
    id: 'ph-cafe-1',
    itemId: ItemIds.cafe,
    supplierId: SupplierIds.horecaSelect,
    oldPrice: 16.20,
    newPrice: 17.50,
    changedAt: daysAgo(44),
    changedByName: 'Marc Delvaux',
  ),
];
