import '../models/goods_receipt.dart';
import '../models/goods_receipt_line.dart';
import 'mock_items.dart';
import 'mock_purchase_orders.dart';
import 'mock_reference.dart';
import 'mock_stores.dart';

abstract final class ReceiptIds {
  static const String boucherieFirst = 'gr-016-1';
  static const String cremerieFinal = 'gr-015-1';
  static const String brasseurs = 'gr-013-1';
}

/// Confirmed deliveries.
///
/// Between them these three cover every outcome the receiving screen has to
/// handle, so the read-only receipt detail has something real to render and the
/// movement history has receipts to link back to:
///
/// - **over-delivery** — 22 kg of carbonade against 20 ordered
/// - **short, balance still coming** — 4 kg of lard against 10, left open
/// - **short, closed** — 300 eggs against 360, accepted and closed
/// - **price change** — crème at 4,25 € against 3,60 € ordered, an 18% rise
///   that is above the confirmation threshold and updates the price history
/// - **unordered item** — 4 kg of gouda the driver brought anyway
///
/// A receipt is never edited or deleted once confirmed, which is why these are
/// written as history rather than as something the demo mutates.
final List<GoodsReceipt> mockGoodsReceipts = [
  // ---------------------------------------------------------------------------
  // Boucherie — the delivery that left the order in `partial`
  // ---------------------------------------------------------------------------
  GoodsReceipt(
    id: ReceiptIds.boucherieFirst,
    orderId: OrderIds.partialBoucherie,
    storeId: StoreIds.sablon,
    receivedAt: daysAgo(6),
    receivedByName: 'Amélie Vandenberghe',
    lines: [
      const GoodsReceiptLine(
        id: 'grl-016-1-1',
        itemId: ItemIds.carbonade,
        quantityOrdered: 20,
        quantityReceived: 22,
        actualUnitPrice: 14.20,
        note: 'Deux kilos en plus, acceptés.',
      ),
      const GoodsReceiptLine(
        id: 'grl-016-1-2',
        itemId: ItemIds.lard,
        quantityOrdered: 10,
        quantityReceived: 4,
        actualUnitPrice: 9.80,
        note: 'Reste annoncé pour la fin de semaine.',
      ),
    ],
  ),

  // ---------------------------------------------------------------------------
  // Crémerie — short delivery closed, unordered line, and a real price rise
  // ---------------------------------------------------------------------------
  GoodsReceipt(
    id: ReceiptIds.cremerieFinal,
    orderId: OrderIds.receivedCremerie,
    storeId: StoreIds.sablon,
    receivedAt: daysAgo(11),
    receivedByName: 'Marc Delvaux',
    lines: [
      const GoodsReceiptLine(
        id: 'grl-015-1-1',
        itemId: ItemIds.beurre,
        quantityOrdered: 15,
        quantityReceived: 15,
        actualUnitPrice: 7.20,
      ),
      // 3,60 € ordered, 4,25 € on the delivery note — an 18% jump, past the
      // confirmation threshold. Confirming this receipt is what wrote the
      // crème price history entry and moved the supplier's current price.
      const GoodsReceiptLine(
        id: 'grl-015-1-2',
        itemId: ItemIds.creme,
        quantityOrdered: 24,
        quantityReceived: 24,
        actualUnitPrice: 4.25,
        note: 'Hausse annoncée sur le bon de livraison.',
      ),
      const GoodsReceiptLine(
        id: 'grl-015-1-3',
        itemId: ItemIds.oeufs,
        quantityOrdered: 360,
        quantityReceived: 300,
        actualUnitPrice: 0.32,
        closedShort: true,
        note: 'Cinq plateaux manquants, non réapprovisionnés.',
      ),
      const GoodsReceiptLine(
        id: 'grl-015-1-4',
        itemId: ItemIds.gouda,
        quantityOrdered: 0,
        quantityReceived: 4,
        actualUnitPrice: 9.40,
        wasUnordered: true,
        note: 'Ajouté par le chauffeur, non commandé.',
      ),
    ],
  ),

  // ---------------------------------------------------------------------------
  // Brasseurs — everything arrived, at the agreed price
  // ---------------------------------------------------------------------------
  GoodsReceipt(
    id: ReceiptIds.brasseurs,
    orderId: OrderIds.receivedBrasseurs,
    storeId: StoreIds.sablon,
    receivedAt: daysAgo(23),
    receivedByName: 'Sophie Lemmens',
    lines: [
      const GoodsReceiptLine(
        id: 'grl-013-1-1',
        itemId: ItemIds.jupiler,
        quantityOrdered: 10,
        quantityReceived: 10,
        actualUnitPrice: 21.50,
      ),
      const GoodsReceiptLine(
        id: 'grl-013-1-2',
        itemId: ItemIds.duvel,
        quantityOrdered: 4,
        quantityReceived: 4,
        actualUnitPrice: 34.20,
      ),
    ],
  ),
];
