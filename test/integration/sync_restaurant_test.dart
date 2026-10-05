// The restaurant scenarios that matter most, through a running Supabase
// (SYNC_TESTS_PLAN.md, group L). They prove the fake server of
// test/db/sync_restaurant_*_test.dart follows the same rules as the real one.
//
//   supabase start
//   flutter test test/integration/sync_restaurant_test.dart --concurrency=1 \
//     --dart-define-from-file=config/local.json

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock_inventory/core/config/env.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/device_access.dart';
import 'package:stock_inventory/data/employee_photo_store.dart';
import 'package:stock_inventory/data/providers.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/models/models.dart';
import 'package:stock_inventory/services/auth_service.dart';
import 'package:stock_inventory/services/sync_service.dart';

import '../support/db_fixture.dart';
import '../support/restaurant_tablets.dart';

void main() {
  final skip = Env.hasServer
      ? false
      : 'no server: run with --dart-define-from-file=config/local.json';

  late List<Tablet> tablets;
  late String storeId;
  late Category legumes;
  late UnitOfMeasure kg;
  late Supplier metro;
  late Item tomates;

  Future<(AppDatabase, AccountBackend, DeviceAccessController)> device() async {
    final db = openEmptyDatabase();
    final backend = SupabaseAccountBackend(
      SupabaseClient(
        Env.supabaseUrl,
        Env.supabasePublishableKey,
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
          authFlowType: AuthFlowType.implicit,
        ),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        accountBackendProvider.overrideWithValue(backend),
        employeePhotoStoreProvider.overrideWithValue(_NoPhotos()),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() => seedDeviceAccessSnapshot(DeviceAccess.demo));
    final controller = container.read(deviceAccessProvider.notifier);
    await controller.hydrate();
    return (db, backend, controller);
  }

  Tablet tablet(String name) => tablets.firstWhere((t) => t.name == name);

  Future<void> syncAll() async {
    for (var round = 0; round < 4; round++) {
      for (final t in tablets) {
        if (t.isOffline) continue;
        final result = await t.sync();
        expect(result.outcome, SyncOutcome.done, reason: '$t ${result.detail}');
      }
    }
  }

  Future<void> settle() async {
    for (final t in tablets) {
      t.online();
    }
    await syncAll();
    for (final table in comparedTables) {
      final expected = await tableRows(tablets.first.db, table);
      for (final other in tablets.skip(1)) {
        expect(
          await tableRows(other.db, table),
          expected,
          reason: '$table differs on $other',
        );
      }
    }
    for (final t in tablets) {
      expect(await t.waiting(), 0, reason: '$t still waits');
    }
  }

  setUp(() async {
    if (!Env.hasServer) return;
    final run = DateTime.now().microsecondsSinceEpoch;
    final (a, backendA, controllerA) = await device();
    await controllerA.signUp('owner-$run@example.test', 'motdepasse-local');
    final owner = await controllerA.createRestaurant(
      restaurantName: 'Resto $run',
      city: 'Namur',
      phone: '081',
      firstName: 'Léa',
      lastName: 'Martin',
      pin: 'PIN-$run',
      password: '4321',
    );
    storeId = owner.storeId;
    final bureau = Tablet('Bureau', a, TabletLink(backendA, a));
    tablets = [bureau];
    for (final name in ['Cuisine', 'Bar']) {
      final code = await backendA.createJoinCode();
      final (db, backend, controller) = await device();
      await controller.signUp('$name-$run@example.test', 'motdepasse-local');
      await controller.joinWithCode(code);
      tablets.add(Tablet(name, db, TabletLink(backend, db)));
    }

    legumes = (await bureau.catalog.createCategory(
      storeId: storeId,
      name: 'Légumes',
    ))!;
    kg = (await bureau.catalog.createUnit(
      storeId: storeId,
      name: 'Kilogramme',
      abbreviation: 'kg',
    ))!;
    metro = await bureau.suppliers.create(
      storeId: storeId,
      name: 'Metro',
      contactName: '',
      email: '',
      phone: '',
      addressLine: '',
      postalCode: '',
      city: '',
    );
    tomates = (await bureau.items.create(
      storeId: storeId,
      name: 'Tomates',
      categoryId: legumes.id,
      unitId: kg.id,
      lowStockThreshold: 3,
      quantity: 10,
      openingUnitCost: 2,
    ))!;
    await syncAll();
  });

  Future<PurchaseOrder> sentOrder() async {
    final bureau = tablet('Bureau');
    final order = await bureau.orders.createDraft(
      storeId: storeId,
      supplierId: metro.id,
      lines: [
        PurchaseOrderLine(
          id: '',
          itemId: tomates.id,
          quantityOrdered: 10,
          unitPrice: 2,
        ),
      ],
    );
    await bureau.orders.send(order.id);
    await syncAll();
    return order;
  }

  Future<void> receive(Tablet t, PurchaseOrder order, double kg) async {
    final line = (await t.orders.order(order.id))!.lines.single;
    await t.orders.confirmReceipt(
      orderId: order.id,
      receivedByName: t.name,
      lines: [
        ReceiptDraftLine(
          itemId: tomates.id,
          quantityOrdered: line.quantityOrdered - line.quantityReceived,
          quantityReceived: kg,
          orderedUnitPrice: 2,
          actualUnitPrice: 2,
        ),
      ],
    );
  }

  const timeout = Timeout(Duration(minutes: 3));

  test(
    'B1/C2 — three tablets take stock out offline: every one counts',
    () async {
      for (final t in tablets) {
        t.offline();
        await t.movements.recordStockOut(
          storeId: storeId,
          itemId: tomates.id,
          quantity: 2,
          reason: StockOutReason.sale,
        );
      }
      await settle();
      for (final t in tablets) {
        expect(await t.stockOf(tomates.id), 4, reason: '$t');
      }
    },
    skip: skip,
    timeout: timeout,
  );

  test(
    'C1 — two deliveries at once at two prices',
    () async {
      tablet('Cuisine').offline();
      tablet('Bar').offline();
      for (final (name, price) in [('Cuisine', 2.0), ('Bar', 4.0)]) {
        await tablet(name).movements.recordStockIn(
          storeId: storeId,
          itemId: tomates.id,
          quantity: 5,
          unitPrice: price,
        );
      }
      await settle();
      final item = (await tablet('Bureau').items.item(tomates.id))!;
      expect(item.quantity, 20);
      expect(item.averageCost, closeTo(2.5, 1e-9));
    },
    skip: skip,
    timeout: timeout,
  );

  test(
    'D4 — edited offline while deleted elsewhere: delete wins, told',
    () async {
      final bar = tablet('Bar');
      bar.offline();
      expect(await tablet('Bureau').suppliers.delete(metro.id), isTrue);
      await syncAll();
      await bar.suppliers.update(metro.id, phone: '0470');
      await settle();
      expect(await bar.suppliers.supplier(metro.id), isNull);
      expect([
        for (final e in await bar.toCheck()) e.reason,
      ], contains('deleted'));
    },
    skip: skip,
    timeout: timeout,
  );

  test(
    'E4 — a draft changed offline after it was sent: refused as going '
    'backwards',
    () async {
      final bureau = tablet('Bureau');
      final order = await bureau.orders.createDraft(
        storeId: storeId,
        supplierId: metro.id,
        lines: [
          PurchaseOrderLine(
            id: '',
            itemId: tomates.id,
            quantityOrdered: 3,
            unitPrice: 2,
          ),
        ],
      );
      await syncAll();
      tablet('Bar').offline();
      await bureau.orders.send(order.id);
      await syncAll();
      await tablet('Bar').orders.updateDraft(order.id, note: 'Urgent');
      await settle();
      expect(
        (await tablet('Bar').orders.order(order.id))!.status,
        PurchaseOrderStatus.sent,
      );
      expect([
        for (final e in await tablet('Bar').toCheck()) e.reason,
      ], contains('status_backwards'));
    },
    skip: skip,
    timeout: timeout,
  );

  test(
    'E5 — cancelled on one, received offline on another: goods kept, told',
    () async {
      final order = await sentOrder();
      tablet('Cuisine').offline();
      await tablet('Bureau').orders.cancel(order.id);
      await syncAll();
      await receive(tablet('Cuisine'), order, 10);
      await settle();
      expect(await tablet('Bureau').stockOf(tomates.id), 20);
      expect([
        for (final e in await tablet('Cuisine').toCheck()) e.reason,
      ], contains('status_closed'));
    },
    skip: skip,
    timeout: timeout,
  );

  test(
    'E7 — closed short on one, the rest received offline: stays closed',
    () async {
      final order = await sentOrder();
      await receive(tablet('Cuisine'), order, 4);
      await syncAll();
      tablet('Cuisine').offline();
      await tablet('Bureau').orders.closeShort(order.id);
      await syncAll();
      await receive(tablet('Cuisine'), order, 6);
      await settle();
      for (final t in tablets) {
        expect(
          (await t.orders.order(order.id))!.status,
          PurchaseOrderStatus.received,
        );
        expect(await t.stockOf(tomates.id), 20);
      }
    },
    skip: skip,
    timeout: timeout,
  );

  test(
    'E3 — the same delivery confirmed on two tablets offline (F7): the '
    'stock is not changed, every tablet is told once',
    () async {
      final order = await sentOrder();
      tablet('Cuisine').offline();
      tablet('Bar').offline();
      await receive(tablet('Cuisine'), order, 10);
      await receive(tablet('Bar'), order, 10);
      await settle();
      for (final t in tablets) {
        expect(await t.stockOf(tomates.id), 30, reason: '$t');
        final alerts = [
          for (final n in await AccountRepository(t.db).notifications(storeId))
            if (n.title.startsWith('Réception en double')) n,
        ];
        expect(alerts, hasLength(1), reason: '$t');
        expect(
          [for (final e in await t.toCheck()) e.reason],
          contains('resolved_double_receipt'),
          reason: '$t',
        );
      }
    },
    skip: skip,
    timeout: timeout,
  );

  test(
    'E2b — two part deliveries offline (F6): the commande adds both up',
    () async {
      final order = await sentOrder();
      tablet('Cuisine').offline();
      tablet('Bar').offline();
      await receive(tablet('Cuisine'), order, 4);
      await receive(tablet('Bar'), order, 3);
      await settle();
      for (final t in tablets) {
        final line = (await t.orders.order(order.id))!.lines.single;
        expect(line.quantityReceived, 7, reason: '$t');
        expect(await t.stockOf(tomates.id), 17, reason: '$t');
      }
    },
    skip: skip,
    timeout: timeout,
  );
}

class _NoPhotos extends EmployeePhotoStore {
  @override
  Future<void> deleteFor(String employeeId) async {}
}
