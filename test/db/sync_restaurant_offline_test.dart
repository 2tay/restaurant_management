// Group B: one tablet loses the Wi-Fi, the others carry on
// (SYNC_TESTS_PLAN.md).

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/models/models.dart';
import 'package:stock_inventory/services/sync_service.dart';

import '../support/restaurant_tablets.dart';

void main() {
  late Restaurant r;

  setUp(() async => r = await Restaurant.open());

  Future<void> out(Tablet t, Item item, double quantity) =>
      t.movements.recordStockOut(
        storeId: r.storeId,
        itemId: item.id,
        quantity: quantity,
        reason: StockOutReason.sale,
      );

  test(
    'B1 — the kitchen loses the Wi-Fi during service, the bar does not',
    () async {
      final cuisine = r['Cuisine'];
      cuisine.offline();
      for (var i = 0; i < 10; i++) {
        await out(cuisine, r.oignons, 1);
      }
      for (var i = 0; i < 5; i++) {
        await out(r['Bar'], r.oignons, 1);
        await r.syncAll();
      }
      expect(await r['Bar'].stockOf(r.oignons.id), 15);

      cuisine.online();
      await r.settle();
      for (final t in r.tablets.values) {
        expect(await t.stockOf(r.oignons.id), 5, reason: '$t'); // 20 − 15
      }
    },
  );

  test(
    'B2 — the offline tablet still shows what it had, and counts waits',
    () async {
      final cuisine = r['Cuisine'];
      cuisine.offline();
      for (var i = 0; i < 10; i++) {
        await out(cuisine, r.tomates, 0.5);
      }
      expect((await cuisine.sync()).outcome, SyncOutcome.offline);

      expect(await cuisine.items.items(r.storeId), hasLength(3));
      expect(await cuisine.stockOf(r.tomates.id), 5);
      // Ten movements, and the article each time: one entry per row.
      expect(await cuisine.waiting(), 11);
      cuisine.online();
      await r.settle();
    },
  );

  test(
    'B3 — what changed while the kitchen was offline arrives when it is back',
    () async {
      final cuisine = r['Cuisine'];
      cuisine.offline();
      final bureau = r['Bureau'];
      final made = <Item>[];
      for (final name in ['Basilic', 'Thym', 'Romarin']) {
        made.add(
          (await bureau.items.create(
            storeId: r.storeId,
            name: name,
            categoryId: r.legumes.id,
            unitId: r.kg.id,
            lowStockThreshold: 1,
          ))!,
        );
      }
      expect(await bureau.items.delete(r.saumon.id), isTrue);
      await r.syncAll();
      expect(await cuisine.items.items(r.storeId), hasLength(3));

      cuisine.online();
      await r.settle();
      final names = [
        for (final i in await cuisine.items.items(r.storeId)) i.name,
      ]..sort();
      expect(names, ['Basilic', 'Oignons', 'Romarin', 'Thym', 'Tomates']);
    },
  );

  for (final barFirst in [true, false]) {
    test(
      'B4 — two tablets offline, back ${barFirst ? 'bar' : 'kitchen'} first: '
      'same result',
      () async {
        final cuisine = r['Cuisine'];
        final bar = r['Bar'];
        cuisine.offline();
        bar.offline();
        await out(cuisine, r.tomates, 2);
        await bar.movements.recordStockIn(
          storeId: r.storeId,
          itemId: r.tomates.id,
          quantity: 6,
          unitPrice: 3,
        );
        await cuisine.catalog.createCategory(
          storeId: r.storeId,
          name: 'Fruits',
        );
        await bar.items.update(r.oignons.id, lowStockThreshold: 9);

        for (final t in barFirst ? [bar, cuisine] : [cuisine, bar]) {
          t.online();
          await r.syncAll();
        }
        await r.settle();
        for (final t in r.tablets.values) {
          expect(await t.stockOf(r.tomates.id), 14, reason: '$t');
          expect((await t.items.item(r.oignons.id))!.lowStockThreshold, 9);
          expect([
            for (final c in await t.catalog.categories(r.storeId)) c.name,
          ], contains('Fruits'));
        }
      },
    );
  }

  test(
    'B5 — the whole restaurant loses the internet for the evening',
    () async {
      for (final t in r.tablets.values) {
        t.offline();
      }
      await out(r['Cuisine'], r.saumon, 1);
      await out(r['Bar'], r.saumon, 1);
      await r['Bureau'].movements.recordStockIn(
        storeId: r.storeId,
        itemId: r.saumon.id,
        quantity: 10,
        unitPrice: 22,
      );
      await out(r['Cuisine'], r.saumon, 2);
      for (final t in r.tablets.values) {
        t.online();
      }
      await r.settle();
      for (final t in r.tablets.values) {
        expect(await t.stockOf(r.saumon.id), 11, reason: '$t'); // 5 − 4 + 10
      }
    },
  );

  test('B6 — a week offline: hundreds of changes on both sides', () async {
    final cuisine = r['Cuisine'];
    cuisine.offline();
    final start = DateTime(2026, 10, 1, 9);
    for (var i = 0; i < 150; i++) {
      final at = start.add(Duration(minutes: 67 * i));
      await withClock(Clock.fixed(at), () async {
        await out(cuisine, r.oignons, 0.1);
        await r['Bar'].movements.recordStockIn(
          storeId: r.storeId,
          itemId: r.oignons.id,
          quantity: 0.1,
          unitPrice: 1,
        );
      });
    }
    await r.syncAll();
    cuisine.online();
    final first = await cuisine.sync(pageSize: 50);
    expect(first.outcome, SyncOutcome.done);
    expect(r.server.batchSizes.where((n) => n == 100), isNotEmpty);
    await r.settle();
    for (final t in r.tablets.values) {
      expect(await t.stockOf(r.oignons.id), closeTo(20, 1e-9), reason: '$t');
    }
  });

  test(
    'B7 — Wi-Fi going on and off while working: nothing lost, nothing twice',
    () async {
      final cuisine = r['Cuisine'];
      for (var i = 0; i < 12; i++) {
        if (i.isEven) cuisine.offline();
        if (i % 4 == 1) cuisine.online();
        await out(cuisine, r.oignons, 1);
        await cuisine.sync();
        await r['Bar'].sync();
      }
      cuisine.online();
      await r.settle();
      for (final t in r.tablets.values) {
        expect(await t.stockOf(r.oignons.id), 8, reason: '$t');
      }
    },
  );

  test(
    'B8 — closed for the night with changes unsent: they leave in the morning',
    () async {
      final cuisine = r['Cuisine'];
      cuisine.offline();
      for (var i = 0; i < 5; i++) {
        await out(cuisine, r.tomates, 1);
      }
      expect(await cuisine.waiting(), greaterThan(0));
      // The next morning: a new pass on the same database, Wi-Fi back.
      cuisine.online();
      final morning = await SyncRunner(
        db: cuisine.db,
        backend: cuisine.link,
      ).run();
      expect(morning.outcome, SyncOutcome.done);
      await r.settle();
      expect(await r['Bureau'].stockOf(r.tomates.id), 5);
    },
  );
}
