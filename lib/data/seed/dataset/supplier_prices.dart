import '../../../models/supplier_price.dart';
import 'items.dart';
import 'reference.dart';
import 'suppliers.dart';

/// Item–supplier links, each carrying its own price.
///
/// Several items are deliberately supplied by three suppliers at meaningfully
/// different prices. Four of them — poulet, huile d'olive, frites and citrons —
/// have a default supplier that is **not** the cheapest, so the price
/// comparison report opens on a real finding rather than on a screen full of
/// "vous payez déjà le meilleur prix". That report is the app's selling point;
/// it needs something to actually say.
final List<SupplierPrice> mockSupplierPrices = [
  // ---------------------------------------------------------------------------
  // Blanc de poulet — the headline comparison. Default is 1,35 €/kg over the
  // cheapest offer, on an item the kitchen goes through constantly.
  // ---------------------------------------------------------------------------
  SupplierPrice(
    id: 'sp-poulet-central',
    itemId: ItemIds.poulet,
    supplierId: SupplierIds.grossisteCentral,
    pricePerUnit: 12.80,
    effectiveDate: daysAgo(24),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-poulet-boucherie',
    itemId: ItemIds.poulet,
    supplierId: SupplierIds.boucherie,
    pricePerUnit: 11.45,
    effectiveDate: daysAgo(52),
    isDefault: false,
  ),
  SupplierPrice(
    id: 'sp-poulet-horeca',
    itemId: ItemIds.poulet,
    supplierId: SupplierIds.horecaSelect,
    pricePerUnit: 13.20,
    effectiveDate: daysAgo(38),
    isDefault: false,
  ),

  // ---------------------------------------------------------------------------
  // Huile d'olive — also overpaying.
  // ---------------------------------------------------------------------------
  SupplierPrice(
    id: 'sp-huile-central',
    itemId: ItemIds.huileOlive,
    supplierId: SupplierIds.grossisteCentral,
    pricePerUnit: 8.90,
    effectiveDate: daysAgo(18),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-huile-horeca',
    itemId: ItemIds.huileOlive,
    supplierId: SupplierIds.horecaSelect,
    pricePerUnit: 7.75,
    effectiveDate: daysAgo(45),
    isDefault: false,
  ),

  // ---------------------------------------------------------------------------
  // Frites — small unit difference, very large volume. Worth flagging.
  // ---------------------------------------------------------------------------
  SupplierPrice(
    id: 'sp-frites-central',
    itemId: ItemIds.frites,
    supplierId: SupplierIds.grossisteCentral,
    pricePerUnit: 1.85,
    effectiveDate: daysAgo(30),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-frites-horeca',
    itemId: ItemIds.frites,
    supplierId: SupplierIds.horecaSelect,
    pricePerUnit: 1.72,
    effectiveDate: daysAgo(21),
    isDefault: false,
  ),

  SupplierPrice(
    id: 'sp-citrons-central',
    itemId: ItemIds.citrons,
    supplierId: SupplierIds.grossisteCentral,
    pricePerUnit: 3.40,
    effectiveDate: daysAgo(28),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-citrons-maraicher',
    itemId: ItemIds.citrons,
    supplierId: SupplierIds.maraicher,
    pricePerUnit: 2.95,
    effectiveDate: daysAgo(14),
    isDefault: false,
  ),

  // ---------------------------------------------------------------------------
  // Items where the default already is the cheapest — the report needs both
  // outcomes or it reads as alarmist.
  // ---------------------------------------------------------------------------
  SupplierPrice(
    id: 'sp-tomates-maraicher',
    itemId: ItemIds.tomates,
    supplierId: SupplierIds.maraicher,
    pricePerUnit: 3.20,
    effectiveDate: daysAgo(9),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-tomates-central',
    itemId: ItemIds.tomates,
    supplierId: SupplierIds.grossisteCentral,
    pricePerUnit: 3.95,
    effectiveDate: daysAgo(30),
    isDefault: false,
  ),
  SupplierPrice(
    id: 'sp-tomates-horeca',
    itemId: ItemIds.tomates,
    supplierId: SupplierIds.horecaSelect,
    pricePerUnit: 4.10,
    effectiveDate: daysAgo(41),
    isDefault: false,
  ),

  SupplierPrice(
    id: 'sp-beurre-cremerie',
    itemId: ItemIds.beurre,
    supplierId: SupplierIds.cremerie,
    pricePerUnit: 7.20,
    effectiveDate: daysAgo(16),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-beurre-central',
    itemId: ItemIds.beurre,
    supplierId: SupplierIds.grossisteCentral,
    pricePerUnit: 7.85,
    effectiveDate: daysAgo(33),
    isDefault: false,
  ),
  SupplierPrice(
    id: 'sp-beurre-horeca',
    itemId: ItemIds.beurre,
    supplierId: SupplierIds.horecaSelect,
    pricePerUnit: 8.05,
    effectiveDate: daysAgo(47),
    isDefault: false,
  ),

  SupplierPrice(
    id: 'sp-jupiler-brasseurs',
    itemId: ItemIds.jupiler,
    supplierId: SupplierIds.brasseurs,
    pricePerUnit: 21.50,
    effectiveDate: daysAgo(11),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-jupiler-central',
    itemId: ItemIds.jupiler,
    supplierId: SupplierIds.grossisteCentral,
    pricePerUnit: 23.90,
    effectiveDate: daysAgo(35),
    isDefault: false,
  ),

  SupplierPrice(
    id: 'sp-gouda-cremerie',
    itemId: ItemIds.gouda,
    supplierId: SupplierIds.cremerie,
    pricePerUnit: 9.40,
    effectiveDate: daysAgo(22),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-gouda-central',
    itemId: ItemIds.gouda,
    supplierId: SupplierIds.grossisteCentral,
    pricePerUnit: 10.10,
    effectiveDate: daysAgo(40),
    isDefault: false,
  ),

  SupplierPrice(
    id: 'sp-carbonade-boucherie',
    itemId: ItemIds.carbonade,
    supplierId: SupplierIds.boucherie,
    pricePerUnit: 14.20,
    effectiveDate: daysAgo(19),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-carbonade-central',
    itemId: ItemIds.carbonade,
    supplierId: SupplierIds.grossisteCentral,
    pricePerUnit: 15.40,
    effectiveDate: daysAgo(37),
    isDefault: false,
  ),

  SupplierPrice(
    id: 'sp-cabillaud-maree',
    itemId: ItemIds.cabillaud,
    supplierId: SupplierIds.maree,
    pricePerUnit: 18.50,
    effectiveDate: daysAgo(7),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-cabillaud-central',
    itemId: ItemIds.cabillaud,
    supplierId: SupplierIds.grossisteCentral,
    pricePerUnit: 19.90,
    effectiveDate: daysAgo(29),
    isDefault: false,
  ),

  // ---------------------------------------------------------------------------
  // Single-supplier items. Most of an inventory looks like this; the multi
  // supplier items above are the interesting minority.
  // ---------------------------------------------------------------------------
  SupplierPrice(
    id: 'sp-pommes-maraicher',
    itemId: ItemIds.pommesTerre,
    supplierId: SupplierIds.maraicher,
    pricePerUnit: 1.15,
    effectiveDate: daysAgo(13),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-oignons-maraicher',
    itemId: ItemIds.oignons,
    supplierId: SupplierIds.maraicher,
    pricePerUnit: 1.40,
    effectiveDate: daysAgo(13),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-carottes-maraicher',
    itemId: ItemIds.carottes,
    supplierId: SupplierIds.maraicher,
    pricePerUnit: 1.30,
    effectiveDate: daysAgo(13),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-salade-maraicher',
    itemId: ItemIds.salade,
    supplierId: SupplierIds.maraicher,
    pricePerUnit: 1.10,
    effectiveDate: daysAgo(13),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-champignons-maraicher',
    itemId: ItemIds.champignons,
    supplierId: SupplierIds.maraicher,
    pricePerUnit: 4.60,
    effectiveDate: daysAgo(13),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-persil-maraicher',
    itemId: ItemIds.persil,
    supplierId: SupplierIds.maraicher,
    pricePerUnit: 1.25,
    effectiveDate: daysAgo(25),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-lard-boucherie',
    itemId: ItemIds.lard,
    supplierId: SupplierIds.boucherie,
    pricePerUnit: 9.80,
    effectiveDate: daysAgo(26),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-jambon-boucherie',
    itemId: ItemIds.jambonArdenne,
    supplierId: SupplierIds.boucherie,
    pricePerUnit: 22.40,
    effectiveDate: daysAgo(26),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-boulettes-boucherie',
    itemId: ItemIds.boulettes,
    supplierId: SupplierIds.boucherie,
    pricePerUnit: 0.95,
    effectiveDate: daysAgo(26),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-americain-boucherie',
    itemId: ItemIds.filetAmericain,
    supplierId: SupplierIds.boucherie,
    pricePerUnit: 16.90,
    effectiveDate: daysAgo(20),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-moules-maree',
    itemId: ItemIds.moules,
    supplierId: SupplierIds.maree,
    pricePerUnit: 6.40,
    effectiveDate: daysAgo(7),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-crevettes-maree',
    itemId: ItemIds.crevettes,
    supplierId: SupplierIds.maree,
    pricePerUnit: 42.00,
    effectiveDate: daysAgo(4),
    isDefault: true,
  ),
  // Raised by the Crémerie delivery eleven days ago rather than by anybody
  // editing a price screen — see `mock_goods_receipts.dart`. That is how price
  // history is meant to get written.
  SupplierPrice(
    id: 'sp-creme-cremerie',
    itemId: ItemIds.creme,
    supplierId: SupplierIds.cremerie,
    pricePerUnit: 4.25,
    effectiveDate: daysAgo(11),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-oeufs-cremerie',
    itemId: ItemIds.oeufs,
    supplierId: SupplierIds.cremerie,
    pricePerUnit: 0.32,
    effectiveDate: daysAgo(22),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-lait-cremerie',
    itemId: ItemIds.lait,
    supplierId: SupplierIds.cremerie,
    pricePerUnit: 1.05,
    effectiveDate: daysAgo(22),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-chimay-brasseurs',
    itemId: ItemIds.chimay,
    supplierId: SupplierIds.brasseurs,
    pricePerUnit: 38.60,
    effectiveDate: daysAgo(11),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-duvel-brasseurs',
    itemId: ItemIds.duvel,
    supplierId: SupplierIds.brasseurs,
    pricePerUnit: 34.20,
    effectiveDate: daysAgo(11),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-cola-central',
    itemId: ItemIds.cola,
    supplierId: SupplierIds.grossisteCentral,
    pricePerUnit: 18.75,
    effectiveDate: daysAgo(31),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-eau-central',
    itemId: ItemIds.eauPlate,
    supplierId: SupplierIds.grossisteCentral,
    pricePerUnit: 7.90,
    effectiveDate: daysAgo(31),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-vin-horeca',
    itemId: ItemIds.vinRouge,
    supplierId: SupplierIds.horecaSelect,
    pricePerUnit: 6.80,
    effectiveDate: daysAgo(44),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-cafe-horeca',
    itemId: ItemIds.cafe,
    supplierId: SupplierIds.horecaSelect,
    pricePerUnit: 17.50,
    effectiveDate: daysAgo(44),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-farine-central',
    itemId: ItemIds.farine,
    supplierId: SupplierIds.grossisteCentral,
    pricePerUnit: 0.85,
    effectiveDate: daysAgo(31),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-sel-central',
    itemId: ItemIds.sel,
    supplierId: SupplierIds.grossisteCentral,
    pricePerUnit: 0.70,
    effectiveDate: daysAgo(31),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-poivre-central',
    itemId: ItemIds.poivre,
    supplierId: SupplierIds.grossisteCentral,
    pricePerUnit: 24.00,
    effectiveDate: daysAgo(31),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-riz-central',
    itemId: ItemIds.riz,
    supplierId: SupplierIds.grossisteCentral,
    pricePerUnit: 1.95,
    effectiveDate: daysAgo(31),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-vinaigre-central',
    itemId: ItemIds.vinaigre,
    supplierId: SupplierIds.grossisteCentral,
    pricePerUnit: 2.30,
    effectiveDate: daysAgo(31),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-mayonnaise-central',
    itemId: ItemIds.mayonnaise,
    supplierId: SupplierIds.grossisteCentral,
    pricePerUnit: 4.15,
    effectiveDate: daysAgo(31),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-pois-central',
    itemId: ItemIds.petitsPois,
    supplierId: SupplierIds.grossisteCentral,
    pricePerUnit: 2.20,
    effectiveDate: daysAgo(30),
    isDefault: true,
  ),

  // ---------------------------------------------------------------------------
  // Le Comptoir de Liège
  // ---------------------------------------------------------------------------
  SupplierPrice(
    id: 'sp-liege-boulets',
    itemId: ItemIds.liegeBoulets,
    supplierId: SupplierIds.liegeGrossiste,
    pricePerUnit: 1.80,
    effectiveDate: daysAgo(17),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-liege-sirop',
    itemId: ItemIds.liegeSirop,
    supplierId: SupplierIds.liegeGrossiste,
    pricePerUnit: 8.40,
    effectiveDate: daysAgo(17),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-liege-frites',
    itemId: ItemIds.liegeFrites,
    supplierId: SupplierIds.liegeGrossiste,
    pricePerUnit: 1.90,
    effectiveDate: daysAgo(17),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-liege-oignons',
    itemId: ItemIds.liegeOignons,
    supplierId: SupplierIds.liegeGrossiste,
    pricePerUnit: 1.55,
    effectiveDate: daysAgo(17),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-liege-cafe',
    itemId: ItemIds.liegeCafe,
    supplierId: SupplierIds.liegeGrossiste,
    pricePerUnit: 18.20,
    effectiveDate: daysAgo(17),
    isDefault: true,
  ),
  SupplierPrice(
    id: 'sp-liege-jupiler',
    itemId: ItemIds.liegeJupiler,
    supplierId: SupplierIds.liegeBrasseurs,
    pricePerUnit: 21.50,
    effectiveDate: daysAgo(12),
    isDefault: true,
  ),
];
