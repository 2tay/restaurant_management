// Commandes on two tablets (MANUAL_TESTS_MULTI_TABLET_SYNC.md, part 5).
//
// Two devices of one restaurant share one fake server. "Offline" means a
// device does not sync until the test says so; a full round is A, B, A. Every
// test ends by checking that both tablets hold exactly the same commandes,
// receipts and stock.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/models/models.dart';
import 'package:stock_inventory/services/sync_service.dart';

import '../support/db_fixture.dart';
import '../support/fake_account_backend.dart';

void main() {
  late FakeAccountBackend server;
  late String organization;

  setUp(() async {
    server = FakeAccountBackend();
    organization = server.addOrganization('Brasserie');
    server.addUser(
      'owner@resto.be',
      'motdepasse',
      organizationId: organization,
    );
    await server.signIn(email: 'owner@resto.be', password: 'motdepasse');
  });

  /// A registered account device with an empty database.
  Future<AppDatabase> newDevice() async {
    final db = openEmptyDatabase();
    await server.registerDevice(await DeviceRepository(db).deviceId());
    await DeviceAccessRepository(db).writeAccount(
      email: 'owner@resto.be',
      organizationId: organization,
      organizationName: 'Brasserie',
      role: 'owner',
    );
    return db;
  }

  Future<void> sync(AppDatabase db) async {
    final result = await SyncRunner(db: db, backend: server).run();
    expect(result.outcome, isNot(SyncOutcome.failed), reason: result.detail);
  }

  Future<void> fullRound(AppDatabase a, AppDatabase b) async {
    await sync(a);
    await sync(b);
    await sync(a);
  }

  /// A store with one supplier delivering water (50 in stock) and cola (20),
  /// made on A and synced to B.
  Future<({Store store, Supplier supplier, Item water, Item cola})> setUpShop(
    AppDatabase a,
    AppDatabase b,
  ) async {
    final store = await StoreRepository(a).createStore(
      name: 'Brasserie',
      addressLine: '',
      postalCode: '',
      city: 'Namur',
      phone: '081',
    );
    await EmployeeRepository(a).create(
      storeId: store.id,
      firstName: 'Léa',
      lastName: 'Martin',
      pin: 'LM-2026',
      phone: '081',
      email: 'owner@resto.be',
      role: EmployeeRole.owner,
      pay: 0,
    );
    final category = (await CatalogRepository(
      a,
    ).createCategory(storeId: store.id, name: 'Boissons'))!;
    final unit = (await CatalogRepository(
      a,
    ).createUnit(storeId: store.id, name: 'Bouteille', abbreviation: 'btl'))!;
    final supplier = await SupplierRepository(a).create(
      storeId: store.id,
      name: 'Grossiste Test',
      contactName: 'Marc',
      email: 'marc@grossiste.be',
      phone: '02',
      addressLine: '',
      postalCode: '',
      city: 'Bruxelles',
    );
    Future<Item> item(String name, double quantity, double cost) async {
      final created = (await ItemRepository(a).create(
        storeId: store.id,
        name: name,
        categoryId: category.id,
        unitId: unit.id,
        lowStockThreshold: 5,
        quantity: quantity,
        openingUnitCost: cost,
      ))!;
      await SupplierRepository(a).linkItem(
        itemId: created.id,
        supplierId: supplier.id,
        pricePerUnit: cost,
        makeDefault: true,
      );
      return created;
    }

    final water = await item('Eau', 50, 0.5);
    final cola = await item('Cola', 20, 1);
    await sync(a);
    await sync(b);
    return (store: store, supplier: supplier, water: water, cola: cola);
  }

  /// A sent commande on [db] for [lines] (article, quantity, price).
  Future<PurchaseOrder> sentOrder(
    AppDatabase db,
    ({Store store, Supplier supplier, Item water, Item cola}) shop,
    List<(Item, double, double)> lines,
  ) async {
    final orders = OrderRepository(db);
    final draft = await orders.createDraft(
      storeId: shop.store.id,
      supplierId: shop.supplier.id,
      lines: [
        for (final (item, quantity, price) in lines)
          PurchaseOrderLine(
            id: '',
            itemId: item.id,
            quantityOrdered: quantity,
            unitPrice: price,
          ),
      ],
    );
    return (await orders.send(draft.id))!;
  }

  /// Receives [quantities] (by article id) on [db]; closes short on request.
  Future<GoodsReceipt> receive(
    AppDatabase db,
    String orderId,
    Map<String, double> quantities, {
    Map<String, double> prices = const {},
    bool closeShort = false,
    String name = 'Léa Martin',
  }) async {
    final order = (await OrderRepository(db).order(orderId))!;
    final receipt = await OrderRepository(db).confirmReceipt(
      orderId: orderId,
      receivedByName: name,
      lines: [
        for (final line in order.lines)
          if (quantities.containsKey(line.itemId))
            ReceiptDraftLine(
              itemId: line.itemId,
              quantityOrdered: line.quantityOrdered,
              quantityReceived: quantities[line.itemId]!,
              orderedUnitPrice: line.unitPrice,
              actualUnitPrice: prices[line.itemId] ?? line.unitPrice,
              closeShort: closeShort,
            ),
      ],
    );
    expect(receipt, isNotNull, reason: 'the commande could be received');
    return receipt!;
  }

  /// Everything a person would compare between two tablets for one store.
  Future<Map<String, Object?>> snapshot(AppDatabase db, String storeId) async {
    final orders = OrderRepository(db);
    final items = await ItemRepository(db).items(storeId);
    final movements = await MovementRepository(db).movementsForStore(storeId);
    return {
      'orders': {
        for (final order in await orders.orders(storeId))
          order.id: {
            'reference': order.reference,
            'status': order.status.name,
            'lines': {
              for (final line in order.lines)
                line.itemId: (line.quantityReceived, line.closedShort),
            },
            'receipts': [
              for (final receipt in await orders.receiptsForOrder(order.id))
                receipt.id,
            ]..sort(),
          },
      },
      'stock': {
        for (final item in items)
          item.name: (item.quantity, item.averageCost?.toStringAsFixed(6)),
      },
      'movements': [for (final m in movements) m.id]..sort(),
    };
  }

  Future<void> expectSame(AppDatabase a, AppDatabase b, String storeId) async {
    expect(await snapshot(b, storeId), await snapshot(a, storeId));
    expect(await OutboxRepository(a).pendingCount(), 0);
    expect(await OutboxRepository(b).pendingCount(), 0);
  }

  Future<double> stockOf(AppDatabase db, Item item) async =>
      (await ItemRepository(db).item(item.id))!.quantity;

  test('OR1 — sent on A, received on B: received and stock moved on both',
      () async {
    final a = await newDevice();
    final b = await newDevice();
    final shop = await setUpShop(a, b);

    final order = await sentOrder(a, shop, [
      (shop.water, 24, 0.5),
      (shop.cola, 12, 1),
    ]);
    await sync(a);
    await sync(b);
    expect(
      (await OrderRepository(b).order(order.id))!.status,
      PurchaseOrderStatus.sent,
    );

    await receive(
      b,
      order.id,
      {shop.water.id: 24, shop.cola.id: 12},
      name: 'Karim Test',
    );
    await fullRound(a, b);

    for (final db in [a, b]) {
      expect(
        (await OrderRepository(db).order(order.id))!.status,
        PurchaseOrderStatus.received,
      );
      expect(await stockOf(db, shop.water), 74);
      expect(await stockOf(db, shop.cola), 32);
      final receipts = await OrderRepository(db).receiptsForOrder(order.id);
      expect(receipts.single.receivedByName, 'Karim Test');
      final fromOrder = [
        for (final m in await MovementRepository(
          db,
        ).movementsForStore(shop.store.id))
          if (m.orderId == order.id) m,
      ];
      expect(fromOrder, hasLength(2));
      expect(fromOrder.map((m) => m.receiptId).toSet(), {receipts.single.id});
    }
    await expectSame(a, b, shop.store.id);
  });

  test('OR1 — a new price on the delivery reaches the other tablet', () async {
    final a = await newDevice();
    final b = await newDevice();
    final shop = await setUpShop(a, b);
    final order = await sentOrder(a, shop, [(shop.water, 10, 0.5)]);
    await sync(a);
    await sync(b);

    await receive(b, order.id, {shop.water.id: 10}, prices: {shop.water.id: 0.8});
    await fullRound(a, b);

    for (final db in [a, b]) {
      final price = await SupplierRepository(
        db,
      ).priceFor(shop.water.id, shop.supplier.id);
      expect(price!.pricePerUnit, 0.8);
    }
    await expectSame(a, b, shop.store.id);
  });

  test('OR2 — partial delivery on B, closed short on A: the gap is kept',
      () async {
    final a = await newDevice();
    final b = await newDevice();
    final shop = await setUpShop(a, b);
    final order = await sentOrder(a, shop, [(shop.water, 24, 0.5)]);
    await sync(a);
    await sync(b);

    await receive(b, order.id, {shop.water.id: 20});
    await sync(b);
    await sync(a);
    final partial = (await OrderRepository(a).order(order.id))!;
    expect(partial.status, PurchaseOrderStatus.partial);
    expect(partial.lines.single.quantityReceived, 20);

    await OrderRepository(a).closeShort(order.id);
    await fullRound(a, b);

    for (final db in [a, b]) {
      final closed = (await OrderRepository(db).order(order.id))!;
      expect(closed.status, PurchaseOrderStatus.received);
      expect(closed.lines.single.quantityOrdered, 24);
      expect(closed.lines.single.quantityReceived, 20);
      expect(closed.lines.single.closedShort, isTrue);
      expect(await stockOf(db, shop.water), 70);
    }
    await expectSame(a, b, shop.store.id);
  });

  test('OR3 — received on both tablets offline: both receipts and all the '
      'stock are kept, the same on both', () async {
    final a = await newDevice();
    final b = await newDevice();
    final shop = await setUpShop(a, b);
    final order = await sentOrder(a, shop, [(shop.cola, 12, 1)]);
    await sync(a);
    await sync(b);

    // Both offline: each one receives the whole delivery.
    await receive(a, order.id, {shop.cola.id: 12});
    await receive(b, order.id, {shop.cola.id: 12});
    await fullRound(a, b);

    for (final db in [a, b]) {
      expect(
        (await OrderRepository(db).order(order.id))!.status,
        PurchaseOrderStatus.received,
      );
      expect(await OrderRepository(db).receiptsForOrder(order.id), hasLength(2));
      // Every movement counts: a receipt is never lost.
      expect(await stockOf(db, shop.cola), 44);
    }
    expect(await SyncErrorRepository(b).all(), isEmpty);
    await expectSame(a, b, shop.store.id);
  });

  test('OR4 — cancelled on A, received on B offline: the cancel stays, B '
      'is told, and both tablets agree', () async {
    final a = await newDevice();
    final b = await newDevice();
    final shop = await setUpShop(a, b);
    final order = await sentOrder(a, shop, [(shop.water, 24, 0.5)]);
    await sync(a);
    await sync(b);

    // A, online, cancels; B, offline, still sees it sent and receives it.
    await OrderRepository(a).cancel(order.id);
    await sync(a);
    await receive(b, order.id, {shop.water.id: 24});
    await sync(b);
    await sync(a);

    for (final db in [a, b]) {
      expect(
        (await OrderRepository(db).order(order.id))!.status,
        PurchaseOrderStatus.cancelled,
      );
    }
    final refused = await SyncErrorRepository(b).all();
    expect(
      [for (final e in refused) (e.changedTable, e.reason)],
      [('purchase_orders', 'status_closed')],
    );
    // The goods did come through B's door: the receipt and its stock stay,
    // and A has them too.
    expect(await stockOf(b, shop.water), 74);
    expect(await stockOf(a, shop.water), 74);
    await expectSame(a, b, shop.store.id);
  });

  test('OR4 — a received commande cannot go back to sent', () async {
    final a = await newDevice();
    final b = await newDevice();
    final shop = await setUpShop(a, b);
    final order = await sentOrder(a, shop, [(shop.water, 10, 0.5)]);
    await sync(a);
    await sync(b);

    await receive(a, order.id, {shop.water.id: 10});
    await sync(a);
    // B, still at "sent", partly receives: its row says partial.
    await receive(b, order.id, {shop.water.id: 4});
    await fullRound(a, b);

    for (final db in [a, b]) {
      expect(
        (await OrderRepository(db).order(order.id))!.status,
        PurchaseOrderStatus.received,
      );
      expect(await stockOf(db, shop.water), 64);
    }
    expect(
      [for (final e in await SyncErrorRepository(b).all()) e.reason],
      ['status_closed'],
    );
    await expectSame(a, b, shop.store.id);
  });

  test('a draft deleted on A and edited on B: the delete wins', () async {
    final a = await newDevice();
    final b = await newDevice();
    final shop = await setUpShop(a, b);
    final draft = await OrderRepository(a).createDraft(
      storeId: shop.store.id,
      supplierId: shop.supplier.id,
      lines: [
        PurchaseOrderLine(
          id: '',
          itemId: shop.water.id,
          quantityOrdered: 6,
          unitPrice: 0.5,
        ),
      ],
    );
    await sync(a);
    await sync(b);

    // Both offline.
    expect(await OrderRepository(a).deleteDraft(draft.id), isTrue);
    await OrderRepository(b).updateDraft(
      draft.id,
      note: 'Livraison mardi',
      lines: [
        PurchaseOrderLine(
          id: '',
          itemId: shop.cola.id,
          quantityOrdered: 12,
          unitPrice: 1,
        ),
      ],
    );
    await fullRound(a, b);

    for (final db in [a, b]) {
      expect(await OrderRepository(db).order(draft.id), isNull);
      expect(await OrderRepository(db).orders(shop.store.id), isEmpty);
    }
    expect(
      [
        for (final e in await SyncErrorRepository(b).all())
          if (e.changedTable == 'purchase_orders') e.reason,
      ],
      ['deleted'],
    );
    await expectSame(a, b, shop.store.id);
  });

  test('two drafts made offline on both tablets are both kept', () async {
    final a = await newDevice();
    final b = await newDevice();
    final shop = await setUpShop(a, b);

    await sentOrder(a, shop, [(shop.water, 6, 0.5)]);
    await sentOrder(b, shop, [(shop.cola, 6, 1)]);
    await fullRound(a, b);

    for (final db in [a, b]) {
      expect(await OrderRepository(db).orders(shop.store.id), hasLength(2));
    }
    await expectSame(a, b, shop.store.id);
  });

  test('two commandes made offline on two tablets get different references: '
      'T1 and T2', () async {
    final a = await newDevice();
    final b = await newDevice();
    final shop = await setUpShop(a, b);

    await sentOrder(a, shop, [(shop.water, 6, 0.5)]);
    await sentOrder(b, shop, [(shop.cola, 6, 1)]);
    await fullRound(a, b);

    final year = DateTime.now().year;
    for (final db in [a, b]) {
      expect(
        {
          for (final o in await OrderRepository(db).orders(shop.store.id))
            o.reference,
        },
        {'CMD-$year-T1-001', 'CMD-$year-T2-001'},
      );
    }
  });

  test('a tablet registered before numbers existed learns its number at its '
      'next sync', () async {
    final a = await newDevice();
    final store = await StoreRepository(a).createStore(
      name: 'Brasserie',
      addressLine: '',
      postalCode: '',
      city: 'Namur',
      phone: '081',
    );
    final supplier = await SupplierRepository(a).create(
      storeId: store.id,
      name: 'Grossiste Test',
      contactName: '',
      email: '',
      phone: '',
      addressLine: '',
      postalCode: '',
      city: '',
    );
    Future<String> newReference() async => (await OrderRepository(a)
        .createDraft(storeId: store.id, supplierId: supplier.id, lines: []))
        .reference;

    // Registered, but its number was never stored: the device id's code.
    expect(await DeviceRepository(a).number(), isNull);
    final code = (await DeviceRepository(a).deviceId())
        .substring(0, 4)
        .toUpperCase();
    final year = DateTime.now().year;
    expect(await newReference(), 'CMD-$year-$code-001');

    await sync(a);

    expect(await DeviceRepository(a).number(), 1);
    expect(await newReference(), 'CMD-$year-T1-002');
    // Asking again did not make a second device on the server.
    expect(server.registeredDevices.values.single.number, 1);
  });
}
