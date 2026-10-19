// A real service day on three tablets (MANUAL_TESTS_MULTI_TABLET_SYNC.md,
// part 11).
//
// Three devices of one restaurant share one fake server. They go offline,
// each works like a real service — stock outs, a delivery, a new article, a
// price change, a count, clock-ins and departures — then they reconnect. In
// the end the three databases must hold exactly the same thing, and no
// movement or worked hour may be lost, whatever order they reconnect in.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/models/models.dart';
import 'package:stock_inventory/services/sync_service.dart';

import '../support/db_fixture.dart';
import '../support/fake_account_backend.dart';

typedef Shop = ({
  Store store,
  Supplier supplier,
  Category category,
  UnitOfMeasure unit,
  Item water,
  Item cola,
  Employee owner,
  Employee karim,
  Employee sara,
  PurchaseOrder order,
});

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

  final today = DateTime.now();
  DateTime at(int hour, int minute) =>
      DateTime(today.year, today.month, today.day, hour, minute);

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

  /// The morning, online on A, then everyone gets it: a store, a supplier,
  /// water (50) and cola (20), two employees, a sent commande of 10 water, and
  /// Karim clocked in at 09:00.
  Future<Shop> morning(List<AppDatabase> devices) async {
    final a = devices.first;
    final store = await StoreRepository(a).createStore(
      name: 'Brasserie',
      addressLine: '',
      postalCode: '',
      city: 'Namur',
      phone: '081',
    );
    Future<Employee> employee(String first, String pin, EmployeeRole role) async =>
        (await EmployeeRepository(a).create(
          storeId: store.id,
          firstName: first,
          lastName: 'Test',
          pin: pin,
          phone: '081',
          email: '${first.toLowerCase()}@resto.be',
          role: role,
          pay: 15,
        ))!;
    final owner = await employee('Léa', 'PIN-LEA', EmployeeRole.owner);
    final karim = await employee('Karim', 'PIN-KARIM', EmployeeRole.staff);
    final sara = await employee('Sara', 'PIN-SARA', EmployeeRole.staff);
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
    final orders = OrderRepository(a);
    final draft = await orders.createDraft(
      storeId: store.id,
      supplierId: supplier.id,
      lines: [
        PurchaseOrderLine(
          id: '',
          itemId: water.id,
          quantityOrdered: 10,
          unitPrice: 0.5,
        ),
      ],
    );
    final order = (await orders.send(draft.id))!;
    await AttendanceRepository(a).clockIn(karim.id, store.id, now: at(9, 0));

    for (final db in devices) {
      await sync(db);
    }
    return (
      store: store,
      supplier: supplier,
      category: category,
      unit: unit,
      water: water,
      cola: cola,
      owner: owner,
      karim: karim,
      sara: sara,
      order: order,
    );
  }

  /// The service, every tablet offline. A: the bar. B: the kitchen. C: the
  /// office.
  Future<void> service(Shop shop, AppDatabase a, AppDatabase b, AppDatabase c) async {
    final store = shop.store.id;

    // A — the bar: sells water, receives the commande, adds an article.
    await MovementRepository(a).recordStockOut(
      storeId: store,
      itemId: shop.water.id,
      quantity: 5,
      reason: StockOutReason.sale,
    );
    await OrderRepository(a).confirmReceipt(
      orderId: shop.order.id,
      receivedByName: 'Léa Test',
      lines: [
        ReceiptDraftLine(
          itemId: shop.water.id,
          quantityOrdered: 10,
          quantityReceived: 10,
          orderedUnitPrice: 0.5,
          actualUnitPrice: 0.6,
        ),
      ],
    );
    await ItemRepository(a).create(
      storeId: store,
      name: 'Citron',
      categoryId: shop.category.id,
      unitId: shop.unit.id,
      lowStockThreshold: 2,
      quantity: 8,
      openingUnitCost: 0.3,
    );

    // B — the kitchen: uses water and cola, Karim leaves at 17:00, Sara
    // arrives at 11:00.
    await MovementRepository(b).recordStockOut(
      storeId: store,
      itemId: shop.water.id,
      quantity: 3,
      reason: StockOutReason.waste,
    );
    await MovementRepository(b).recordStockOut(
      storeId: store,
      itemId: shop.cola.id,
      quantity: 2,
      reason: StockOutReason.sale,
    );
    final karimsDay = (await AttendanceRepository(
      b,
    ).forEmployee(shop.karim.id)).single;
    await AttendanceRepository(b).clockOut(karimsDay.id, now: at(17, 0));
    await AttendanceRepository(
      b,
    ).clockIn(shop.sara.id, store, now: at(11, 0));

    // C — the office: a manual delivery of water, a new cola price, and a
    // count of the cola.
    await MovementRepository(c).recordStockIn(
      storeId: store,
      itemId: shop.water.id,
      quantity: 12,
      supplierId: shop.supplier.id,
      unitPrice: 0.5,
    );
    final colaPrice = (await SupplierRepository(
      c,
    ).priceFor(shop.cola.id, shop.supplier.id))!;
    await SupplierRepository(
      c,
    ).updatePrice(colaPrice.id, 1.2, changedByName: 'Léa Test');
    final colaOnC = (await ItemRepository(c).item(shop.cola.id))!;
    await MovementRepository(c).recordAdjustment(
      storeId: store,
      itemId: shop.cola.id,
      systemQuantity: colaOnC.quantity,
      countedQuantity: 19,
    );
  }

  /// Everything a person would compare between tablets for one store.
  Future<Map<String, Object?>> snapshot(AppDatabase db, Shop shop) async {
    final storeId = shop.store.id;
    final orders = OrderRepository(db);
    final suppliers = SupplierRepository(db);
    return {
      'items': {
        for (final item in await ItemRepository(db).items(storeId))
          item.id: (
            item.name,
            item.quantity,
            item.averageCost?.toStringAsFixed(6),
            (await suppliers.priceFor(item.id, shop.supplier.id))?.pricePerUnit,
          ),
      },
      'movements': [
        for (final m in await MovementRepository(db).movementsForStore(storeId))
          '${m.id} ${m.quantity}',
      ]..sort(),
      'orders': {
        for (final order in await orders.orders(storeId))
          // Records compare lists by identity, so the lines go in as text.
          order.id:
              '${order.status.name} '
              '${[for (final l in order.lines) l.quantityReceived]} '
              '${(await orders.receiptsForOrder(order.id)).length} receipt(s)',
      },
      'attendance': {
        for (final employee in [shop.karim, shop.sara])
          employee.firstName: [
            for (final day in await AttendanceRepository(
              db,
            ).forEmployee(employee.id))
              '${day.date} ${day.status.name} '
                  '${[for (final s in day.sessions) '${s.clockInAt.toUtc()}–${s.clockOutAt?.toUtc()}']}',
          ],
      },
    };
  }

  Future<void> expectAllSame(List<AppDatabase> devices, Shop shop) async {
    final first = await snapshot(devices.first, shop);
    for (final (index, db) in devices.indexed.skip(1)) {
      expect(
        await snapshot(db, shop),
        first,
        reason: 'tablet ${'ABC'[index]} differs from tablet A',
      );
    }
    for (final db in devices) {
      expect(await OutboxRepository(db).pendingCount(), 0);
    }
  }

  /// What must be true after the day, whoever synced first.
  Future<void> expectTheDay(AppDatabase db, Shop shop) async {
    final items = {
      for (final item in await ItemRepository(db).items(shop.store.id))
        item.name: item,
    };
    // 50 − 5 sold − 3 wasted + 10 received + 12 delivered.
    expect(items['Eau']!.quantity, 64);
    expect(items['Citron']!.quantity, 8);
    expect(
      (await OrderRepository(db).order(shop.order.id))!.status,
      PurchaseOrderStatus.received,
    );
    expect(
      (await SupplierRepository(
        db,
      ).priceFor(shop.cola.id, shop.supplier.id))!.pricePerUnit,
      1.2,
    );
    // Karim worked 09:00 → 17:00; Sara is still in.
    final karim = (await AttendanceRepository(
      db,
    ).forEmployee(shop.karim.id)).single;
    expect(karim.status, AttendanceStatus.done);
    expect(karim.sessions.single.clockOutAt, at(17, 0));
    final sara = (await AttendanceRepository(
      db,
    ).forEmployee(shop.sara.id)).single;
    expect(sara.status, AttendanceStatus.working);
    // Every movement of the day is there: 3 stock outs, 1 receipt and
    // 1 delivery in, and 4 adjustments (the opening stock of water, cola and
    // Citron, and C's count).
    final movements = await MovementRepository(
      db,
    ).movementsForStore(shop.store.id);
    expect(
      movements.where((m) => m.type == StockMovementType.stockOut),
      hasLength(3),
    );
    expect(
      movements.where((m) => m.type == StockMovementType.stockIn),
      hasLength(2),
    );
    expect(
      movements.where((m) => m.type == StockMovementType.adjustment),
      hasLength(4),
    );
  }

  test('three tablets offline all day, back C, A, B: all three agree and '
      'nothing is lost', () async {
    final a = await newDevice();
    final b = await newDevice();
    final c = await newDevice();
    final devices = [a, b, c];
    final shop = await morning(devices);

    await service(shop, a, b, c);
    for (final db in [c, a, b, c, a, b]) {
      await sync(db);
    }

    for (final db in devices) {
      await expectTheDay(db, shop);
    }
    await expectAllSame(devices, shop);
  });

  test('the same day, reconnected in 25 random orders: always the same '
      'result on every tablet', () async {
    for (var seed = 1; seed <= 25; seed++) {
      server = FakeAccountBackend();
      organization = server.addOrganization('Brasserie');
      server.addUser(
        'owner@resto.be',
        'motdepasse',
        organizationId: organization,
      );
      await server.signIn(email: 'owner@resto.be', password: 'motdepasse');

      final devices = [await newDevice(), await newDevice(), await newDevice()];
      final shop = await morning(devices);
      await service(shop, devices[0], devices[1], devices[2]);

      // A few syncs in a random order, as tablets come back one by one…
      final random = Random(seed);
      final order = <int>[
        for (var i = 0; i < 2 + random.nextInt(6); i++) random.nextInt(3),
      ];
      for (final i in order) {
        await sync(devices[i]);
      }
      // …then everyone is online and syncs twice.
      for (final db in [...devices, ...devices]) {
        await sync(db);
      }

      final which = 'seed $seed, sync order ${order.map((i) => 'ABC'[i]).join()}';
      for (final db in devices) {
        await expectLater(
          expectTheDay(db, shop),
          completes,
          reason: which,
        );
      }
      final first = await snapshot(devices.first, shop);
      for (final db in devices.skip(1)) {
        expect(await snapshot(db, shop), first, reason: which);
      }
      for (final db in devices) {
        await db.close();
      }
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
