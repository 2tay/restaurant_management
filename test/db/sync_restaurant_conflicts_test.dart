// Group D: the same product changed on two tablets, and Group K: tablets
// whose clock is wrong (SYNC_TESTS_PLAN.md).
//
// Tests marked `skip: 'Fx …'` describe what a restaurant owner expects and
// what the app does not do yet; SYNC_TESTS.md explains each finding.

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/models/models.dart';

import '../support/restaurant_tablets.dart';

void main() {
  late Restaurant r;

  setUp(() async => r = await Restaurant.open());

  final now = DateTime.now();
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  DateTime at(int hour, [int minute = 0]) =>
      tomorrow.add(Duration(hours: hour, minutes: minute));

  Future<String> nameOn(Tablet t, Item item) async =>
      (await t.items.item(item.id))!.name;

  group('D — one product, two tablets', () {
    test(
      'D1 — renamed on two tablets online: the last sent wins everywhere',
      () async {
        await r['Bureau'].items.update(r.tomates.id, name: 'Tomate ronde');
        await r['Bureau'].sync();
        await r['Bar'].items.update(r.tomates.id, name: 'Tomate cerise');
        await r['Bar'].sync();
        await r.settle();
        for (final t in r.tablets.values) {
          expect(await nameOn(t, r.tomates), 'Tomate cerise', reason: '$t');
        }
      },
    );

    test(
      'D2 — two different fields changed offline: both kept',
      () async {
        r['Bureau'].offline();
        r['Bar'].offline();
        await r['Bureau'].items.update(r.tomates.id, lowStockThreshold: 7);
        final fruits = (await r['Bar'].catalog.createCategory(
          storeId: r.storeId,
          name: 'Fruits',
        ))!;
        await r['Bar'].items.update(r.tomates.id, categoryId: fruits.id);
        r['Bureau'].online();
        r['Bar'].online();
        await r.settle();
        for (final t in r.tablets.values) {
          final item = (await t.items.item(r.tomates.id))!;
          expect(item.categoryId, fruits.id, reason: '$t: Bar\'s change');
          expect(item.lowStockThreshold, 7, reason: '$t: Bureau\'s change');
        }
      },
      skip: knownIssue(
        'F3: a product sends its whole row, the last one drops the other '
        'tablet\'s field',
      ),
    );

    test('D2b — same as D2, but what the app does today is at least the same '
        'on every tablet', () async {
      r['Bureau'].offline();
      r['Bar'].offline();
      await r['Bureau'].items.update(r.tomates.id, lowStockThreshold: 7);
      await r['Bar'].items.update(r.tomates.id, maxStock: 40);
      r['Bureau'].online();
      r['Bar'].online();
      await r.settle();
    });

    test(
      'D3 — an edit made offline yesterday does not undo today\'s',
      () async {
        final cuisine = r['Cuisine'];
        cuisine.offline();
        await withClock(Clock.fixed(at(-20)), () async {
          await cuisine.items.update(r.tomates.id, lowStockThreshold: 5);
        });
        await withClock(Clock.fixed(at(9)), () async {
          await r['Bureau'].items.update(r.tomates.id, lowStockThreshold: 8);
        });
        await r.syncAll();
        cuisine.online();
        await r.settle();
        for (final t in r.tablets.values) {
          expect(
            (await t.items.item(r.tomates.id))!.lowStockThreshold,
            8,
            reason: '$t',
          );
        }
      },
      skip: knownIssue(
        'F4: the last change to reach the server wins, even when it was '
        'made long before',
      ),
    );

    test('D4 — a supplier edited offline while the office deleted it: '
        'deleted everywhere, and the bar is told', () async {
      final boucher = await r['Bureau'].suppliers.create(
        storeId: r.storeId,
        name: 'Boucherie',
        contactName: '',
        email: '',
        phone: '081',
        addressLine: '',
        postalCode: '',
        city: '',
      );
      await r.settle();
      final bar = r['Bar'];
      bar.offline();
      expect(await r['Bureau'].suppliers.delete(boucher.id), isTrue);
      await r.syncAll();
      await bar.suppliers.update(boucher.id, phone: '0470 12 34 56');

      bar.online();
      await r.settle();
      for (final t in r.tablets.values) {
        expect(
          [for (final s in await t.suppliers.suppliers(r.storeId)) s.id],
          isNot(contains(boucher.id)),
          reason: '$t',
        );
      }
      final told = await bar.toCheck();
      expect([for (final e in told) e.reason], contains('deleted'));
    });

    test('D5 — the same product deleted on two tablets: no error', () async {
      r['Cuisine'].offline();
      expect(await r['Cuisine'].items.delete(r.saumon.id), isTrue);
      expect(await r['Bar'].items.delete(r.saumon.id), isTrue);
      await r.syncAll();
      r['Cuisine'].online();
      await r.settle();
      for (final t in r.tablets.values) {
        expect(await t.items.item(r.saumon.id), isNull, reason: '$t');
        expect(await t.toCheck(), isEmpty, reason: '$t');
      }
    });

    test('D6 — the same new product made on two tablets offline: two products, '
        'the same on every tablet', () async {
      r['Cuisine'].offline();
      r['Bar'].offline();
      for (final t in [r['Cuisine'], r['Bar']]) {
        await t.items.create(
          storeId: r.storeId,
          name: 'Basilic',
          categoryId: r.legumes.id,
          unitId: r.kg.id,
          lowStockThreshold: 1,
        );
      }
      r['Cuisine'].online();
      r['Bar'].online();
      await r.settle();
      final basilic = [
        for (final i in await r['Bureau'].items.items(r.storeId))
          if (i.name == 'Basilic') i,
      ];
      expect(basilic, hasLength(2));
    });

    test('D7 — the same barcode given to two products offline: the clash is '
        'visible', () async {
      r['Cuisine'].offline();
      await r['Cuisine'].items.update(r.tomates.id, barcode: '5400000000017');
      await r['Bar'].items.update(r.oignons.id, barcode: '5400000000017');
      await r.syncAll();
      r['Cuisine'].online();
      await r.settle();
      final withCode = await r['Bureau'].items.itemsWithBarcode(
        r.storeId,
        '5400000000017',
      );
      expect(withCode, hasLength(2));
    });

    test(
      'D8 — an edit made while the previous one is on its way is not lost',
      () async {
        final bar = r['Bar'];
        await bar.items.update(r.tomates.id, lowStockThreshold: 4);
        r.server.duringPush = () async {
          r.server.duringPush = null;
          await bar.items.update(r.tomates.id, lowStockThreshold: 9);
        };
        await bar.sync();
        await r.settle();
        for (final t in r.tablets.values) {
          expect(
            (await t.items.item(r.tomates.id))!.lowStockThreshold,
            9,
            reason: '$t',
          );
        }
      },
    );
  });

  group('F1, F2 — what the comparison leaves out', () {
    test(
      'F1 — after a rebuild, a product\'s change stamp is the same on every '
      'tablet',
      () async {
        r['Cuisine'].offline();
        r['Bar'].offline();
        await r['Bar'].movements.recordStockOut(
          storeId: r.storeId,
          itemId: r.tomates.id,
          quantity: 3,
          reason: StockOutReason.sale,
          occurredAt: at(18),
        );
        await r['Cuisine'].movements.recordAdjustment(
          storeId: r.storeId,
          itemId: r.tomates.id,
          systemQuantity: 10,
          countedQuantity: 10,
          occurredAt: at(18, 30),
        );
        r['Cuisine'].online();
        r['Bar'].online();
        await r.settle();
        final cuisine = await tableRows(r['Cuisine'].db, 'items', strict: true);
        final bar = await tableRows(r['Bar'].db, 'items', strict: true);
        expect(bar, cuisine);
      },
      skip: knownIssue(
        'F1: the rebuild stamps updated_at only where the figures moved',
      ),
    );
  });

  group('K — wrong clocks', () {
    test('K1 — a tablet two hours behind: the order of arrival decides, not '
        'its clock', () async {
      await withClock(Clock.fixed(at(12)), () async {
        await r['Cuisine'].items.update(r.saumon.id, name: 'Saumon frais');
      });
      await r['Cuisine'].sync();
      await withClock(Clock.fixed(at(10, 5)), () async {
        await r['Bar'].items.update(r.saumon.id, name: 'Saumon d\'Écosse');
      });
      await r['Bar'].sync();
      await r.settle();
      for (final t in r.tablets.values) {
        expect(await nameOn(t, r.saumon), 'Saumon d\'Écosse', reason: '$t');
      }
    });

    test(
      'K2 — a delivery on a tablet one day behind, after a count elsewhere: '
      'the delivery still counts',
      () async {
        r['Bar'].offline();
        // Really 18:00: the kitchen counts 10 kg.
        await r['Cuisine'].movements.recordAdjustment(
          storeId: r.storeId,
          itemId: r.tomates.id,
          systemQuantity: 10,
          countedQuantity: 10,
          occurredAt: at(18),
        );
        // Really 19:00, 5 kg arrive at the bar, whose clock says yesterday.
        await withClock(Clock.fixed(at(19 - 24)), () async {
          await r['Bar'].movements.recordStockIn(
            storeId: r.storeId,
            itemId: r.tomates.id,
            quantity: 5,
            unitPrice: 2,
          );
        });
        await r.syncAll();
        r['Bar'].online();
        await r.settle();
        expect(await r['Bureau'].stockOf(r.tomates.id), 15);
      },
      skip: knownIssue(
        'F5: movements are replayed by device time; a delivery dated '
        'before a count is absorbed by it',
      ),
    );

    test('K2b — same as K2: what happens today is at least the same on every '
        'tablet', () async {
      r['Bar'].offline();
      await r['Cuisine'].movements.recordAdjustment(
        storeId: r.storeId,
        itemId: r.tomates.id,
        systemQuantity: 10,
        countedQuantity: 10,
        occurredAt: at(18),
      );
      await withClock(Clock.fixed(at(19 - 24)), () async {
        await r['Bar'].movements.recordStockIn(
          storeId: r.storeId,
          itemId: r.tomates.id,
          quantity: 5,
          unitPrice: 2,
        );
      });
      r['Bar'].online();
      await r.settle();
    });

    test(
      'K3 — a clock jumping back an hour (summer time) breaks nothing',
      () async {
        await withClock(Clock.fixed(at(3)), () async {
          await r['Cuisine'].items.update(r.oignons.id, lowStockThreshold: 4);
        });
        await withClock(Clock.fixed(at(2, 30)), () async {
          await r['Cuisine'].items.update(r.oignons.id, lowStockThreshold: 6);
        });
        await r.settle();
        expect((await r['Bar'].items.item(r.oignons.id))!.lowStockThreshold, 6);
      },
    );
  });
}
