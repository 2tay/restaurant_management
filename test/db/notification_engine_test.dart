// The notification engine: which real events reach the feed, and which do not.
//
// Until this existed the feed was ten seeded rows that never changed. These
// tests are about the three rules that keep it worth reading — notify the
// crossing rather than the state, honour the preference before composing
// anything, and never let a feed entry fail the write it describes.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart'
    show ItemIds, StoreIds, SupplierIds;
import 'package:stock_inventory/models/models.dart';

import '../support/db_fixture.dart';

void main() {
  late AppDatabase db;
  late AccountRepository account;
  late MovementRepository movements;
  late StoreRepository stores;

  /// What the seed ships with, read rather than pinned: these tests are about
  /// what the engine adds, and a hard-coded baseline would turn a change to the
  /// demo dataset into a failure here.
  late int seededUnread;

  setUp(() async {
    db = await openSeededDatabase();
    account = AccountRepository(db);
    movements = MovementRepository(db);
    stores = StoreRepository(db);
    seededUnread = await account.unreadNotificationCount(StoreIds.sablon);
  });

  /// The feed entries about one article, newest first.
  Future<List<NotificationItem>> about(String itemId) async {
    final all = await account.notifications(StoreIds.sablon);
    return all.where((n) => n.relatedItemId == itemId).toList();
  }

  /// Carbonade starts at 24 kg against a threshold of 10 — comfortably above
  /// it, which is what makes it the article to push over the line.
  Future<void> consume(double quantity, {String item = ItemIds.carbonade}) =>
      movements.recordStockOut(
        storeId: StoreIds.sablon,
        itemId: item,
        quantity: quantity,
        reason: StockOutReason.sale,
      );

  group('stock crossings', () {
    test('going under the threshold files one low-stock notification', () async {
      expect(await about(ItemIds.carbonade), isEmpty);

      await consume(15);

      final filed = await about(ItemIds.carbonade);
      expect(filed, hasLength(1));
      expect(filed.single.kind, NotificationKind.lowStock);
      expect(filed.single.isRead, isFalse);
      expect(filed.single.title, contains('Carbonade'));
      // The body carries both figures, because "it is low" without the numbers
      // is not something anybody can act on.
      expect(filed.single.body, contains('9'));
      expect(filed.single.body, contains('10'));
    });

    // The rule the whole design turns on: an article that is *already* low
    // produces a movement every service, and every one of them crosses nothing.
    test('staying under it files nothing more', () async {
      await consume(15);
      await consume(1);
      await consume(1);

      expect(await about(ItemIds.carbonade), hasLength(1));
    });

    test('hitting zero files a rupture, not a second low-stock', () async {
      // Straight from 24 to 0 in one movement: it crosses both lines at once
      // and only the worse one is worth saying.
      await consume(24);

      final filed = await about(ItemIds.carbonade);
      expect(filed, hasLength(1));
      expect(filed.single.kind, NotificationKind.outOfStock);
    });

    test('a delivery back above the line files nothing', () async {
      await consume(15);
      await movements.recordStockIn(
        storeId: StoreIds.sablon,
        itemId: ItemIds.carbonade,
        quantity: 30,
      );

      // Still just the one from going low. Stock going *up* is not news.
      expect(await about(ItemIds.carbonade), hasLength(1));
    });

    test('the notification deep-links to the article it is about', () async {
      await consume(15);

      expect((await about(ItemIds.carbonade)).single.relatedItemId,
          ItemIds.carbonade);
    });
  });

  group('preferences', () {
    test('a kind switched off is never composed at all', () async {
      await stores.setNotificationPreference(StoreIds.sablon, lowStock: false);

      await consume(15);

      // Not hidden — absent. A suppressed notification that still sat unread on
      // the bell would be the opposite of what the switch promises.
      expect(await about(ItemIds.carbonade), isEmpty);
      expect(
        await account.unreadNotificationCount(StoreIds.sablon),
        seededUnread,
      );
    });

    test('switching it back on resumes the next crossing', () async {
      await stores.setNotificationPreference(StoreIds.sablon, lowStock: false);
      await consume(15);
      await stores.setNotificationPreference(StoreIds.sablon, lowStock: true);

      await consume(9);

      final filed = await about(ItemIds.carbonade);
      expect(filed, hasLength(1));
      expect(filed.single.kind, NotificationKind.outOfStock);
    });

    test('deliveries are off by default', () async {
      final settings = await stores.settings(StoreIds.sablon);

      expect(settings.notifyDeliveries, isFalse);
      expect(settings.notifyLowStock, isTrue);
      expect(settings.notifyPriceChange, isTrue);
      expect(settings.notifyLargeAdjustment, isTrue);
    });
  });

  group('adjustments', () {
    test('a large count discrepancy is flagged', () async {
      await movements.recordAdjustment(
        storeId: StoreIds.sablon,
        itemId: ItemIds.carbonade,
        systemQuantity: 24,
        countedQuantity: 12,
      );

      final filed = await about(ItemIds.carbonade);
      expect(
        filed.map((n) => n.kind),
        contains(NotificationKind.largeAdjustment),
      );
    });

    test('a small one is not', () async {
      // Half a kilo off twenty-four: a scale, not a problem.
      await movements.recordAdjustment(
        storeId: StoreIds.sablon,
        itemId: ItemIds.carbonade,
        systemQuantity: 24,
        countedQuantity: 23.5,
      );

      expect(await about(ItemIds.carbonade), isEmpty);
    });

    // An opening balance goes through the same path with a system quantity of
    // zero. It is not a discrepancy — there was nothing to disagree with — and
    // flagging it would greet every new article with a warning.
    test('an opening balance is not an adjustment', () async {
      final item = await ItemRepository(db).create(
        storeId: StoreIds.sablon,
        name: 'Endives',
        categoryId: (await CatalogRepository(db).categories(StoreIds.sablon))
            .first
            .id,
        unitId: (await CatalogRepository(db).units(StoreIds.sablon)).first.id,
        lowStockThreshold: 5,
      );

      await movements.recordOpeningBalance(
        storeId: StoreIds.sablon,
        itemId: item!.id,
        quantity: 40,
      );

      expect(await about(item.id), isEmpty);
    });
  });

  group('price changes', () {
    test('a supplier raising a price reaches the feed', () async {
      final suppliers = SupplierRepository(db);
      final price = await suppliers.priceFor(
        ItemIds.poulet,
        SupplierIds.grossisteCentral,
      );

      await suppliers.updatePrice(price!.id, price.pricePerUnit * 1.2);

      final filed = (await about(ItemIds.poulet))
          .where((n) => n.kind == NotificationKind.priceChange)
          .toList();
      expect(filed, isNotEmpty);
      expect(filed.first.title, startsWith('Hausse'));
      // It names the supplier, which is the half nobody can see for themselves.
      expect(filed.first.relatedSupplierId, SupplierIds.grossisteCentral);
    });

    test('setting the same price again says nothing', () async {
      final suppliers = SupplierRepository(db);
      final price = await suppliers.priceFor(
        ItemIds.poulet,
        SupplierIds.grossisteCentral,
      );
      final before = (await about(ItemIds.poulet)).length;

      await suppliers.updatePrice(price!.id, price.pricePerUnit);

      expect(await about(ItemIds.poulet), hasLength(before));
    });
  });
}
