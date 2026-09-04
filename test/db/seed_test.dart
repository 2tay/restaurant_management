// Referential integrity and demo coverage, against a seeded database.
//
// The database-side counterpart to `mock_data_test.dart`. The dataset is still
// hand-written across a dozen files and still relates everything by string id, so
// a typo still produces a dash, a blank row, or a crash on a screen nobody opened
// during the demo — the schema catches some of those now, and this suite catches
// the rest.
//
// Which is worth being precise about. Six references in the schema carry **no**
// foreign key, because Phase 1 lets them dangle by design: a movement keeps a
// deleted supplier's id, a completed commande keeps a line naming a deleted
// article. That is right for data the app produces, and it means nothing stops
// the *seed* from shipping one of those broken. So the loose references get a
// group of their own here — they are exactly the ones the database will not
// check for us.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/core/utils/stock_status.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/database/bootstrap.dart';
import 'package:stock_inventory/data/database/meta_keys.dart';
import 'package:stock_inventory/data/mappers/mappers.dart';
import 'package:stock_inventory/data/repositories/demo_repository.dart';
import 'package:stock_inventory/data/repositories/new_id.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/data/seed/demo_seed.dart';
import 'package:stock_inventory/models/models.dart';

import '../support/db_fixture.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await openSeededDatabase();
  });

  Future<Set<String>> idsOf(String table, [String column = 'id']) async {
    final rows = await db.customSelect('SELECT $column FROM $table').get();
    return rows.map((row) => row.read<String>(column)).toSet();
  }

  Future<List<Item>> itemsForStore(String storeId) async {
    final rows = await (db.select(
      db.items,
    )..where((i) => i.storeId.equals(storeId))).get();
    return rows.map(itemFromRow).toList();
  }

  group('references the schema does not enforce', () {
    // Each of these would throw on insert if the column carried a foreign key.
    // None of them do, for reasons written down in the table definitions. So the
    // seed is checked here instead.

    test('every delivery names a supplier that exists', () async {
      final supplierIds = await idsOf('suppliers');
      final deliveries = await (db.select(db.stockMovements)
            ..where((m) => m.type.equalsValue(StockMovementType.stockIn)))
          .get();

      expect(deliveries, isNotEmpty);
      for (final movement in deliveries) {
        expect(
          supplierIds,
          contains(movement.supplierId),
          reason: '${movement.id} is a delivery with no valid supplier',
        );
      }
    });

    test('every commande names a supplier that exists', () async {
      final supplierIds = await idsOf('suppliers');
      final orders = await db.select(db.purchaseOrders).get();

      expect(orders, isNotEmpty);
      for (final order in orders) {
        expect(
          supplierIds,
          contains(order.supplierId),
          reason: order.reference,
        );
      }
    });

    test('every commande and receipt line names an article that exists',
        () async {
      final itemIds = await idsOf('items');

      for (final line in await db.select(db.purchaseOrderLines).get()) {
        expect(itemIds, contains(line.itemId), reason: 'order line ${line.id}');
      }
      for (final line in await db.select(db.goodsReceiptLines).get()) {
        expect(
          itemIds,
          contains(line.itemId),
          reason: 'receipt line ${line.id}',
        );
      }
    });

    test('every default supplier on an article exists', () async {
      final supplierIds = await idsOf('suppliers');
      final items = await db.select(db.items).get();

      for (final item in items.where((i) => i.defaultSupplierId != null)) {
        expect(
          supplierIds,
          contains(item.defaultSupplierId),
          reason: item.name,
        );
      }
    });

    test('every notification points at something that exists', () async {
      final itemIds = await idsOf('items');
      final supplierIds = await idsOf('suppliers');

      for (final notification in await db.select(db.notifications).get()) {
        if (notification.relatedItemId != null) {
          expect(itemIds, contains(notification.relatedItemId));
        }
        if (notification.relatedSupplierId != null) {
          expect(supplierIds, contains(notification.relatedSupplierId));
        }
      }
    });
  });

  group('referential integrity', () {
    test('an article uses its own store\'s category and unit', () async {
      // Not implied by the foreign keys: those only say the category exists, not
      // that it belongs to the same establishment. Getting this wrong shows an
      // article filed under another restaurant's category.
      final rows = await db
          .customSelect(
            'SELECT i.name AS name FROM items i '
            'JOIN categories c ON c.id = i.category_id '
            'JOIN units u ON u.id = i.unit_id '
            'WHERE c.store_id != i.store_id OR u.store_id != i.store_id',
          )
          .get();

      expect(
        rows.map((r) => r.read<String>('name')),
        isEmpty,
        reason: 'these articles borrow another store\'s catalogue',
      );
    });

    test('every price history entry has a matching current price', () async {
      final rows = await db
          .customSelect(
            'SELECT h.id AS id FROM price_history h '
            'LEFT JOIN supplier_prices p '
            '  ON p.item_id = h.item_id AND p.supplier_id = h.supplier_id '
            'WHERE p.id IS NULL',
          )
          .get();

      expect(
        rows.map((r) => r.read<String>('id')),
        isEmpty,
        reason: 'history but no current price',
      );
    });

    test('every article is priced by at least one supplier', () async {
      final rows = await db
          .customSelect(
            'SELECT i.name AS name FROM items i '
            'LEFT JOIN supplier_prices p ON p.item_id = i.id '
            'WHERE p.id IS NULL',
          )
          .get();

      expect(
        rows.map((r) => r.read<String>('name')),
        isEmpty,
        reason: 'an article with no supplier price cannot be valued',
      );
    });

    test('an article has at most one default supplier', () async {
      final rows = await db
          .customSelect(
            'SELECT item_id AS item_id, COUNT(*) AS n FROM supplier_prices '
            'WHERE is_default = 1 GROUP BY item_id HAVING n > 1',
          )
          .get();

      expect(rows.map((r) => r.read<String>('item_id')), isEmpty);
    });
  });

  group('movement field usage matches its type', () {
    test('deliveries carry a price, usage carries a reason', () async {
      final movements = await db.select(db.stockMovements).get();
      expect(movements, isNotEmpty);

      for (final movement in movements) {
        switch (movement.type) {
          case StockMovementType.stockIn:
            expect(movement.unitPrice, isNotNull, reason: movement.id);
            expect(movement.quantity, greaterThan(0), reason: movement.id);
          case StockMovementType.stockOut:
            expect(movement.reason, isNotNull, reason: movement.id);
            expect(movement.quantity, lessThan(0), reason: movement.id);
          case StockMovementType.adjustment:
            expect(movement.systemQuantity, isNotNull, reason: movement.id);
            expect(movement.countedQuantity, isNotNull, reason: movement.id);
        }
      }
    });
  });

  group('the dataset demos what it needs to', () {
    test('all three stock statuses appear in the flagship store', () async {
      final statuses = (await itemsForStore(
        StoreIds.sablon,
      )).map(stockStatusOf).toSet();

      expect(statuses, containsAll(StockStatus.values));
    });

    test('the new store is empty, so empty states can be demoed', () async {
      expect(await itemsForStore(StoreIds.saintGilles), isEmpty);
    });

    test('at least one article has three competing suppliers', () async {
      final rows = await db
          .customSelect(
            'SELECT item_id AS item_id FROM supplier_prices '
            'GROUP BY item_id HAVING COUNT(*) >= 3',
          )
          .get();

      expect(rows, isNotEmpty);
    });

    test('at least one article pays a default that is not the cheapest',
        () async {
      // Without this the price comparison report opens on nothing to say, and it
      // is the feature the app is sold on.
      final rows = await db
          .customSelect(
            'SELECT d.item_id AS item_id FROM supplier_prices d '
            'WHERE d.is_default = 1 AND d.price_per_unit > '
            '  (SELECT MIN(p.price_per_unit) FROM supplier_prices p '
            '   WHERE p.item_id = d.item_id)',
          )
          .get();

      expect(rows, isNotEmpty);
    });

    test('stores hold different inventories, proving scoping is visible',
        () async {
      final sablon = await itemsForStore(StoreIds.sablon);
      final liege = await itemsForStore(StoreIds.liege);

      expect(sablon, isNotEmpty);
      expect(liege, isNotEmpty);
      expect(sablon.length, isNot(liege.length));
    });

    test('the seed matches the dataset it was built from', () async {
      // A crude but effective guard on the seed itself: if a mock list grows and
      // the seed is not updated to insert it, the counts diverge.
      expect(await db.select(db.stores).get(), hasLength(mockStores.length));
      expect(await db.select(db.items).get(), hasLength(mockItems.length));
      expect(
        await db.select(db.supplierPrices).get(),
        hasLength(mockSupplierPrices.length),
      );
      expect(
        await db.select(db.stockMovements).get(),
        hasLength(mockStockMovements.length),
      );
      expect(
        await db.select(db.purchaseOrders).get(),
        hasLength(mockPurchaseOrders.length),
      );
      expect(
        await db.select(db.purchaseOrderLines).get(),
        hasLength(mockPurchaseOrders.fold<int>(0, (n, o) => n + o.lines.length)),
      );
      expect(
        await db.select(db.goodsReceipts).get(),
        hasLength(mockGoodsReceipts.length),
      );
    });
  });

  group('the timeline is anchored, not frozen', () {
    test('the seed records when it ran', () async {
      final row = await (db.select(
        db.meta,
      )..where((m) => m.key.equals(MetaKeys.seededAt))).getSingle();

      expect(DateTime.parse(row.value), seedInstant);
    });

    test('dates are relative to the anchor, so the demo always looks recent',
        () async {
      // The same dataset seeded a year apart must read the same way: a commande
      // sent three days before the anchor, not three days after some instant
      // frozen when the mock library first loaded.
      final later = await openSeededDatabase(at: DateTime(2027, 5));

      Future<Duration> ageOfNewestMovement(AppDatabase database) async {
        final row = await database
            .customSelect('SELECT MAX(occurred_at) AS newest FROM stock_movements')
            .getSingle();
        return DateTime.parse(row.read<String>('newest')).difference(
          DateTime.parse(
            (await (database.select(database.meta)
                      ..where((m) => m.key.equals(MetaKeys.seededAt)))
                    .getSingle())
                .value,
          ),
        );
      }

      expect(await ageOfNewestMovement(later), await ageOfNewestMovement(db));
    });

    test('seeding twice with the same anchor gives the same dataset', () async {
      final twin = await openSeededDatabase();

      final a = await db.select(db.stockMovements).get();
      final b = await twin.select(twin.stockMovements).get();

      expect(b.map((m) => m.occurredAt), a.map((m) => m.occurredAt));
    });
  });

  group('first launch and reset', () {
    test('an empty database is seeded, and a seeded one is left alone',
        () async {
      final fresh = openEmptyDatabase();

      expect(await seedIfEmpty(fresh), isTrue);
      final seeded = await fresh.select(fresh.items).get();
      expect(seeded, isNotEmpty);

      expect(await seedIfEmpty(fresh), isFalse);
      expect(await fresh.select(fresh.items).get(), hasLength(seeded.length));
    });

    test('clearing empties every table', () async {
      await clearAllData(db);

      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name NOT LIKE 'sqlite_%'",
          )
          .get();

      for (final row in rows) {
        final table = row.read<String>('name');
        final count = await db
            .customSelect('SELECT COUNT(*) AS n FROM "$table"')
            .getSingle();
        expect(count.read<int>('n'), 0, reason: table);
      }
    });

    test('a reset undoes a change rather than only re-counting rows', () async {
      final before = await (db.select(
        db.items,
      )..where((i) => i.storeId.equals(StoreIds.sablon))).get();
      final target = before.first;

      await (db.update(db.items)..where((i) => i.id.equals(target.id))).write(
        ItemsCompanion(quantity: Value(target.quantity + 999)),
      );

      await DemoRepository(db).resetDemo();

      final after = await (db.select(
        db.items,
      )..where((i) => i.id.equals(target.id))).getSingle();
      expect(after.quantity, target.quantity);
    });

    test('a generated id can never collide with a seeded one', () async {
      // The dataset's ids are readable slugs — `item-poulet`, `store-sablon` —
      // and everything created afterwards gets a UUID. Phase 1 generated
      // `item-new-7` from a counter that restarted with the process, which was
      // harmless only while the data restarted with it too. It does not any
      // more, so the two id spaces have to be incapable of meeting.
      final seeded = <String>{
        for (final row in await db.select(db.items).get()) row.id,
        for (final row in await db.select(db.suppliers).get()) row.id,
        for (final row in await db.select(db.categories).get()) row.id,
        for (final row in await db.select(db.units).get()) row.id,
        for (final row in await db.select(db.stores).get()) row.id,
      };

      final generated = <String>{for (var i = 0; i < 500; i++) newId()};

      expect(generated, hasLength(500), reason: 'generated ids repeat');
      expect(generated.intersection(seeded), isEmpty);

      // And they do not merely differ — they are a different shape, which is
      // what makes the guarantee hold for ids this test never saw.
      final uuid = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
        r'[0-9a-f]{12}$',
      );
      expect(generated.every(uuid.hasMatch), isTrue);
      expect(seeded.any(uuid.hasMatch), isFalse);
    });
  });
}
