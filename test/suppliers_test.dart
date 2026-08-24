// Suppliers and the item–supplier links that carry prices.
//
// The link is where this app's central idea lives: price is an attribute of the
// item–supplier *pair*, not of the item. So most of what is pinned here is
// about keeping that relationship coherent — exactly one default per item, a
// history entry whenever a price moves, and a promotion when the default goes.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/mock_data/mock_data.dart';

import 'support/mock_reset.dart';

/// How many suppliers claim to be the default for an item.
///
/// Must always be zero or one. Two would make every auto-filled price a coin
/// toss, and the bug would only show up as prices that occasionally look wrong.
int defaultCount(String itemId) =>
    MockQueries.pricesForItem(itemId).where((p) => p.isDefault).length;

void main() {
  setUp(restoreMockData);

  group('linking an item to a supplier', () {
    test('creates the link at the given price', () {
      // Tomates are not supplied by the Boucherie.
      final link = SupplierMutations.linkItem(
        itemId: ItemIds.tomates,
        supplierId: SupplierIds.boucherie,
        pricePerUnit: 2.80,
      );

      expect(link, isNotNull);
      expect(
        MockQueries.priceFor(ItemIds.tomates, SupplierIds.boucherie),
        isNotNull,
      );
      expect(link!.pricePerUnit, 2.80);
    });

    test('refuses a link that already exists', () {
      expect(
        SupplierMutations.linkItem(
          itemId: ItemIds.poulet,
          supplierId: SupplierIds.grossisteCentral,
          pricePerUnit: 9.99,
        ),
        isNull,
        reason: 'that is a price edit, and silently overwriting would lose the '
            'history entry the edit path writes',
      );
    });

    test('the first supplier for an item becomes its default', () {
      final created = ItemMutations.create(
        storeId: StoreIds.sablon,
        name: 'Chicons',
        categoryId: CategoryIds.legumes,
        unitId: UnitIds.kg,
        quantity: 0,
        lowStockThreshold: 2,
      )!;

      final link = SupplierMutations.linkItem(
        itemId: created.id,
        supplierId: SupplierIds.maraicher,
        pricePerUnit: 3.10,
      )!;

      // An item with prices but no default has no auto-fill anywhere, which
      // reads as the feature being broken.
      expect(link.isDefault, isTrue);
      expect(defaultCount(created.id), 1);
    });

    test('an item never has two defaults', () {
      SupplierMutations.linkItem(
        itemId: ItemIds.tomates,
        supplierId: SupplierIds.boucherie,
        pricePerUnit: 2.80,
        makeDefault: true,
      );

      expect(defaultCount(ItemIds.tomates), 1);
      expect(
        MockQueries.defaultPriceForItem(ItemIds.tomates)!.supplierId,
        SupplierIds.boucherie,
      );
    });
  });

  group('changing a price', () {
    test('writes a history entry for the item–supplier pair', () {
      final price = MockQueries.priceFor(
        ItemIds.poulet,
        SupplierIds.grossisteCentral,
      )!;
      final before = MockQueries.priceHistoryFor(
        ItemIds.poulet,
        SupplierIds.grossisteCentral,
      ).length;

      SupplierMutations.updatePrice(price.id, 13.60);

      final history = MockQueries.priceHistoryFor(
        ItemIds.poulet,
        SupplierIds.grossisteCentral,
      );
      expect(history.length, before + 1);
      expect(history.first.oldPrice, price.pricePerUnit);
      expect(history.first.newPrice, 13.60);
      expect(
        MockQueries.priceFor(
          ItemIds.poulet,
          SupplierIds.grossisteCentral,
        )!.pricePerUnit,
        13.60,
      );
    });

    test('setting the same price writes nothing', () {
      final price = MockQueries.priceFor(
        ItemIds.poulet,
        SupplierIds.grossisteCentral,
      )!;
      final before = MockQueries.priceHistoryFor(
        ItemIds.poulet,
        SupplierIds.grossisteCentral,
      ).length;

      SupplierMutations.updatePrice(price.id, price.pricePerUnit);

      expect(
        MockQueries.priceHistoryFor(
          ItemIds.poulet,
          SupplierIds.grossisteCentral,
        ).length,
        before,
      );
    });

    test('keeps the default flag', () {
      final price = MockQueries.defaultPriceForItem(ItemIds.poulet)!;

      SupplierMutations.updatePrice(price.id, 13.60);

      expect(MockQueries.defaultPriceForItem(ItemIds.poulet), isNotNull);
      expect(defaultCount(ItemIds.poulet), 1);
    });
  });

  group('unlinking', () {
    test('promotes the cheapest remaining supplier when the default goes', () {
      final wasDefault = MockQueries.defaultPriceForItem(ItemIds.poulet)!;
      final expected = MockQueries.pricesForItem(
        ItemIds.poulet,
      ).firstWhere((price) => price.id != wasDefault.id);

      SupplierMutations.unlinkItem(wasDefault.id);

      // Without the promotion the item keeps its other suppliers but loses its
      // auto-fill everywhere, and nothing on screen explains why.
      final promoted = MockQueries.defaultPriceForItem(ItemIds.poulet);
      expect(promoted, isNotNull);
      expect(promoted!.id, expected.id);
      expect(defaultCount(ItemIds.poulet), 1);
    });

    test('removing a non-default leaves the default alone', () {
      final defaultPrice = MockQueries.defaultPriceForItem(ItemIds.poulet)!;
      final other = MockQueries.pricesForItem(
        ItemIds.poulet,
      ).firstWhere((price) => !price.isDefault);

      SupplierMutations.unlinkItem(other.id);

      expect(
        MockQueries.defaultPriceForItem(ItemIds.poulet)!.id,
        defaultPrice.id,
      );
    });

    test('removing the last link leaves no default and does not crash', () {
      for (final price in MockQueries.pricesForItem(ItemIds.poulet)) {
        SupplierMutations.unlinkItem(price.id);
      }

      expect(MockQueries.pricesForItem(ItemIds.poulet), isEmpty);
      expect(MockQueries.defaultPriceForItem(ItemIds.poulet), isNull);
    });

    test('keeps the price history for the pair', () {
      final price = MockQueries.priceFor(
        ItemIds.poulet,
        SupplierIds.grossisteCentral,
      )!;
      final before = MockQueries.priceHistoryFor(
        ItemIds.poulet,
        SupplierIds.grossisteCentral,
      ).length;

      SupplierMutations.unlinkItem(price.id);

      // What they charged while the link existed stays true afterwards.
      expect(
        MockQueries.priceHistoryFor(
          ItemIds.poulet,
          SupplierIds.grossisteCentral,
        ).length,
        before,
      );
    });
  });

  group('deleting a supplier', () {
    test('is refused while they hold an open order', () {
      expect(
        SupplierMutations.deleteBlockedBy(SupplierIds.grossisteCentral),
        SupplierDeleteBlock.hasOpenOrder,
      );
      expect(SupplierMutations.delete(SupplierIds.grossisteCentral), isFalse);
    });

    test('removes their prices and promotes replacements', () {
      // Horeca Select's only open order was cancelled, so they can go.
      expect(
        SupplierMutations.deleteBlockedBy(SupplierIds.horecaSelect),
        isNull,
      );
      expect(SupplierMutations.delete(SupplierIds.horecaSelect), isTrue);

      expect(MockQueries.supplierById(SupplierIds.horecaSelect), isNull);
      expect(MockQueries.pricesForSupplier(SupplierIds.horecaSelect), isEmpty);

      // Vin rouge and café had them as their only supplier; everything else
      // that had them as default gets a replacement.
      for (final item in MockQueries.itemsForStore(StoreIds.sablon)) {
        final prices = MockQueries.pricesForItem(item.id);
        if (prices.isEmpty) continue;
        expect(
          defaultCount(item.id),
          1,
          reason: '${item.name} has prices but ${defaultCount(item.id)} '
              'defaults',
        );
      }
    });

    test('keeps the stock movements that name them', () {
      final before = mockStockMovements
          .where((m) => m.supplierId == SupplierIds.horecaSelect)
          .length;

      SupplierMutations.delete(SupplierIds.horecaSelect);

      // A movement is the record of goods that really moved. The supplier going
      // away does not unmake that.
      expect(
        mockStockMovements
            .where((m) => m.supplierId == SupplierIds.horecaSelect)
            .length,
        before,
      );
    });

    test('keeps their closed orders', () {
      final before = MockQueries.ordersForSupplier(
        SupplierIds.horecaSelect,
      ).length;

      SupplierMutations.delete(SupplierIds.horecaSelect);

      expect(
        MockQueries.ordersForSupplier(SupplierIds.horecaSelect).length,
        before,
        reason: 'order history is how an owner sees who they used to buy from',
      );
    });
  });

  group('creating and editing a supplier', () {
    test('trims what it stores', () {
      final created = SupplierMutations.create(
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

    test('allows two suppliers with the same name', () {
      final existing = MockQueries.suppliersForStore(StoreIds.sablon).first;

      // Two branches of the same butcher is a real situation. Blocking it would
      // be the app inventing a rule the business does not have.
      final created = SupplierMutations.create(
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

    test('an edit leaves the id and the links alone', () {
      final links = MockQueries.pricesForSupplier(
        SupplierIds.maraicher,
      ).length;

      final updated = SupplierMutations.update(
        SupplierIds.maraicher,
        name: 'Maraîcher VDB',
      );

      expect(updated!.id, SupplierIds.maraicher);
      expect(MockQueries.pricesForSupplier(SupplierIds.maraicher).length, links);
    });
  });
}
