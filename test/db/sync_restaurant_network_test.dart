// Group I: network trouble during a sync, and Group J: tablets joining and
// leaving (SYNC_TESTS_PLAN.md).

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/models/models.dart';
import 'package:stock_inventory/services/auth_service.dart';
import 'package:stock_inventory/services/sync_service.dart';

import '../support/db_fixture.dart';
import '../support/restaurant_tablets.dart';

void main() {
  late Restaurant r;

  setUp(() async => r = await Restaurant.open());

  Future<void> takeOut(Tablet t, Item item, double q) =>
      t.movements.recordStockOut(
        storeId: r.storeId,
        itemId: item.id,
        quantity: q,
        reason: StockOutReason.sale,
      );

  group('I — network trouble', () {
    test('I1 — the server saved the stock-outs but the answer was lost: they '
        'count once, not twice', () async {
      final cuisine = r['Cuisine'];
      for (var i = 0; i < 3; i++) {
        await takeOut(cuisine, r.oignons, 1);
      }
      r.server.loseAnswerOnce = true;
      expect((await cuisine.sync()).outcome, SyncOutcome.offline);
      expect(
        await cuisine.waiting(),
        greaterThan(0),
        reason: 'the tablet does not know they arrived',
      );

      await r.settle();
      for (final t in r.tablets.values) {
        expect(await t.stockOf(r.oignons.id), 17, reason: '$t');
        final outs = (await t.movements.movementsForItem(
          r.oignons.id,
        )).where((m) => m.type == StockMovementType.stockOut);
        expect(outs, hasLength(3), reason: '$t');
      }
    });

    test('I1b — a commande sent twice after a lost answer is still one sent '
        'commande', () async {
      final bureau = r['Bureau'];
      final order = await bureau.orders.createDraft(
        storeId: r.storeId,
        supplierId: r.metro.id,
        lines: [
          PurchaseOrderLine(
            id: '',
            itemId: r.tomates.id,
            quantityOrdered: 5,
            unitPrice: 2,
          ),
        ],
      );
      await bureau.orders.send(order.id);
      r.server.loseAnswerOnce = true;
      await bureau.sync();
      await r.settle();
      expect(await bureau.toCheck(), isEmpty);
      expect(await r['Cuisine'].orders.orders(r.storeId), hasLength(1));
    });

    test(
      'I1c — a resend after a lost answer does not undo what another '
      'tablet changed meanwhile',
      () async {
        final bureau = r['Bureau'];
        await bureau.items.update(r.tomates.id, lowStockThreshold: 4);
        r.server.loseAnswerOnce = true;
        await bureau.sync();
        // Meanwhile the bar, which received Bureau's change, changes it again.
        await r['Bar'].sync();
        expect((await r['Bar'].items.item(r.tomates.id))!.lowStockThreshold, 4);
        await r['Bar'].items.update(r.tomates.id, lowStockThreshold: 6);
        await r['Bar'].sync();

        await r.settle();
        for (final t in r.tablets.values) {
          expect(
            (await t.items.item(r.tomates.id))!.lowStockThreshold,
            6,
            reason: '$t',
          );
        }
      },
      skip: knownIssue(
        'F12: after a lost answer the tablet sends its old '
        'change again, over the newer one',
      ),
    );

    test('I2 — the download stops halfway, something changes, then it '
        'resumes: nothing skipped, nothing twice', () async {
      final bureau = r['Bureau'];
      final cuisine = r['Cuisine'];
      cuisine.offline();
      for (var i = 0; i < 30; i++) {
        await bureau.catalog.createCategory(storeId: r.storeId, name: 'C$i');
      }
      await bureau.sync();
      cuisine.online();
      r.server.failPullAfterPages = 1;
      expect((await cuisine.sync(pageSize: 10)).outcome, SyncOutcome.offline);
      await bureau.catalog.renameCategory(
        (await bureau.catalog.categoryNamed(r.storeId, 'C0'))!.id,
        'C0 bis',
      );
      await bureau.sync();
      expect((await cuisine.sync(pageSize: 10)).outcome, SyncOutcome.done);
      final names = [
        for (final c in await cuisine.catalog.categories(r.storeId)) c.name,
      ];
      expect(names, hasLength(31));
      expect(names, contains('C0 bis'));
      await r.settle();
    });

    test('I3 — one change refused in a batch: the others are saved, the '
        'refused one is listed, the queue empties', () async {
      final cuisine = r['Cuisine'];
      await takeOut(cuisine, r.tomates, 1);
      await cuisine.items.update(r.oignons.id, lowStockThreshold: 5);
      await cuisine.suppliers.update(r.metro.id, phone: '02 000 00 00');
      r.server.rejectWhen = (change) =>
          change['table'] == 'suppliers' ? 'invalid' : null;
      await cuisine.sync();
      r.server.rejectWhen = null;
      expect(await cuisine.waiting(), 0);
      expect(
        [for (final e in await cuisine.toCheck()) e.changedTable],
        ['suppliers'],
      );
      await r['Bar'].sync();
      expect(await r['Bar'].stockOf(r.tomates.id), 9);
      expect((await r['Bar'].items.item(r.oignons.id))!.lowStockThreshold, 5);
    });

    test(
      'I3b — after a refusal, the tablet that made the change shows what '
      'the others show',
      () async {
        final cuisine = r['Cuisine'];
        await cuisine.suppliers.update(r.metro.id, phone: '02 000 00 00');
        r.server.rejectWhen = (change) =>
            change['table'] == 'suppliers' ? 'invalid' : null;
        await cuisine.sync();
        r.server.rejectWhen = null;
        await r.settle();
      },
      skip: knownIssue(
        'F13: a refused change stays on the tablet that made '
        'it; the server\'s version is not put back',
      ),
    );

    test('I4 — the server down for several passes: nothing lost, the tries '
        'counted, everything leaves when it is back', () async {
      final cuisine = r['Cuisine'];
      await takeOut(cuisine, r.saumon, 1);
      final waiting = await cuisine.waiting();
      cuisine.offline();
      for (var i = 0; i < 3; i++) {
        expect((await cuisine.sync()).outcome, SyncOutcome.offline);
      }
      expect(await cuisine.waiting(), waiting);
      final attempts = await cuisine.db
          .customSelect('SELECT MAX(attempts) AS n FROM outbox')
          .getSingle();
      expect(attempts.data['n'], 3, reason: 'each failed pass is counted');
      cuisine.online();
      await r.settle();
      expect(await r['Bar'].stockOf(r.saumon.id), 4);
    });

    test('I6 — someone edits the kitchen tablet while it is receiving: the '
        'edit is kept and sent', () async {
      final cuisine = r['Cuisine'];
      await r['Bureau'].items.update(r.tomates.id, name: 'Tomate (Bureau)');
      await r['Bureau'].sync();
      cuisine.link.duringPull = () async {
        await cuisine.items.update(r.tomates.id, name: 'Tomate (Cuisine)');
      };
      await cuisine.sync();
      expect(
        (await cuisine.items.item(r.tomates.id))!.name,
        'Tomate (Cuisine)',
      );
      await r.settle();
      expect(
        (await r['Bureau'].items.item(r.tomates.id))!.name,
        'Tomate (Cuisine)',
      );
    });

    test(
      'I6b — a product deleted elsewhere, edited on the kitchen tablet '
      'while it was receiving the delete: deleted in the end',
      () async {
        final cuisine = r['Cuisine'];
        expect(await r['Bureau'].items.delete(r.saumon.id), isTrue);
        await r['Bureau'].sync();
        cuisine.link.duringPull = () async {
          await cuisine.items.update(r.saumon.id, lowStockThreshold: 1);
        };
        await cuisine.sync();
        await r.settle();
        expect(
          await cuisine.items.item(r.saumon.id),
          isNull,
          reason: 'the kitchen still shows a deleted product',
        );
      },
      skip: knownIssue(
        'F13: a refused change stays on the tablet that made '
        'it; the server\'s version is not put back',
      ),
    );

    test('I7 — 600 changes: sent in batches of 100, received in pages, the '
        'next pass receives nothing', () async {
      final bureau = r['Bureau'];
      for (var i = 0; i < 600; i++) {
        await bureau.catalog.createCategory(storeId: r.storeId, name: 'Cat $i');
      }
      r.server.batchSizes.clear();
      await bureau.sync();
      expect(r.server.batchSizes.take(6), everyElement(100));
      final first = await r['Cuisine'].sync(pageSize: 100);
      expect(first.received, greaterThanOrEqualTo(600));
      expect((await r['Cuisine'].sync(pageSize: 100)).received, 0);
      await r.settle();
    });
  });

  group('J — tablets joining and leaving', () {
    Future<void> aWeekOfWork() async {
      for (var day = 0; day < 7; day++) {
        await takeOut(r['Cuisine'], r.oignons, 1);
        await r['Bar'].movements.recordStockIn(
          storeId: r.storeId,
          itemId: r.tomates.id,
          quantity: 2,
          unitPrice: 2 + day / 10,
        );
        await r.syncAll();
      }
      expect(await r['Bureau'].items.delete(r.saumon.id), isTrue);
      await r.settle();
    }

    test('J1 — a new tablet joins after a week: everything, right figures, '
        'deleted rows hidden', () async {
      await aWeekOfWork();
      final terrasse = await r.addTablet('Terrasse');
      await r.settle();
      expect(await terrasse.stockOf(r.oignons.id), 13);
      expect(await terrasse.stockOf(r.tomates.id), 24);
      expect(await terrasse.items.items(r.storeId), hasLength(2));
      expect(await terrasse.waiting(), 0);
    });

    test(
      'J2 — a new tablet joins while the kitchen is offline with changes',
      () async {
        r['Cuisine'].offline();
        await takeOut(r['Cuisine'], r.tomates, 4);
        final terrasse = await r.addTablet('Terrasse');
        expect(await terrasse.stockOf(r.tomates.id), 10);
        r['Cuisine'].online();
        await r.settle();
        expect(await terrasse.stockOf(r.tomates.id), 6);
      },
    );

    test('J3 — the owner removes a lost tablet: it stops, its changes are not '
        'sent, the others carry on', () async {
      final bar = r['Bar'];
      bar.offline();
      for (var i = 0; i < 4; i++) {
        await takeOut(bar, r.tomates, 1);
      }
      expect(
        await r.server.removeDevice(await DeviceRepository(bar.db).deviceId()),
        isTrue,
      );
      bar.online();
      final result = await bar.sync();
      expect(result.outcome, SyncOutcome.deviceRemoved);
      expect(await bar.waiting(), greaterThan(0));
      bar.offline(); // out of the comparison
      await takeOut(r['Cuisine'], r.tomates, 1);
      await r.settle();
      expect(await r['Bureau'].stockOf(r.tomates.id), 9);
    });

    test('J4 — the session expired with changes waiting: nothing lost, they '
        'leave after signing in again', () async {
      final bureau = r['Bureau'];
      await bureau.items.update(r.tomates.id, lowStockThreshold: 2);
      final waiting = await bureau.waiting();
      r.server.failNext = const AccountException(
        AccountErrorCode.sessionExpired,
      );
      expect((await bureau.sync()).outcome, SyncOutcome.sessionExpired);
      expect(await bureau.waiting(), waiting);
      await r.settle();
      expect(
        (await r['Cuisine'].items.item(r.tomates.id))!.lowStockThreshold,
        2,
      );
    });

    test(
      'J6 — a tablet still in the demo next to the real ones sends nothing',
      () async {
        final before = r.server.serverRows.length;
        final demo = await openSeededDatabase();
        await DeviceAccessRepository(demo).writeDemo();
        await ItemRepository(demo).update(
          (await ItemRepository(
            demo,
          ).items((await StoreRepository(demo).stores()).first.id)).first.id,
          lowStockThreshold: 99,
        );
        // The sync only runs on an account device; the demo is not one.
        final access = await DeviceAccessRepository(demo).read();
        expect(access.isAccount, isFalse);
        expect(r.server.serverRows.length, before);
      },
    );
  });
}
