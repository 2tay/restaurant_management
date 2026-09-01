import '../../../models/purchase_order.dart';
import '../../../models/purchase_order_line.dart';
import 'items.dart';
import 'reference.dart';
import 'stores.dart';
import 'suppliers.dart';

abstract final class OrderIds {
  static const String draftMaraicher = 'po-2026-018';
  static const String sentGrossiste = 'po-2026-017';
  static const String partialBoucherie = 'po-2026-016';
  static const String receivedCremerie = 'po-2026-015';
  static const String cancelledHoreca = 'po-2026-014';
  static const String receivedBrasseurs = 'po-2026-013';

  static const String liegeSent = 'po-2026-012';
}

/// The commandes.
///
/// Every status appears at least once, because each one unlocks a different set
/// of actions and a demo that only shows drafts proves nothing:
///
/// - **draft** — Maraîcher, still being built. Editable, deletable, sendable.
/// - **sent** — Grossiste Central, nothing received. This is the one to receive
///   live in front of the client: it has a short delivery and a price rise
///   waiting to happen.
/// - **partial** — Boucherie, sent nine days ago and still open. Past the
///   seven-day threshold, so the dashboard flags it as stale.
/// - **received** — Crémerie and Brasseurs, closed and read-only.
/// - **cancelled** — Horeca Select, killed before anything arrived.
///
/// Quantities on the open orders are chosen so the "already on order" indicator
/// has something to say: poulet and huile d'olive are both low *and* on their
/// way, which is exactly the situation that causes a manager to order twice.
final List<PurchaseOrder> mockPurchaseOrders = [
  // ---------------------------------------------------------------------------
  // Draft — nothing has left the building
  // ---------------------------------------------------------------------------
  PurchaseOrder(
    id: OrderIds.draftMaraicher,
    storeId: StoreIds.sablon,
    supplierId: SupplierIds.maraicher,
    reference: 'CMD-2026-018',
    status: PurchaseOrderStatus.draft,
    createdAt: hoursAgo(4),
    lines: [
      const PurchaseOrderLine(
        id: 'pol-018-1',
        itemId: ItemIds.tomates,
        quantityOrdered: 20,
        unitPrice: 3.20,
      ),
      const PurchaseOrderLine(
        id: 'pol-018-2',
        itemId: ItemIds.salade,
        quantityOrdered: 24,
        unitPrice: 1.10,
      ),
      const PurchaseOrderLine(
        id: 'pol-018-3',
        itemId: ItemIds.persil,
        quantityOrdered: 12,
        unitPrice: 1.25,
      ),
    ],
    note: 'Livraison souhaitée mardi matin.',
  ),

  // ---------------------------------------------------------------------------
  // Sent — the demo order. Locked, receivable, still cancellable.
  // ---------------------------------------------------------------------------
  PurchaseOrder(
    id: OrderIds.sentGrossiste,
    storeId: StoreIds.sablon,
    supplierId: SupplierIds.grossisteCentral,
    reference: 'CMD-2026-017',
    status: PurchaseOrderStatus.sent,
    createdAt: daysAgo(3),
    sentAt: daysAgo(2),
    lines: [
      const PurchaseOrderLine(
        id: 'pol-017-1',
        itemId: ItemIds.poulet,
        quantityOrdered: 15,
        unitPrice: 12.80,
      ),
      const PurchaseOrderLine(
        id: 'pol-017-2',
        itemId: ItemIds.huileOlive,
        quantityOrdered: 12,
        unitPrice: 8.90,
      ),
      const PurchaseOrderLine(
        id: 'pol-017-3',
        itemId: ItemIds.riz,
        quantityOrdered: 25,
        unitPrice: 1.95,
      ),
      const PurchaseOrderLine(
        id: 'pol-017-4',
        itemId: ItemIds.mayonnaise,
        quantityOrdered: 10,
        unitPrice: 4.15,
      ),
    ],
  ),

  // ---------------------------------------------------------------------------
  // Partial — one delivery in, one line still outstanding, and open long
  // enough that the dashboard should be complaining about it.
  // ---------------------------------------------------------------------------
  PurchaseOrder(
    id: OrderIds.partialBoucherie,
    storeId: StoreIds.sablon,
    supplierId: SupplierIds.boucherie,
    reference: 'CMD-2026-016',
    status: PurchaseOrderStatus.partial,
    createdAt: daysAgo(10),
    sentAt: daysAgo(9),
    lines: [
      // Over-delivered: 22 arrived against 20 ordered.
      const PurchaseOrderLine(
        id: 'pol-016-1',
        itemId: ItemIds.carbonade,
        quantityOrdered: 20,
        quantityReceived: 22,
        unitPrice: 14.20,
      ),
      // Short, and the receiver said the balance is still coming — which is
      // why this order is sitting in `partial` nine days later.
      const PurchaseOrderLine(
        id: 'pol-016-2',
        itemId: ItemIds.lard,
        quantityOrdered: 10,
        quantityReceived: 4,
        unitPrice: 9.80,
      ),
      const PurchaseOrderLine(
        id: 'pol-016-3',
        itemId: ItemIds.jambonArdenne,
        quantityOrdered: 5,
        unitPrice: 22.40,
      ),
    ],
  ),

  // ---------------------------------------------------------------------------
  // Received — closed short on one line, with an unordered item and a real
  // price rise in its receipt.
  // ---------------------------------------------------------------------------
  PurchaseOrder(
    id: OrderIds.receivedCremerie,
    storeId: StoreIds.sablon,
    supplierId: SupplierIds.cremerie,
    reference: 'CMD-2026-015',
    status: PurchaseOrderStatus.received,
    createdAt: daysAgo(13),
    sentAt: daysAgo(12),
    closedAt: daysAgo(11),
    lines: [
      const PurchaseOrderLine(
        id: 'pol-015-1',
        itemId: ItemIds.beurre,
        quantityOrdered: 15,
        quantityReceived: 15,
        unitPrice: 7.20,
      ),
      const PurchaseOrderLine(
        id: 'pol-015-2',
        itemId: ItemIds.creme,
        quantityOrdered: 24,
        quantityReceived: 24,
        unitPrice: 3.60,
      ),
      // 360 ordered, 300 delivered, closed short. The order still says 360 —
      // that 60-egg gap is the record of the supplier under-delivering, and
      // rewriting the line to 300 would erase it.
      const PurchaseOrderLine(
        id: 'pol-015-3',
        itemId: ItemIds.oeufs,
        quantityOrdered: 360,
        quantityReceived: 300,
        unitPrice: 0.32,
        closedShort: true,
      ),
    ],
  ),

  // ---------------------------------------------------------------------------
  // Cancelled — nothing was ever received, so cancelling was allowed
  // ---------------------------------------------------------------------------
  PurchaseOrder(
    id: OrderIds.cancelledHoreca,
    storeId: StoreIds.sablon,
    supplierId: SupplierIds.horecaSelect,
    reference: 'CMD-2026-014',
    status: PurchaseOrderStatus.cancelled,
    createdAt: daysAgo(21),
    sentAt: daysAgo(20),
    closedAt: daysAgo(19),
    lines: [
      const PurchaseOrderLine(
        id: 'pol-014-1',
        itemId: ItemIds.vinRouge,
        quantityOrdered: 24,
        unitPrice: 6.80,
      ),
      const PurchaseOrderLine(
        id: 'pol-014-2',
        itemId: ItemIds.cafe,
        quantityOrdered: 8,
        unitPrice: 17.50,
      ),
    ],
    note: 'Annulée — délai de livraison annoncé à trois semaines.',
  ),

  // ---------------------------------------------------------------------------
  // Received cleanly — the boring case, which the list also needs
  // ---------------------------------------------------------------------------
  PurchaseOrder(
    id: OrderIds.receivedBrasseurs,
    storeId: StoreIds.sablon,
    supplierId: SupplierIds.brasseurs,
    reference: 'CMD-2026-013',
    status: PurchaseOrderStatus.received,
    createdAt: daysAgo(26),
    sentAt: daysAgo(25),
    closedAt: daysAgo(23),
    lines: [
      const PurchaseOrderLine(
        id: 'pol-013-1',
        itemId: ItemIds.jupiler,
        quantityOrdered: 10,
        quantityReceived: 10,
        unitPrice: 21.50,
      ),
      const PurchaseOrderLine(
        id: 'pol-013-2',
        itemId: ItemIds.duvel,
        quantityOrdered: 4,
        quantityReceived: 4,
        unitPrice: 34.20,
      ),
    ],
  ),

  // ---------------------------------------------------------------------------
  // Liège — so switching stores does not land on an empty orders list
  // ---------------------------------------------------------------------------
  PurchaseOrder(
    id: OrderIds.liegeSent,
    storeId: StoreIds.liege,
    supplierId: SupplierIds.liegeGrossiste,
    reference: 'CMD-LG-2026-004',
    status: PurchaseOrderStatus.sent,
    createdAt: daysAgo(2),
    sentAt: daysAgo(1),
    lines: [
      const PurchaseOrderLine(
        id: 'pol-lg-004-1',
        itemId: ItemIds.liegeFrites,
        quantityOrdered: 30,
        unitPrice: 1.90,
      ),
      const PurchaseOrderLine(
        id: 'pol-lg-004-2',
        itemId: ItemIds.liegeOignons,
        quantityOrdered: 15,
        unitPrice: 1.55,
      ),
    ],
  ),
];
