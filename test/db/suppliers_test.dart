// Suppliers and the item–supplier links that carry prices.
//
// The link is where this app's central idea lives: price is an attribute of the
// item–supplier *pair*, not of the item. So most of what is pinned here is about
// keeping that relationship coherent — exactly one default per article, a
// history entry whenever a price moves, and a promotion when the default goes.
//
// Ported from `test/suppliers_test.dart`: same tests, same assertions, against a
// database instead of a list.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart'
    show CategoryIds, ItemIds, StoreIds, SupplierIds, UnitIds;

import '../support/db_fixture.dart';

void main() {
  late AppDatabase db;
  late SupplierRepository suppliers;
  late ItemRepository items;
  late MovementRepository movements;
  late OrderRepository orders;

  setUp(() async {
    db = await openSeededDatabase();
    suppliers = SupplierRepository(db);
    items = ItemRepository(db);
    movements = MovementRepository(db);
    orders = OrderRepository(db);
  });

  /// How many suppliers claim to be the default for an article.
  ///
  /// Must always be zero or one. Two would make every auto-filled price a coin
  /// toss, and the bug would only show up as prices that occasionally look
  /// wrong.
  Future<int> defaultCount(String itemId) async =>
      (await suppliers.pricesForItem(itemId)).where((p) => p.isDefault).length;

  group('linking an article to a supplier', () {
    test('creates the link at the given price', () async {
      // Tomates are not supplied by the Boucherie.
      final link = await suppliers.linkItem(
        itemId: ItemIds.tomates,
        supplierId: SupplierIds.boucherie,
        pricePerUnit: 2.80,
      );

      expect(link, isNotNull);
      expect(
        await suppliers.priceFor(ItemIds.tomates, SupplierIds.boucherie),
        isNotNull,
      );
      expect(link!.pricePerUnit, 2.80);
    });

    test('refuses a link that already exists', () async {
      expect(
        await suppliers.linkItem(
          itemId: ItemIds.poulet,
          supplierId: SupplierIds.grossisteCentral,
          pricePerUnit: 9.99,
        ),
        isNull,
        reason: 'that is a price edit, and silently overwriting would lose the '
            'history entry the edit path writes',
      );
    });

    test('refuses a price of zero or less', () async {
      expect(
        await suppliers.linkItem(
          itemId: ItemIds.tomates,
          supplierId: SupplierIds.boucherie,
          pricePerUnit: 0,
        ),
        isNull,
      );
    });

    test('the first supplier for an article becomes its default', () async {
      final created = (await items.create(
        storeId: StoreIds.sablon,
        name: 'Chicons',
        categoryId: CategoryIds.legumes,
        unitId: UnitIds.kg,
        quantity: 0,
        lowStockThreshold: 2,
      ))!;

      final link = (await suppliers.linkItem(
        itemId: created.id,
        supplierId: SupplierIds.maraicher,
        pricePerUnit: 3.10,
      ))!;

      // An article with prices but no default has no auto-fill anywhere, which
      // reads as the feature being broken.
      expect(link.isDefault, isTrue);
      expect(await defaultCount(created.id), 1);
    });

    test('an article never has two defaults', () async {
      await suppliers.linkItem(
        itemId: ItemIds.tomates,
        supplierId: SupplierIds.boucherie,
        pricePerUnit: 2.80,
        makeDefault: true,
      );

      expect(await defaultCount(ItemIds.tomates), 1);
      expect(
        (await suppliers.defaultPriceForItem(ItemIds.tomates))!.supplierId,
        SupplierIds.boucherie,
      );
    });
  });

  group('changing a price', () {
    test('writes a history entry for the item-supplier pair', () async {
      final price = (await suppliers.priceFor(
        ItemIds.poulet,
        SupplierIds.grossisteCentral,
      ))!;
      final before = (await suppliers.priceHistoryFor(
        ItemIds.poulet,
        SupplierIds.grossisteCentral,
      )).length;

      await suppliers.updatePrice(price.id, 13.60);

      final history = await suppliers.priceHistoryFor(
        ItemIds.poulet,
        SupplierIds.grossisteCentral,
      );
      expect(history.length, before + 1);
      expect(history.first.oldPrice, price.pricePerUnit);
      expect(history.first.newPrice, 13.60);
      expect(
        (await suppliers.priceFor(
          ItemIds.poulet,
          SupplierIds.grossisteCentral,
        ))!.pricePerUnit,
        13.60,
      );
    });

    test('setting the same price writes nothing', () async {
      final price = (await suppliers.priceFor(
        ItemIds.poulet,
        SupplierIds.grossisteCentral,
      ))!;
      final before = (await suppliers.priceHistoryFor(
        ItemIds.poulet,
        SupplierIds.grossisteCentral,
      )).length;

      await suppliers.updatePrice(price.id, price.pricePerUnit);

      expect(
        (await suppliers.priceHistoryFor(
          ItemIds.poulet,
          SupplierIds.grossisteCentral,
        )).length,
        before,
      );
    });

    test('keeps the default flag', () async {
      final price = (await suppliers.defaultPriceForItem(ItemIds.poulet))!;

      await suppliers.updatePrice(price.id, 13.60);

      expect(await suppliers.defaultPriceForItem(ItemIds.poulet), isNotNull);
      expect(await defaultCount(ItemIds.poulet), 1);
    });

    test('stamps the current user when the caller names nobody', () async {
      final price = (await suppliers.defaultPriceForItem(ItemIds.poulet))!;
      final expected = await AccountRepository(db).currentUserName();

      await suppliers.updatePrice(price.id, 13.60);

      final history = await suppliers.priceHistoryFor(
        price.itemId,
        price.supplierId,
      );
      expect(history.first.changedByName, expected);
      expect(expected, isNotEmpty);
    });
  });

  group('unlinking', () {
    test('promotes the cheapest remaining supplier when the default goes',
        () async {
      final wasDefault = (await suppliers.defaultPriceForItem(ItemIds.poulet))!;
      final expected = (await suppliers.pricesForItem(
        ItemIds.poulet,
      )).firstWhere((price) => price.id != wasDefault.id);

      await suppliers.unlinkItem(wasDefault.id);

      // Without the promotion the article keeps its other suppliers but loses
      // its auto-fill everywhere, and nothing on screen explains why.
      final promoted = await suppliers.defaultPriceForItem(ItemIds.poulet);
      expect(promoted, isNotNull);
      expect(promoted!.id, expected.id);
      expect(await defaultCount(ItemIds.poulet), 1);
    });

    test('removing a non-default leaves the default alone', () async {
      final defaultPrice = (await suppliers.defaultPriceForItem(
        ItemIds.poulet,
      ))!;
      final other = (await suppliers.pricesForItem(
        ItemIds.poulet,
      )).firstWhere((price) => !price.isDefault);

      await suppliers.unlinkItem(other.id);

      expect(
        (await suppliers.defaultPriceForItem(ItemIds.poulet))!.id,
        defaultPrice.id,
      );
    });

    test('removing the last link leaves no default and does not crash',
        () async {
      for (final price in await suppliers.pricesForItem(ItemIds.poulet)) {
        await suppliers.unlinkItem(price.id);
      }

      expect(await suppliers.pricesForItem(ItemIds.poulet), isEmpty);
      expect(await suppliers.defaultPriceForItem(ItemIds.poulet), isNull);
    });

    test('keeps the price history for the pair', () async {
      final price = (await suppliers.priceFor(
        ItemIds.poulet,
        SupplierIds.grossisteCentral,
      ))!;
      final before = (await suppliers.priceHistoryFor(
        ItemIds.poulet,
        SupplierIds.grossisteCentral,
      )).length;

      await suppliers.unlinkItem(price.id);

      // What they charged while the link existed stays true afterwards.
      expect(
        (await suppliers.priceHistoryFor(
          ItemIds.poulet,
          SupplierIds.grossisteCentral,
        )).length,
        before,
      );
    });
  });

  group('deleting a supplier', () {
    test('is refused while they hold an open commande', () async {
      expect(
        await suppliers.deleteBlockedBy(SupplierIds.grossisteCentral),
        SupplierDeleteBlock.hasOpenOrder,
      );
      expect(await suppliers.delete(SupplierIds.grossisteCentral), isFalse);
    });

    test('removes their prices and promotes replacements', () async {
      // Horeca Select's only open commande was cancelled, so they can go.
      expect(await suppliers.deleteBlockedBy(SupplierIds.horecaSelect), isNull);
      expect(await suppliers.delete(SupplierIds.horecaSelect), isTrue);

      expect(await suppliers.supplier(SupplierIds.horecaSelect), isNull);
      expect(
        await suppliers.pricesForSupplier(SupplierIds.horecaSelect),
        isEmpty,
      );

      // Vin rouge and café had them as their only supplier; everything else that
      // had them as default gets a replacement.
      for (final item in await items.items(StoreIds.sablon)) {
        final prices = await suppliers.pricesForItem(item.id);
        if (prices.isEmpty) continue;
        expect(
          await defaultCount(item.id),
          1,
          reason: '${item.name} has prices but '
              '${await defaultCount(item.id)} defaults',
        );
      }
    });

    test('keeps the stock movements that name them', () async {
      Future<int> naming() async => (await movements.movementsForStore(
        StoreIds.sablon,
      )).where((m) => m.supplierId == SupplierIds.horecaSelect).length;

      final before = await naming();
      expect(before, greaterThan(0));

      await suppliers.delete(SupplierIds.horecaSelect);

      // A movement is the record of goods that really moved. The supplier going
      // away does not unmake that.
      expect(await naming(), before);
    });

    test('keeps their closed commandes', () async {
      final before = (await orders.ordersForSupplier(
        SupplierIds.horecaSelect,
      )).length;

      await suppliers.delete(SupplierIds.horecaSelect);

      expect(
        (await orders.ordersForSupplier(SupplierIds.horecaSelect)).length,
        before,
        reason: 'order history is how an owner sees who they used to buy from',
      );
    });
  });

  group('creating and editing a supplier', () {
    test('trims what it stores', () async {
      final created = await suppliers.create(
        storeId: StoreIds.sablon,
        name: '  Nouvelle Boucherie  ',
        contactName: ' Jean ',
        email: ' jean@example.be ',
        phone: ' +32 2 000 00 00 ',
        addressLine: ' Rue 1 ',
        postalCode: ' 1000 ',
        city: ' Bruxelles ',
      );

      expect(created.name, 'Nouvelle Boucherie');
      expect(created.email, 'jean@example.be');
    });

    test('allows two suppliers with the same name', () async {
      final existing = (await suppliers.suppliers(StoreIds.sablon)).first;

      // Two branches of the same butcher is a real situation. Blocking it would
      // be the app inventing a rule the business does not have.
      final created = await suppliers.create(
        storeId: StoreIds.sablon,
        name: existing.name,
        contactName: 'Autre',
        email: 'autre@example.be',
        phone: '+32 2 111 11 11',
        addressLine: 'Rue 2',
        postalCode: '1000',
        city: 'Bruxelles',
      );

      expect(created.id, isNot(existing.id));
    });

    test('an edit leaves the id and the links alone', () async {
      final links = (await suppliers.pricesForSupplier(
        SupplierIds.maraicher,
      )).length;

      final updated = await suppliers.update(
        SupplierIds.maraicher,
        name: 'Maraîcher VDB',
      );

      expect(updated!.id, SupplierIds.maraicher);
      expect(
        (await suppliers.pricesForSupplier(SupplierIds.maraicher)).length,
        links,
      );
    });
  });
}
