// Group C: stock math when tablets disagree (SYNC_TESTS_PLAN.md).
//
// The stock on every tablet is replayed from the movements, so whatever the
// order they arrive in, every tablet must end with the same, right figures.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/models/models.dart';

import '../support/restaurant_tablets.dart';

void main() {
  late Restaurant r;

  setUp(() async => r = await Restaurant.open());

  // Tomorrow, so every movement comes after the products' opening stock,
  // which is dated now.
  final today = DateTime.now();
  final evening = DateTime(today.year, today.month, today.day + 1);
  DateTime at(int hour, [int minute = 0]) =>
      evening.add(Duration(hours: hour, minutes: minute));

  Future<void> stockOut(Tablet t, Item item, double q, {DateTime? when}) =>
      t.movements.recordStockOut(
        storeId: r.storeId,
        itemId: item.id,
        quantity: q,
        reason: StockOutReason.sale,
        occurredAt: when,
      );

  Future<void> count(
    Tablet t,
    Item item,
    double counted, {
    DateTime? when,
  }) async => t.movements.recordAdjustment(
    storeId: r.storeId,
    itemId: item.id,
    systemQuantity: await t.stockOf(item.id),
    countedQuantity: counted,
    occurredAt: when,
  );

  void bothOffline() {
    r['Cuisine'].offline();
    r['Bar'].offline();
  }

  Future<void> bothBack() async {
    r['Cuisine'].online();
    r['Bar'].online();
    await r.settle();
  }

  Future<void> expectStock(Item item, double quantity) async {
    for (final t in r.tablets.values) {
      expect(await t.stockOf(item.id), closeTo(quantity, 1e-9), reason: '$t');
    }
  }

  test(
    'C1 — two deliveries at once, at two prices: 10 kg and one average cost',
    () async {
      bothOffline();
      await r['Cuisine'].movements.recordStockIn(
        storeId: r.storeId,
        itemId: r.tomates.id,
        quantity: 5,
        unitPrice: 2,
      );
      await r['Bar'].movements.recordStockIn(
        storeId: r.storeId,
        itemId: r.tomates.id,
        quantity: 5,
        unitPrice: 4,
      );
      await bothBack();
      await expectStock(r.tomates, 20);
      // 10 kg at 2 €, 5 at 2 €, 5 at 4 € → 2.5 €.
      expect(
        (await r['Bureau'].items.item(r.tomates.id))!.averageCost,
        closeTo(2.5, 1e-9),
      );
    },
  );

  test('C2 — two stock-outs at once: both come off', () async {
    bothOffline();
    await stockOut(r['Cuisine'], r.tomates, 3);
    await stockOut(r['Bar'], r.tomates, 3);
    await bothBack();
    await expectStock(r.tomates, 4);
  });

  test('C3 — taking out more than there is: both kept, stock below zero, '
      'and an alert', () async {
    bothOffline();
    await stockOut(r['Cuisine'], r.tomates, 8);
    await stockOut(r['Bar'], r.tomates, 8);
    await bothBack();
    await expectStock(r.tomates, -6);
    final movements = await r['Bureau'].movements.movementsForItem(
      r.tomates.id,
    );
    expect(
      movements.where((m) => m.type == StockMovementType.stockOut),
      hasLength(2),
    );
    final alerts = await r['Bureau'].db
        .customSelect(
          'SELECT * FROM notifications WHERE deleted_at IS NULL '
          "AND related_item_id = '${r.tomates.id}'",
        )
        .get();
    expect(
      alerts,
      isNotEmpty,
      reason: 'someone must be told the stock ran out',
    );
  });

  test('C4 — a count made after a stock-out on another tablet does not take it '
      'twice', () async {
    bothOffline();
    await stockOut(r['Bar'], r.tomates, 3, when: at(18));
    // The kitchen never saw those 3 kg go, and counts the shelf at 18:30.
    await count(r['Cuisine'], r.tomates, 10, when: at(18, 30));
    await bothBack();
    await expectStock(r.tomates, 10);
  });

  test('C5 — a stock-out after a count comes off the count', () async {
    bothOffline();
    await count(r['Cuisine'], r.tomates, 10, when: at(18));
    await stockOut(r['Bar'], r.tomates, 3, when: at(18, 30));
    await bothBack();
    await expectStock(r.tomates, 7);
  });

  test('C6 — two counts at once: the later count is the stock', () async {
    bothOffline();
    await count(r['Cuisine'], r.tomates, 10, when: at(18));
    await count(r['Bar'], r.tomates, 12, when: at(18, 5));
    await bothBack();
    await expectStock(r.tomates, 12);
  });

  test(
    'C7 — yesterday\'s movement arriving after today\'s: replayed by time',
    () async {
      final bar = r['Bar'];
      bar.offline();
      await bar.movements.recordStockIn(
        storeId: r.storeId,
        itemId: r.saumon.id,
        quantity: 5,
        unitPrice: 30,
        occurredAt: at(9),
      );
      await r['Cuisine'].movements.recordStockIn(
        storeId: r.storeId,
        itemId: r.saumon.id,
        quantity: 10,
        unitPrice: 10,
        occurredAt: at(20),
      );
      await r.syncAll();
      bar.online();
      await r.settle();
      await expectStock(r.saumon, 20);

      // The same movements on one tablet, in time order, give the same cost.
      final solo = await Restaurant.open(tablets: ['Seul']);
      await solo['Seul'].movements.recordStockIn(
        storeId: solo.storeId,
        itemId: solo.saumon.id,
        quantity: 5,
        unitPrice: 30,
        occurredAt: at(9),
      );
      await solo['Seul'].movements.recordStockIn(
        storeId: solo.storeId,
        itemId: solo.saumon.id,
        quantity: 10,
        unitPrice: 10,
        occurredAt: at(20),
      );
      expect(
        (await r['Bureau'].items.item(r.saumon.id))!.averageCost,
        closeTo(
          (await solo['Seul'].items.item(solo.saumon.id))!.averageCost!,
          1e-9,
        ),
      );
    },
  );

  test('C8 — a stock-out on a product deleted on the office PC', () async {
    final cuisine = r['Cuisine'];
    cuisine.offline();
    expect(await r['Bureau'].items.delete(r.saumon.id), isTrue);
    await r.syncAll();
    await stockOut(cuisine, r.saumon, 1);
    cuisine.online();
    await r.settle();
    for (final t in r.tablets.values) {
      expect(
        [for (final i in await t.items.items(r.storeId)) i.name],
        isNot(contains('Saumon')),
        reason: '$t: a deleted product must not come back',
      );
    }
  });

  test(
    'C9 — a stock-in made before the product\'s opening stock arrived',
    () async {
      final bureau = r['Bureau'];
      final cuisine = r['Cuisine'];
      final beurre = (await bureau.items.create(
        storeId: r.storeId,
        name: 'Beurre',
        categoryId: r.legumes.id,
        unitId: r.kg.id,
        lowStockThreshold: 1,
        quantity: 4,
        openingUnitCost: 8,
      ))!;
      await bureau.sync();
      await cuisine.sync();
      cuisine.offline();
      await cuisine.movements.recordStockIn(
        storeId: r.storeId,
        itemId: beurre.id,
        quantity: 2,
        unitPrice: 9,
      );
      await stockOut(bureau, beurre, 1);
      await r.syncAll();
      cuisine.online();
      await r.settle();
      await expectStock(beurre, 5);
    },
  );

  test('C10 — 300 random movements on 3 tablets with random Wi-Fi cuts give '
      'the same stock as one tablet doing them all', () async {
    final random = Random(42);
    final tablets = r.tablets.values.toList();
    final products = r.products.values.toList();
    final done =
        <({String kind, Item item, double q, double price, DateTime when})>[];
    final start = at(8);

    for (var i = 0; i < 300; i++) {
      final t = tablets[random.nextInt(tablets.length)];
      if (random.nextInt(10) == 0) t.isOffline ? t.online() : t.offline();
      final item = products[random.nextInt(products.length)];
      final when = start.add(Duration(minutes: i * 7 + random.nextInt(5)));
      final kind = random.nextInt(10) < 6 ? 'out' : 'in';
      final q = (random.nextInt(20) + 1) / 4;
      final price = (random.nextInt(40) + 4) / 4;
      if (kind == 'out') {
        await stockOut(t, item, q, when: when);
      } else {
        await t.movements.recordStockIn(
          storeId: r.storeId,
          itemId: item.id,
          quantity: q,
          unitPrice: price,
          occurredAt: when,
        );
      }
      done.add((kind: kind, item: item, q: q, price: price, when: when));
      if (random.nextInt(4) == 0) await r.syncAll();
    }
    for (final t in tablets) {
      t.online();
    }
    await r.settle();

    final solo = await Restaurant.open(tablets: ['Seul']);
    final byName = {for (final i in done) i.item.name: i.item};
    for (final m in done) {
      final item = solo.products[m.item.name]!;
      if (m.kind == 'out') {
        await solo['Seul'].movements.recordStockOut(
          storeId: solo.storeId,
          itemId: item.id,
          quantity: m.q,
          reason: StockOutReason.sale,
          occurredAt: m.when,
        );
      } else {
        await solo['Seul'].movements.recordStockIn(
          storeId: solo.storeId,
          itemId: item.id,
          quantity: m.q,
          unitPrice: m.price,
          occurredAt: m.when,
        );
      }
    }
    for (final name in byName.keys) {
      final there = (await r['Bureau'].items.item(r.products[name]!.id))!;
      final alone = (await solo['Seul'].items.item(solo.products[name]!.id))!;
      expect(there.quantity, closeTo(alone.quantity, 1e-9), reason: name);
      expect(
        there.averageCost ?? 0,
        closeTo(alone.averageCost ?? 0, 1e-6),
        reason: name,
      );
    }
    expect(
      await StockLedger(r['Bureau'].db).rebuildStore(r.storeId),
      isEmpty,
      reason: 'a rebuild on a settled tablet changes nothing',
    );
  });
}
