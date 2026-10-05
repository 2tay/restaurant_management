// Group E: commandes and deliveries across tablets (SYNC_TESTS_PLAN.md).
//
// The office PC orders, the kitchen and the bar receive. The server only
// lets a commande's status move forward, and keeps a closed one closed;
// receipts and their stock movements are add-only.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/models/models.dart';

import '../support/restaurant_tablets.dart';

void main() {
  late Restaurant r;

  setUp(() async => r = await Restaurant.open());

  /// A commande of 10 kg of tomatoes at 2 €, from Metro.
  Future<PurchaseOrder> draft(Tablet t, {double kg = 10}) =>
      t.orders.createDraft(
        storeId: r.storeId,
        supplierId: r.metro.id,
        lines: [
          PurchaseOrderLine(
            id: '',
            itemId: r.tomates.id,
            quantityOrdered: kg,
            unitPrice: 2,
          ),
        ],
      );

  Future<PurchaseOrder> sentOrder() async {
    final order = await draft(r['Bureau']);
    await r['Bureau'].orders.send(order.id);
    await r.settle();
    return order;
  }

  Future<GoodsReceipt?> receive(
    Tablet t,
    PurchaseOrder order,
    double kg, {
    double price = 2,
  }) async {
    final outstanding = (await t.orders.order(order.id))!.lines.single;
    return t.orders.confirmReceipt(
      orderId: order.id,
      receivedByName: t.name,
      lines: [
        ReceiptDraftLine(
          itemId: r.tomates.id,
          quantityOrdered:
              outstanding.quantityOrdered - outstanding.quantityReceived,
          quantityReceived: kg,
          orderedUnitPrice: 2,
          actualUnitPrice: price,
        ),
      ],
    );
  }

  Future<PurchaseOrderStatus> statusOn(Tablet t, PurchaseOrder order) async =>
      (await t.orders.order(order.id))!.status;

  Future<void> expectEverywhere(
    PurchaseOrder order, {
    required PurchaseOrderStatus status,
    required double stock,
    required int receipts,
  }) async {
    for (final t in r.tablets.values) {
      expect(await statusOn(t, order), status, reason: '$t');
      expect(await t.stockOf(r.tomates.id), stock, reason: '$t');
      expect(
        await t.orders.receiptsForOrder(order.id),
        hasLength(receipts),
        reason: '$t',
      );
    }
  }

  test(
    'E1 — ordered on the office PC, fully received in the kitchen',
    () async {
      final order = await sentOrder();
      expect(await statusOn(r['Cuisine'], order), PurchaseOrderStatus.sent);
      expect(await receive(r['Cuisine'], order, 10), isNotNull);
      await r.settle();
      await expectEverywhere(
        order,
        status: PurchaseOrderStatus.received,
        stock: 20,
        receipts: 1,
      );
    },
  );

  test(
    'E2 — half received in the kitchen, the rest later at the bar',
    () async {
      final order = await sentOrder();
      await receive(r['Cuisine'], order, 4);
      await r.settle();
      await expectEverywhere(
        order,
        status: PurchaseOrderStatus.partial,
        stock: 14,
        receipts: 1,
      );
      await receive(r['Bar'], order, 6);
      await r.settle();
      await expectEverywhere(
        order,
        status: PurchaseOrderStatus.received,
        stock: 20,
        receipts: 2,
      );
    },
  );

  test(
    'E2b — two part deliveries of one commande on two tablets offline: the '
    'commande adds both up',
    () async {
      final order = await sentOrder();
      r['Cuisine'].offline();
      r['Bar'].offline();
      await receive(r['Cuisine'], order, 4);
      await receive(r['Bar'], order, 3);
      r['Cuisine'].online();
      r['Bar'].online();
      await r.settle();
      await expectEverywhere(
        order,
        status: PurchaseOrderStatus.partial,
        stock: 17,
        receipts: 2,
      );
      final line = (await r['Bureau'].orders.order(order.id))!.lines.single;
      expect(
        line.quantityReceived,
        7,
        reason: 'the commande says what arrived',
      );
    },
    skip: knownIssue(
      'F6: a commande line is one row; the last tablet\'s '
      'received quantity replaces the other\'s',
    ),
  );

  test(
    'E3 — the same delivery confirmed on two tablets offline: shown, not '
    'silently counted twice',
    () async {
      final order = await sentOrder();
      r['Cuisine'].offline();
      r['Bar'].offline();
      await receive(r['Cuisine'], order, 10);
      await receive(r['Bar'], order, 10);
      r['Cuisine'].online();
      r['Bar'].online();
      await r.settle();
      // The owner expects the double to be flagged somewhere: the stock up by
      // 10 only, or a message to check.
      final told = [
        for (final t in r.tablets.values)
          for (final e in await t.toCheck())
            if (const {
              'purchase_orders',
              'purchase_order_lines',
              'goods_receipts',
              'goods_receipt_lines',
              'stock_movements',
            }.contains(e.changedTable))
              e,
      ];
      final stock = await r['Bureau'].stockOf(r.tomates.id);
      expect(
        stock == 20 || told.isNotEmpty,
        isTrue,
        reason: 'stock $stock and nothing to check',
      );
    },
    skip: knownIssue(
      'F7: a delivery confirmed twice adds the stock twice, '
      'with no warning',
    ),
  );

  test(
    'E3b — same as E3: what happens today is the same on every tablet',
    () async {
      final order = await sentOrder();
      r['Cuisine'].offline();
      r['Bar'].offline();
      await receive(r['Cuisine'], order, 10);
      await receive(r['Bar'], order, 10);
      r['Cuisine'].online();
      r['Bar'].online();
      await r.settle();
      await expectEverywhere(
        order,
        status: PurchaseOrderStatus.received,
        stock: 30,
        receipts: 2,
      );
    },
  );

  test('E4 — a draft changed offline after the office sent it: the sent '
      'commande stays, and the phone is told', () async {
    final order = await draft(r['Bureau']);
    await r.settle();
    r['Bar'].offline();
    await r['Bureau'].orders.send(order.id);
    await r.syncAll();
    final changed = await r['Bar'].orders.updateDraft(order.id, note: 'Urgent');
    expect(changed, isNotNull);

    r['Bar'].online();
    await r.settle();
    for (final t in r.tablets.values) {
      expect(await statusOn(t, order), PurchaseOrderStatus.sent, reason: '$t');
    }
    final told = [for (final e in await r['Bar'].toCheck()) e.reason];
    expect(told, contains('status_backwards'));
  });

  test('E5 — cancelled on the office PC while the kitchen received it offline: '
      'the goods stay in stock, and someone is told', () async {
    final order = await sentOrder();
    r['Cuisine'].offline();
    expect(await r['Bureau'].orders.cancel(order.id), isNotNull);
    await r.syncAll();
    await receive(r['Cuisine'], order, 10);
    r['Cuisine'].online();
    await r.settle();

    for (final t in r.tablets.values) {
      expect(
        await t.stockOf(r.tomates.id),
        20,
        reason: '$t: the goods are on the shelf',
      );
      expect(await t.orders.receiptsForOrder(order.id), hasLength(1));
    }
    final told = [for (final e in await r['Cuisine'].toCheck()) e.reason];
    expect(told, contains('status_closed'));
  });

  test(
    'E6 — a draft deleted on the office PC while the phone sent it offline',
    () async {
      final order = await draft(r['Bureau']);
      await r.settle();
      r['Bar'].offline();
      expect(await r['Bureau'].orders.deleteDraft(order.id), isTrue);
      await r.syncAll();
      expect(await r['Bar'].orders.send(order.id), isNotNull);
      r['Bar'].online();
      await r.settle();
      for (final t in r.tablets.values) {
        expect(await t.orders.order(order.id), isNull, reason: '$t');
      }
      expect([
        for (final e in await r['Bar'].toCheck()) e.reason,
      ], contains('deleted'));
    },
  );

  test('E7 — closed short on the office PC while the kitchen received the rest '
      'offline: stays closed, goods kept', () async {
    final order = await sentOrder();
    await receive(r['Cuisine'], order, 4);
    await r.settle();
    r['Cuisine'].offline();
    expect(await r['Bureau'].orders.closeShort(order.id), isNotNull);
    await r.syncAll();
    await receive(r['Cuisine'], order, 6);
    r['Cuisine'].online();
    await r.settle();
    await expectEverywhere(
      order,
      status: PurchaseOrderStatus.received,
      stock: 20,
      receipts: 2,
    );
  });

  test('E8 — a commande made offline for a supplier deleted elsewhere: no '
      'tablet breaks', () async {
    final boucher = await r['Bar'].suppliers.create(
      storeId: r.storeId,
      name: 'Boucherie',
      contactName: '',
      email: '',
      phone: '',
      addressLine: '',
      postalCode: '',
      city: '',
    );
    await r.settle();
    r['Bureau'].offline();
    expect(await r['Bar'].suppliers.delete(boucher.id), isTrue);
    await r.syncAll();
    final order = await r['Bureau'].orders.createDraft(
      storeId: r.storeId,
      supplierId: boucher.id,
      lines: [
        PurchaseOrderLine(
          id: '',
          itemId: r.saumon.id,
          quantityOrdered: 2,
          unitPrice: 20,
        ),
      ],
    );
    r['Bureau'].online();
    await r.settle();
    for (final t in r.tablets.values) {
      // The lists and the detail still open.
      await t.orders.orders(r.storeId);
      await t.orders.watchOrderDetail(order.id).first;
      await t.orders.watchOrderRows(r.storeId).first;
    }
  });

  test('E9 — a new price on delivery reaches every tablet', () async {
    await r['Bureau'].suppliers.linkItem(
      itemId: r.tomates.id,
      supplierId: r.metro.id,
      pricePerUnit: 2,
    );
    final order = await sentOrder();
    await receive(r['Cuisine'], order, 10, price: 2.4);
    await r.settle();
    for (final t in r.tablets.values) {
      final price = await t.suppliers.priceFor(r.tomates.id, r.metro.id);
      expect(price!.pricePerUnit, 2.4, reason: '$t');
      expect(
        await t.suppliers.priceHistoryFor(r.tomates.id, r.metro.id),
        isNotEmpty,
        reason: '$t',
      );
    }
  });

  test(
    'E10 — two commandes made offline on two tablets get different numbers',
    () async {
      r['Bureau'].offline();
      r['Bar'].offline();
      final one = await draft(r['Bureau']);
      final two = await draft(r['Bar']);
      r['Bureau'].online();
      r['Bar'].online();
      await r.settle();
      expect(one.reference, isNot(two.reference));
    },
    skip: knownIssue(
      'F8: each tablet numbers commandes from its own list, so '
      'two offline tablets give the same number',
    ),
  );

  test('E10b — same as E10: both commandes reach every tablet', () async {
    r['Bureau'].offline();
    r['Bar'].offline();
    await draft(r['Bureau']);
    await draft(r['Bar']);
    r['Bureau'].online();
    r['Bar'].online();
    await r.settle();
    expect(await r['Cuisine'].orders.orders(r.storeId), hasLength(2));
  });

  test('E11 — a receipt is never sent before its commande', () async {
    final bureau = r['Bureau'];
    bureau.offline();
    final order = await draft(bureau);
    await bureau.orders.send(order.id);
    await receive(bureau, order, 10);
    bureau.online();
    final sentTables = <String>[];
    r.server.rejectWhen = (change) {
      sentTables.add(change['table']! as String);
      return null;
    };
    await bureau.sync();
    expect(
      sentTables.indexOf('purchase_orders'),
      lessThan(sentTables.indexOf('goods_receipts')),
    );
    expect(
      sentTables.indexOf('goods_receipts'),
      lessThan(sentTables.indexOf('goods_receipt_lines')),
    );
    await r.settle();
  });

  test('E12 — the stock movement of a delivery links to its receipt on every '
      'tablet', () async {
    final order = await sentOrder();
    final receipt = (await receive(r['Cuisine'], order, 10))!;
    await r.settle();
    for (final t in r.tablets.values) {
      final movements = await MovementRepository(
        t.db,
      ).movementsForItem(r.tomates.id);
      expect(
        movements.where((m) => m.receiptId == receipt.id),
        hasLength(1),
        reason: '$t',
      );
    }
  });
}
