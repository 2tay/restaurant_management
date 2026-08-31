import '../../../models/notification_item.dart';
import 'items.dart';
import 'reference.dart';
import 'stores.dart';
import 'suppliers.dart';

/// Notification centre content.
///
/// Mixed read and unread, and mixed kinds — a list of nothing but low-stock
/// warnings would not exercise the screen's filtering or its icons.
final List<NotificationItem> mockNotifications = [
  NotificationItem(
    id: 'notif-1',
    storeId: StoreIds.sablon,
    kind: NotificationKind.outOfStock,
    title: 'Rupture de stock : Crevettes grises',
    body:
        'Il ne reste plus de crevettes grises. Dernier mouvement il y a 2 jours.',
    createdAt: hoursAgo(2),
    isRead: false,
    relatedItemId: ItemIds.crevettes,
  ),
  NotificationItem(
    id: 'notif-2',
    storeId: StoreIds.sablon,
    kind: NotificationKind.lowStock,
    title: 'Stock faible : Jupiler 33 cl',
    body: 'Il reste 2 bacs, sous le seuil de 3 bacs.',
    createdAt: hoursAgo(2),
    isRead: false,
    relatedItemId: ItemIds.jupiler,
  ),
  NotificationItem(
    id: 'notif-3',
    storeId: StoreIds.sablon,
    kind: NotificationKind.lowStock,
    title: 'Stock faible : Blanc de poulet',
    body: 'Il reste 6 kg, sous le seuil de 8 kg.',
    createdAt: hoursAgo(5),
    isRead: false,
    relatedItemId: ItemIds.poulet,
  ),
  NotificationItem(
    id: 'notif-4',
    storeId: StoreIds.sablon,
    kind: NotificationKind.priceChange,
    title: 'Hausse de prix : Crevettes grises',
    body: 'Marée du Nord est passé de 36,00 € à 42,00 € le kg, soit +16,7 %.',
    createdAt: daysAgo(4),
    isRead: false,
    relatedItemId: ItemIds.crevettes,
    relatedSupplierId: SupplierIds.maree,
  ),
  NotificationItem(
    id: 'notif-5',
    storeId: StoreIds.sablon,
    kind: NotificationKind.delivery,
    title: 'Livraison enregistrée',
    body: 'Maraîcher Vandenbroucke — 6 articles reçus par Sophie Lemmens.',
    createdAt: hoursAgo(20),
    isRead: true,
    relatedSupplierId: SupplierIds.maraicher,
  ),
  NotificationItem(
    id: 'notif-6',
    storeId: StoreIds.sablon,
    kind: NotificationKind.largeAdjustment,
    title: 'Ajustement important : Pommes de terre Bintje',
    body: 'Comptage physique 85 kg contre 97 kg au système, soit −12 kg.',
    createdAt: daysAgo(1),
    isRead: true,
    relatedItemId: ItemIds.pommesTerre,
  ),
  NotificationItem(
    id: 'notif-7',
    storeId: StoreIds.sablon,
    kind: NotificationKind.priceChange,
    title: "Hausse de prix : Huile d'olive extra vierge",
    body: 'Grossiste Central Bruxelles est passé de 8,10 € à 8,90 € le litre.',
    createdAt: daysAgo(18),
    isRead: true,
    relatedItemId: ItemIds.huileOlive,
    relatedSupplierId: SupplierIds.grossisteCentral,
  ),
  NotificationItem(
    id: 'notif-8',
    storeId: StoreIds.sablon,
    kind: NotificationKind.lowStock,
    title: 'Stock faible : Beurre de ferme',
    body: 'Il reste 3 kg, sous le seuil de 4 kg.',
    createdAt: hoursAgo(6),
    isRead: true,
    relatedItemId: ItemIds.beurre,
  ),

  NotificationItem(
    id: 'notif-liege-1',
    storeId: StoreIds.liege,
    kind: NotificationKind.outOfStock,
    title: 'Rupture de stock : Café en grains',
    body: 'Plus de café en grains. Commander chez Grossiste Meuse.',
    createdAt: daysAgo(1),
    isRead: false,
    relatedItemId: ItemIds.liegeCafe,
  ),
  NotificationItem(
    id: 'notif-liege-2',
    storeId: StoreIds.liege,
    kind: NotificationKind.lowStock,
    title: 'Stock faible : Sirop de Liège',
    body: 'Il reste 1,5 kg, sous le seuil de 2 kg.',
    createdAt: daysAgo(3),
    isRead: false,
    relatedItemId: ItemIds.liegeSirop,
  ),
];
