// Stock and cost rebuilt from the movement log (SYNC_PLAN.md, Phase 1,
// steps 7 and 8).
//
// An article's quantity and average cost are derived figures: its baseline
// plus every movement not in that baseline, replayed oldest first. The
// movement repository keeps them current one movement at a time; the ledger
// recomputes them from scratch, which is what a device will do once movements
// start arriving from other devices.
//
// "Another device" here is a movement row inserted directly, the way Phase 6
// will write rows received from the server: no repository, no live update of
// the article.

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/mappers/mappers.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart'
    show CategoryIds, ItemIds, StoreIds, UnitIds;
import 'package:stock_inventory/models/models.dart';

import '../support/db_fixture.dart';

void main() {
  late AppDatabase db;
  late ItemRepository items;
  late MovementRepository movements;
  late StockLedger ledger;

  setUp(() async {
    db = await openSeededDatabase();
    items = ItemRepository(db);
    movements = MovementRepository(db);
    ledger = StockLedger(db);
  });

  /// A fresh article, created on 1 August so its opening balance comes before
  /// every dated movement below.
  Future<Item> newItem({double quantity = 0, double? openingUnitCost}) async =>
      (await withClock<Future<Item?>>(
        Clock.fixed(DateTime(2026, 8, 1)),
        () => items.create(
          storeId: StoreIds.sablon,
          name: 'Article de test',
          categoryId: CategoryIds.epicerie,
          unitId: UnitIds.kg,
          lowStockThreshold: 1,
          quantity: quantity,
          openingUnitCost: openingUnitCost,
        ),
      ))!;

  Future<ItemRow> itemRow(String id) =>
      (db.select(db.items)..where((i) => i.id.equals(id))).getSingle();

  Future<List<StockMovementRow>> movementRows(String itemId) =>
      (db.select(db.stockMovements)
            ..where((m) => m.itemId.equals(itemId))
            ..orderBy([
              (m) => OrderingTerm(expression: m.occurredAt),
              (m) => OrderingTerm(expression: m.id),
            ]))
          .get();

  /// A movement recorded on another device and received as-is.
  Future<void> fromAnotherDevice(StockMovement movement) =>
      db.into(db.stockMovements).insert(movementToRow(movement));

  /// Overwrites the article's figures, as if they had drifted.
  Future<void> scramble(String itemId) => (db.update(
    db.items,
  )..where((i) => i.id.equals(itemId))).write(
    const ItemsCompanion(quantity: Value(-999), averageCost: Value(123)),
  );

  test('the demo dataset is already consistent', () async {
    for (final store in await StoreRepository(db).stores()) {
      expect(
        await ledger.rebuildStore(store.id),
        isEmpty,
        reason: 'rebuilding ${store.name} changed something',
      );
    }
  });

  test('the rebuild agrees with the live path, movement by movement', () async {
    final item = await newItem(quantity: 10, openingUnitCost: 2);
    await movements.recordStockIn(
      storeId: StoreIds.sablon,
      itemId: item.id,
      quantity: 5,
      unitPrice: 3,
      occurredAt: DateTime(2026, 9, 1, 8),
    );
    await movements.recordStockOut(
      storeId: StoreIds.sablon,
      itemId: item.id,
      quantity: 4,
      reason: StockOutReason.sale,
      occurredAt: DateTime(2026, 9, 1, 12),
    );
    await movements.recordAdjustment(
      storeId: StoreIds.sablon,
      itemId: item.id,
      systemQuantity: 11,
      countedQuantity: 9,
      occurredAt: DateTime(2026, 9, 1, 18),
    );
    // No price: moves in at what the stock already cost.
    await movements.recordStockIn(
      storeId: StoreIds.sablon,
      itemId: item.id,
      quantity: 6,
      occurredAt: DateTime(2026, 9, 2, 8),
    );
    await movements.recordStockIn(
      storeId: StoreIds.sablon,
      itemId: item.id,
      quantity: 2,
      unitPrice: 4,
      occurredAt: DateTime(2026, 9, 2, 9),
    );

    final live = await itemRow(item.id);
    final liveLog = await movementRows(item.id);
    expect(live.quantity, 17);

    // Nothing to do on a log the live path wrote in order.
    expect(await ledger.rebuildItem(item.id), isFalse);

    await scramble(item.id);
    expect(await ledger.rebuildItem(item.id), isTrue);

    final rebuilt = await itemRow(item.id);
    expect(rebuilt.quantity, closeTo(live.quantity, 1e-9));
    expect(rebuilt.averageCost, closeTo(live.averageCost!, 1e-9));
    final rebuiltLog = await movementRows(item.id);
    for (final (index, row) in rebuiltLog.indexed) {
      expect(row.quantity, liveLog[index].quantity);
      expect(row.unitCost, liveLog[index].unitCost);
      expect(row.averageCostAfter, liveLog[index].averageCostAfter);
    }
  });

  test('a seeded article keeps its figures through live movements', () async {
    await movements.recordStockIn(
      storeId: StoreIds.sablon,
      itemId: ItemIds.tomates,
      quantity: 8,
      unitPrice: 2.4,
    );
    await movements.recordStockOut(
      storeId: StoreIds.sablon,
      itemId: ItemIds.tomates,
      quantity: 3,
      reason: StockOutReason.waste,
    );
    final live = await itemRow(ItemIds.tomates);

    await scramble(ItemIds.tomates);
    await ledger.rebuildItem(ItemIds.tomates);

    final rebuilt = await itemRow(ItemIds.tomates);
    expect(rebuilt.quantity, closeTo(live.quantity, 1e-9));
    expect(rebuilt.averageCost, closeTo(live.averageCost!, 1e-9));
  });

  test('deleted movements do not count', () async {
    final item = await newItem(quantity: 4, openingUnitCost: 1);
    final stockIn = await movements.recordStockIn(
      storeId: StoreIds.sablon,
      itemId: item.id,
      quantity: 6,
      unitPrice: 1,
    );
    await (db.update(db.stockMovements)
          ..where((m) => m.id.equals(stockIn.id)))
        .write(StockMovementsCompanion(deletedAt: Value(DateTime.now())));

    await ledger.rebuildItem(item.id);
    expect((await itemRow(item.id)).quantity, 4);
  });

  group('movements from two devices', () {
    test('two deliveries of 5 kg make 10 kg, whatever the arrival order',
        () async {
      final item = await newItem();

      // This tablet records its delivery.
      await movements.recordStockIn(
        storeId: StoreIds.sablon,
        itemId: item.id,
        quantity: 5,
        unitPrice: 2,
        occurredAt: DateTime(2026, 9, 1, 10),
      );
      // The other tablet's delivery arrives later but happened earlier.
      await fromAnotherDevice(
        StockMovement(
          id: 'other-device-in',
          storeId: StoreIds.sablon,
          itemId: item.id,
          type: StockMovementType.stockIn,
          quantity: 5,
          unitPrice: 4,
          occurredAt: DateTime(2026, 9, 1, 9),
          userName: 'Autre tablette',
        ),
      );
      expect((await itemRow(item.id)).quantity, 5, reason: 'not replayed yet');

      await ledger.rebuildItem(item.id);

      final rebuilt = await itemRow(item.id);
      expect(rebuilt.quantity, 10);
      // In the order they happened: 5 at 4, then 5 at 2, averaging 3.
      expect(rebuilt.averageCost, closeTo(3, 1e-9));
      final log = await movementRows(item.id);
      expect(log.map((m) => m.averageCostAfter), [4, closeTo(3, 1e-9)]);
    });

    test('stock out on another tablet before a count is not taken twice',
        () async {
      final item = await newItem(quantity: 12, openingUnitCost: 1);

      // This tablet counts 10 at 18:00, believing there were 12.
      await movements.recordAdjustment(
        storeId: StoreIds.sablon,
        itemId: item.id,
        systemQuantity: 12,
        countedQuantity: 10,
        occurredAt: DateTime(2026, 9, 1, 18),
      );
      // The other tablet took 3 out at 17:00, before the count.
      await fromAnotherDevice(
        StockMovement(
          id: 'other-device-out-before',
          storeId: StoreIds.sablon,
          itemId: item.id,
          type: StockMovementType.stockOut,
          quantity: -3,
          reason: StockOutReason.sale,
          occurredAt: DateTime(2026, 9, 1, 17),
          userName: 'Autre tablette',
        ),
      );

      await ledger.rebuildItem(item.id);

      // The count saw the shelf after the 3 left: 10 is what is there.
      expect((await itemRow(item.id)).quantity, 10);
      final count = (await movementRows(
        item.id,
      )).lastWhere((m) => m.type == StockMovementType.adjustment);
      expect(count.systemQuantity, 9, reason: 'what the history now says');
      expect(count.quantity, 1);
      expect(count.countedQuantity, 10, reason: 'what was seen never changes');
    });

    test('stock out on another tablet after a count comes off the count',
        () async {
      final item = await newItem(quantity: 12, openingUnitCost: 1);

      await movements.recordAdjustment(
        storeId: StoreIds.sablon,
        itemId: item.id,
        systemQuantity: 12,
        countedQuantity: 10,
        occurredAt: DateTime(2026, 9, 1, 18),
      );
      await fromAnotherDevice(
        StockMovement(
          id: 'other-device-out-after',
          storeId: StoreIds.sablon,
          itemId: item.id,
          type: StockMovementType.stockOut,
          quantity: -3,
          reason: StockOutReason.sale,
          occurredAt: DateTime(2026, 9, 1, 19),
          userName: 'Autre tablette',
        ),
      );

      await ledger.rebuildItem(item.id);
      expect((await itemRow(item.id)).quantity, 7);
    });
  });
}
