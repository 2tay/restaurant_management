// Schema version 15: the local database made ready for sync.
//
// SYNC_PLAN.md, Phase 1. Nothing here talks to a network. These tests hold the
// rules the later phases will rely on:
//
//   - every table is either synced or local, and a synced one carries the
//     sync columns and its trigger;
//   - `updated_at` moves on every write without a repository asking;
//   - nothing the app deletes leaves the table, and nothing deleted shows up;
//   - a child row knows its store;
//   - the device has an id that stays put.

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/database/meta_keys.dart';
import 'package:stock_inventory/data/database/sync_tables.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart'
    show CategoryIds, EmployeeIds, ItemIds, StoreIds, SupplierIds, UnitIds;
import 'package:stock_inventory/models/models.dart';

import '../support/db_fixture.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await openSeededDatabase();
  });

  Future<List<String>> columnsOf(String table) async => [
    for (final row in await db.customSelect('PRAGMA table_info($table)').get())
      row.read<String>('name'),
  ];

  /// Rows in [table] with this id, deleted ones included.
  Future<List<QueryRow>> rawRows(String table, String id) => db
      .customSelect(
        'SELECT * FROM $table WHERE id = ?',
        variables: [Variable<String>(id)],
      )
      .get();

  group('synced and local tables', () {
    test('every table is in exactly one list', () {
      final tables = {for (final t in db.allTables) t.actualTableName};

      expect(
        SyncTables.synced.intersection(SyncTables.local),
        isEmpty,
        reason: 'a table cannot be both',
      );
      expect(
        tables.difference(SyncTables.synced.union(SyncTables.local)),
        isEmpty,
        reason: 'a new table must be added to lib/data/database/sync_tables.dart',
      );
      expect(
        SyncTables.synced.union(SyncTables.local).difference(tables),
        isEmpty,
        reason: 'the lists name a table that does not exist',
      );
    });

    test('every synced table has the sync columns and its trigger', () async {
      final triggers = {
        for (final row in await db
            .customSelect("SELECT name FROM sqlite_master WHERE type = 'trigger'")
            .get())
          row.read<String>('name'),
      };

      for (final table in SyncTables.synced) {
        final columns = await columnsOf(table);
        expect(columns, contains('updated_at'), reason: table);
        expect(columns, contains('deleted_at'), reason: table);
        expect(triggers, contains('${table}_touch'), reason: table);
      }
      for (final table in SyncTables.withCopiedStore) {
        expect(await columnsOf(table), contains('store_id'), reason: table);
      }
    });

    test('the local table has none of it', () async {
      expect(await columnsOf('meta'), isNot(contains('updated_at')));
    });
  });

  group('updated_at', () {
    test('an insert is stamped with the clock', () async {
      final at = DateTime(2026, 9, 1, 10, 30);
      final category = await withClock(
        Clock.fixed(at),
        () => CatalogRepository(
          db,
        ).createCategory(storeId: StoreIds.sablon, name: 'Épices'),
      );

      final row = await (db.select(
        db.categories,
      )..where((c) => c.id.equals(category!.id))).getSingle();
      expect(row.updatedAt, at.toUtc());
      expect(row.updatedAt.isUtc, isTrue);
    });

    test('an update moves it without the repository asking', () async {
      final before = await (db.select(
        db.categories,
      )..where((c) => c.id.equals(CategoryIds.legumes))).getSingle();

      await CatalogRepository(
        db,
      ).renameCategory(CategoryIds.legumes, 'Légumes frais');

      final after = await (db.select(
        db.categories,
      )..where((c) => c.id.equals(CategoryIds.legumes))).getSingle();
      expect(after.updatedAt.isAfter(before.updatedAt), isTrue);
      // The trigger writes UTC in the format drift reads back as UTC, and it
      // is the real time rather than something shifted by an offset.
      expect(after.updatedAt.isUtc, isTrue);
      expect(
        after.updatedAt.difference(DateTime.now()).inMinutes.abs(),
        lessThan(2),
      );
    });

    test('a write that sets it keeps its own value', () async {
      final at = DateTime(2026, 8, 30, 9);
      await MovementRepository(db).recordStockIn(
        storeId: StoreIds.sablon,
        itemId: ItemIds.tomates,
        quantity: 5,
        unitPrice: 2,
        occurredAt: at,
      );

      final item = await (db.select(
        db.items,
      )..where((i) => i.id.equals(ItemIds.tomates))).getSingle();
      expect(item.updatedAt, at, reason: 'the movement stamps the article');
    });
  });

  group('soft deletes', () {
    test('a category is kept, marked deleted, and hidden', () async {
      final catalog = CatalogRepository(db);
      final category = (await catalog.createCategory(
        storeId: StoreIds.sablon,
        name: 'Temporaire',
      ))!;

      expect(await catalog.deleteCategory(category.id), isTrue);

      final rows = await rawRows('categories', category.id);
      expect(rows, hasLength(1));
      expect(rows.single.read<String?>('deleted_at'), isNotNull);
      expect(await catalog.category(category.id), isNull);
      expect(
        (await catalog.categories(StoreIds.sablon)).map((c) => c.id),
        isNot(contains(category.id)),
      );
      // The name is free again.
      expect(
        await catalog.createCategory(storeId: StoreIds.sablon, name: 'Temporaire'),
        isNotNull,
      );
    });

    test('deleting an article takes its movements and links with it', () async {
      final items = ItemRepository(db);
      final suppliers = SupplierRepository(db);
      final movements = MovementRepository(db);

      final item = (await items.create(
        storeId: StoreIds.sablon,
        name: 'Safran',
        categoryId: CategoryIds.epicerie,
        unitId: UnitIds.kg,
        lowStockThreshold: 1,
      ))!;
      final link = (await suppliers.linkItem(
        itemId: item.id,
        supplierId: SupplierIds.grossisteCentral,
        pricePerUnit: 10,
      ))!;
      await suppliers.updatePrice(link.id, 12);
      await movements.recordStockIn(
        storeId: StoreIds.sablon,
        itemId: item.id,
        quantity: 2,
        unitPrice: 12,
      );
      final countBefore = await CatalogRepository(
        db,
      ).itemCountInCategory(CategoryIds.epicerie);

      expect(await items.delete(item.id), isTrue);

      expect(await items.item(item.id), isNull);
      expect(await movements.movementsForItem(item.id), isEmpty);
      expect(await suppliers.pricesForItem(item.id), isEmpty);
      expect(
        await suppliers.priceHistoryFor(item.id, SupplierIds.grossisteCentral),
        isEmpty,
      );
      expect(
        await CatalogRepository(db).itemCountInCategory(CategoryIds.epicerie),
        countBefore - 1,
        reason: 'a deleted article no longer counts against its category',
      );

      // Everything is still in the tables, stamped.
      for (final table in ['stock_movements', 'supplier_prices', 'price_history']) {
        final rows = await db
            .customSelect(
              'SELECT deleted_at FROM $table WHERE item_id = ?',
              variables: [Variable<String>(item.id)],
            )
            .get();
        expect(rows, isNotEmpty, reason: table);
        expect(
          rows.every((r) => r.read<String?>('deleted_at') != null),
          isTrue,
          reason: table,
        );
      }
    });

    test('an unlinked supplier can be linked again', () async {
      final suppliers = SupplierRepository(db);
      final item = (await ItemRepository(db).create(
        storeId: StoreIds.sablon,
        name: 'Vanille',
        categoryId: CategoryIds.epicerie,
        unitId: UnitIds.kg,
        lowStockThreshold: 1,
      ))!;

      final first = (await suppliers.linkItem(
        itemId: item.id,
        supplierId: SupplierIds.horecaSelect,
        pricePerUnit: 30,
      ))!;
      expect(await suppliers.unlinkItem(first.id), isTrue);
      expect(await suppliers.pricesForItem(item.id), isEmpty);

      // The pair is unique, deleted rows included, so this must bring the old
      // row back rather than insert a second one.
      final again = await suppliers.linkItem(
        itemId: item.id,
        supplierId: SupplierIds.horecaSelect,
        pricePerUnit: 28,
      );
      expect(again, isNotNull);
      expect(again!.id, first.id);
      final prices = await suppliers.pricesForItem(item.id);
      expect(prices.single.pricePerUnit, 28);
    });

    test('a deleted supplier and its prices disappear', () async {
      final suppliers = SupplierRepository(db);
      final supplier = await suppliers.create(
        storeId: StoreIds.sablon,
        name: 'Fournisseur éphémère',
        contactName: 'X',
        email: 'x@example.be',
        phone: '000',
        addressLine: 'Rue 1',
        postalCode: '1000',
        city: 'Bruxelles',
      );
      await suppliers.linkItem(
        itemId: ItemIds.tomates,
        supplierId: supplier.id,
        pricePerUnit: 99,
      );

      expect(await suppliers.delete(supplier.id), isTrue);
      expect(await suppliers.supplier(supplier.id), isNull);
      expect(
        (await suppliers.pricesForItem(ItemIds.tomates)).map((p) => p.supplierId),
        isNot(contains(supplier.id)),
      );
      expect(await rawRows('suppliers', supplier.id), hasLength(1));
    });

    test('a draft keeps only its current lines, and goes when deleted', () async {
      final orders = OrderRepository(db);
      final draft = await orders.createDraft(
        storeId: StoreIds.sablon,
        supplierId: SupplierIds.grossisteCentral,
        lines: const [
          PurchaseOrderLine(
            id: 'x',
            itemId: ItemIds.tomates,
            quantityOrdered: 4,
            unitPrice: 2,
          ),
        ],
      );

      final edited = await orders.updateDraft(
        draft.id,
        lines: const [
          PurchaseOrderLine(
            id: 'y',
            itemId: ItemIds.oignons,
            quantityOrdered: 3,
            unitPrice: 1,
          ),
        ],
      );
      expect(edited!.lines.map((l) => l.itemId), [ItemIds.oignons]);

      final stored = await db
          .customSelect(
            'SELECT deleted_at FROM purchase_order_lines WHERE order_id = ?',
            variables: [Variable<String>(draft.id)],
          )
          .get();
      expect(stored, hasLength(2), reason: 'the replaced line is kept');

      expect(await orders.deleteDraft(draft.id), isTrue);
      expect(await orders.order(draft.id), isNull);
      expect(
        (await orders.orders(StoreIds.sablon)).map((o) => o.id),
        isNot(contains(draft.id)),
      );
      expect(await rawRows('purchase_orders', draft.id), hasLength(1));
    });

    test('a cleared password can be set again', () async {
      final credentials = CredentialRepository(db);
      expect(await credentials.forEmployee(EmployeeIds.amelie), isNotNull);

      expect(await credentials.clear(EmployeeIds.amelie), isTrue);
      expect(await credentials.forEmployee(EmployeeIds.amelie), isNull);

      // One credential per employee, deleted ones included: the old row comes
      // back instead of a second one being added.
      final restored = await credentials.setPassword(EmployeeIds.amelie, '9876');
      expect(restored, isNotNull);
      final rows = await db
          .customSelect(
            'SELECT id FROM employee_credentials WHERE employee_id = ?',
            variables: const [Variable<String>(EmployeeIds.amelie)],
          )
          .get();
      expect(rows, hasLength(1));
      final login = await credentials.authenticate(
        (await EmployeeRepository(db).employee(EmployeeIds.amelie))!.pin,
        '9876',
      );
      expect(login.outcome, LoginOutcome.success);
    });

    test('a busy day can be unmarked and marked again', () async {
      final calendar = CalendarRepository(db);
      final day = DateTime(2026, 12, 24);

      await calendar.toggleDate(StoreIds.sablon, day);
      expect((await calendar.calendar(StoreIds.sablon)).dates, contains(day));

      await calendar.toggleDate(StoreIds.sablon, day);
      expect(
        (await calendar.calendar(StoreIds.sablon)).dates,
        isNot(contains(day)),
      );

      await calendar.toggleDate(StoreIds.sablon, day);
      expect((await calendar.calendar(StoreIds.sablon)).dates, contains(day));
      final rows = await db.select(db.busyDates).get();
      expect(rows.where((r) => r.day == '2026-12-24'), hasLength(1));
    });
  });

  group('child rows know their store', () {
    test('rows written by the app carry the parent store', () async {
      final orders = OrderRepository(db);
      final draft = await orders.createDraft(
        storeId: StoreIds.liege,
        supplierId: SupplierIds.liegeGrossiste,
        lines: const [
          PurchaseOrderLine(
            id: 'x',
            itemId: ItemIds.tomates,
            quantityOrdered: 1,
            unitPrice: 1,
          ),
        ],
      );
      final line = await (db.select(
        db.purchaseOrderLines,
      )..where((l) => l.orderId.equals(draft.id))).getSingle();
      expect(line.storeId, StoreIds.liege);
    });

    test('every seeded child row matches its parent', () async {
      const checks = {
        'purchase_order_lines':
            'SELECT count(*) AS n FROM purchase_order_lines c '
            'JOIN purchase_orders p ON p.id = c.order_id '
            'WHERE c.store_id <> p.store_id',
        'goods_receipt_lines':
            'SELECT count(*) AS n FROM goods_receipt_lines c '
            'JOIN goods_receipts p ON p.id = c.receipt_id '
            'WHERE c.store_id <> p.store_id',
        'attendance_sessions':
            'SELECT count(*) AS n FROM attendance_sessions c '
            'JOIN attendances p ON p.id = c.attendance_id '
            'WHERE c.store_id <> p.store_id',
        'attendance_pauses':
            'SELECT count(*) AS n FROM attendance_pauses c '
            'JOIN attendance_sessions p ON p.id = c.session_id '
            'WHERE c.store_id <> p.store_id',
        'supplier_prices':
            'SELECT count(*) AS n FROM supplier_prices c '
            'JOIN items p ON p.id = c.item_id WHERE c.store_id <> p.store_id',
        'price_history':
            'SELECT count(*) AS n FROM price_history c '
            'JOIN items p ON p.id = c.item_id WHERE c.store_id <> p.store_id',
        'employee_credentials':
            'SELECT count(*) AS n FROM employee_credentials c '
            'JOIN employees p ON p.id = c.employee_id '
            'WHERE c.store_id <> p.store_id',
      };
      for (final entry in checks.entries) {
        final row = await db.customSelect(entry.value).getSingle();
        expect(row.read<int>('n'), 0, reason: entry.key);
      }
    });
  });

  group('device id', () {
    test('is made once and then stays the same', () async {
      final devices = DeviceRepository(db);
      final first = await devices.deviceId();
      expect(first, hasLength(36));
      expect(await devices.deviceId(), first);
    });

    test('survives a demo reset', () async {
      final id = await DeviceRepository(db).deviceId();
      await DemoRepository(db).resetDemo();
      expect(await DeviceRepository(db).deviceId(), id);
      final seeded = await (db.select(
        db.meta,
      )..where((m) => m.key.equals(MetaKeys.seededAt))).getSingleOrNull();
      expect(seeded, isNotNull, reason: 'the rest of meta is rewritten');
    });

    test('two installations get different ids', () async {
      final other = openEmptyDatabase();
      expect(
        await DeviceRepository(other).deviceId(),
        isNot(await DeviceRepository(db).deviceId()),
      );
    });
  });
}
