// Group A: everyday sharing, every tablet online (SYNC_TESTS_PLAN.md).
//
// Three tablets of one restaurant — Cuisine, Bar, Bureau — on one fake
// server. Each scenario ends with `settle`: everybody syncs until quiet,
// then every tablet must hold exactly the same data, with nothing waiting.

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/models/models.dart';

import '../support/restaurant_tablets.dart';

void main() {
  late Restaurant r;

  setUp(() async => r = await Restaurant.open());

  test('the opening day is the same on every tablet', () async {
    for (final tablet in r.tablets.values) {
      expect(
        await tablet.items.items(r.storeId),
        hasLength(3),
        reason: '$tablet',
      );
      expect(await tablet.stockOf(r.tomates.id), 10, reason: '$tablet');
    }
    await r.settle();
  });

  test(
    'A1 — a new product made on the office PC reaches every tablet',
    () async {
      final saumonFume = (await r['Bureau'].items.create(
        storeId: r.storeId,
        name: 'Saumon fumé',
        categoryId: r.legumes.id,
        unitId: r.kg.id,
        lowStockThreshold: 2,
      ))!;
      await r.settle();

      for (final tablet in r.tablets.values) {
        final item = (await tablet.items.item(saumonFume.id))!;
        expect(item.name, 'Saumon fumé', reason: '$tablet');
        expect(item.lowStockThreshold, 2, reason: '$tablet');
        expect(item.unitId, r.kg.id, reason: '$tablet');
      }
    },
  );

  test(
    'A2 — an edit reaches every tablet, and the old value is gone',
    () async {
      await r['Bureau'].items.update(r.tomates.id, lowStockThreshold: 6);
      await r.settle();

      for (final tablet in r.tablets.values) {
        expect(
          (await tablet.items.item(r.tomates.id))!.lowStockThreshold,
          6,
          reason: '$tablet',
        );
      }
    },
  );

  test(
    'A3 — a deleted supplier leaves every list, but its row is kept',
    () async {
      final boucher = await r['Bureau'].suppliers.create(
        storeId: r.storeId,
        name: 'Boucherie Dupont',
        contactName: '',
        email: '',
        phone: '',
        addressLine: '',
        postalCode: '',
        city: '',
      );
      await r.settle();
      expect(await r['Bureau'].suppliers.delete(boucher.id), isTrue);
      await r.settle();

      for (final tablet in r.tablets.values) {
        final names = [
          for (final s in await tablet.suppliers.suppliers(r.storeId)) s.name,
        ];
        expect(names, isNot(contains('Boucherie Dupont')), reason: '$tablet');
        final kept = await tablet.db
            .customSelect(
              'SELECT deleted_at FROM suppliers WHERE id = ?',
              variables: [Variable(boucher.id)],
            )
            .getSingle();
        expect(kept.data['deleted_at'], isNotNull, reason: '$tablet');
      }
    },
  );

  test('A4 — a chain made offline arrives parents first, never half', () async {
    final bureau = r['Bureau'];
    final epices = (await bureau.catalog.createCategory(
      storeId: r.storeId,
      name: 'Épices',
    ))!;
    final botte = (await bureau.catalog.createUnit(
      storeId: r.storeId,
      name: 'Botte',
      abbreviation: 'bt',
    ))!;
    final marche = await bureau.suppliers.create(
      storeId: r.storeId,
      name: 'Marché',
      contactName: '',
      email: '',
      phone: '',
      addressLine: '',
      postalCode: '',
      city: '',
    );
    final persil = (await bureau.items.create(
      storeId: r.storeId,
      name: 'Persil',
      categoryId: epices.id,
      unitId: botte.id,
      lowStockThreshold: 1,
      defaultSupplierId: marche.id,
    ))!;
    await bureau.movements.recordStockIn(
      storeId: r.storeId,
      itemId: persil.id,
      quantity: 4,
      unitPrice: 1,
    );

    // The kitchen syncs after each of Bureau's batches arrives, so it sees
    // every in-between state: never a product without its category or unit.
    await bureau.sync();
    final cuisine = r['Cuisine'];
    await cuisine.sync();
    for (final item in await cuisine.items.items(r.storeId)) {
      expect(await cuisine.catalog.category(item.categoryId), isNotNull);
      expect(await cuisine.catalog.unit(item.unitId), isNotNull);
    }
    expect(await cuisine.stockOf(persil.id), 4);
    await r.settle();
  });

  test(
    'A5 — three tablets change different things in the same minute',
    () async {
      await r['Cuisine'].movements.recordStockOut(
        storeId: r.storeId,
        itemId: r.tomates.id,
        quantity: 2,
        reason: StockOutReason.sale,
      );
      await r['Bar'].catalog.createCategory(
        storeId: r.storeId,
        name: 'Boissons',
      );
      await r['Bureau'].suppliers.update(r.metro.id, phone: '081 99 99 99');
      await r.settle();

      for (final tablet in r.tablets.values) {
        expect(await tablet.stockOf(r.tomates.id), 8, reason: '$tablet');
        expect(
          [for (final c in await tablet.catalog.categories(r.storeId)) c.name],
          contains('Boissons'),
          reason: '$tablet',
        );
        expect(
          (await tablet.suppliers.supplier(r.metro.id))!.phone,
          '081 99 99 99',
          reason: '$tablet',
        );
      }
    },
  );

  test(
    'A6 — once everyone is up to date, nothing goes back and forth',
    () async {
      await r['Cuisine'].movements.recordStockOut(
        storeId: r.storeId,
        itemId: r.oignons.id,
        quantity: 1,
        reason: StockOutReason.sale,
      );
      await r.settle();

      for (final tablet in r.tablets.values) {
        final again = await tablet.sync();
        expect(again.accepted, 0, reason: '$tablet');
        expect(again.received, 0, reason: '$tablet');
      }
    },
  );
}
