// The schema is a set of promises: these tables exist, these references are
// enforced, these ones deliberately are not. This suite is where those promises
// are checked, because every later stage builds on them and a foreign key that
// is quietly off looks exactly like one that works — until data goes missing.

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/models/models.dart';

import '../support/sqlite.dart';

void main() {
  setUpAll(useTestSqlite);

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.memory();
    // Opening is lazy. This forces onCreate and beforeOpen to have run before
    // the first assertion looks at the result of either.
    await db.customSelect('SELECT 1').get();
  });

  tearDown(() => db.close());

  Future<List<String>> tableNames() async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%' ORDER BY name",
        )
        .get();
    return rows.map((row) => row.read<String>('name')).toList();
  }

  Future<void> seedMinimalStore() async {
    await db.into(db.stores).insert(
          StoresCompanion.insert(
            id: 'store-1',
            name: 'Brasserie',
            addressLine: 'Rue Haute 1',
            postalCode: '1000',
            city: 'Bruxelles',
            phone: '+32 2 000 00 00',
            createdAt: DateTime(2026),
          ),
        );
    await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            id: 'cat-1',
            storeId: 'store-1',
            name: 'Légumes',
          ),
        );
    await db.into(db.units).insert(
          UnitsCompanion.insert(
            id: 'unit-1',
            storeId: 'store-1',
            name: 'Kilogramme',
            abbreviation: 'kg',
          ),
        );
  }

  Future<void> insertItem({
    String id = 'item-1',
    String categoryId = 'cat-1',
    String unitId = 'unit-1',
  }) {
    return db.into(db.items).insert(
          ItemsCompanion.insert(
            id: id,
            storeId: 'store-1',
            name: 'Tomates',
            categoryId: categoryId,
            unitId: unitId,
            quantity: 0,
            lowStockThreshold: 5,
            updatedAt: DateTime(2026),
          ),
        );
  }

  Future<void> insertSupplier({String id = 'sup-1'}) {
    return db.into(db.suppliers).insert(
          SuppliersCompanion.insert(
            id: id,
            storeId: 'store-1',
            name: 'Maraîcher',
            contactName: 'Luc',
            email: 'luc@example.be',
            phone: '+32 2 111 11 11',
            addressLine: 'Chaussée 5',
            postalCode: '1050',
            city: 'Ixelles',
          ),
        );
  }

  Future<void> linkItemToSupplier(String id) {
    return db.into(db.supplierPrices).insert(
          SupplierPricesCompanion.insert(
            id: id,
            itemId: 'item-1',
            supplierId: 'sup-1',
            pricePerUnit: 2.5,
            effectiveDate: DateTime(2026),
            isDefault: true,
          ),
        );
  }

  group('the database is created', () {
    test('with every table the app needs', () async {
      expect(await tableNames(), <String>[
        'categories',
        'goods_receipt_lines',
        'goods_receipts',
        'items',
        'meta',
        'notifications',
        'price_history',
        'purchase_order_lines',
        'purchase_orders',
        'stock_movements',
        'stores',
        'supplier_prices',
        'suppliers',
        'team_member_stores',
        'team_members',
        'units',
      ]);
    });

    test('at schema version 1', () {
      expect(db.schemaVersion, 1);
    });

    test('with foreign keys switched on', () async {
      final rows = await db.customSelect('PRAGMA foreign_keys').get();
      expect(
        rows.single.read<int>('foreign_keys'),
        1,
        reason: 'SQLite defaults this to off, per connection. Without it every '
            'reference below is decorative.',
      );
    });
  });

  group('references that are enforced', () {
    test('an item cannot name a category that does not exist', () async {
      await seedMinimalStore();
      await expectLater(
        insertItem(categoryId: 'cat-nope'),
        throwsA(isA<SqliteException>()),
      );
    });

    test('an item cannot name a unit that does not exist', () async {
      await seedMinimalStore();
      await expectLater(
        insertItem(unitId: 'unit-nope'),
        throwsA(isA<SqliteException>()),
      );
    });

    test('a category in use cannot be deleted', () async {
      await seedMinimalStore();
      await insertItem();

      await expectLater(
        (db.delete(db.categories)..where((c) => c.id.equals('cat-1'))).go(),
        throwsA(isA<SqliteException>()),
      );
    });

    test('deleting an item takes its supplier prices with it', () async {
      await seedMinimalStore();
      await insertItem();
      await insertSupplier();
      await linkItemToSupplier('price-1');

      await (db.delete(db.items)..where((i) => i.id.equals('item-1'))).go();

      expect(await db.select(db.supplierPrices).get(), isEmpty);
    });

    test('one item and one supplier can only be linked once', () async {
      await seedMinimalStore();
      await insertItem();
      await insertSupplier();

      await linkItemToSupplier('price-1');
      await expectLater(
        linkItemToSupplier('price-2'),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  group('references that are deliberately not enforced', () {
    // Each of these would be a foreign key in a schema drawn from the diagram
    // rather than written from the rules. They are absent on purpose, and a
    // later tidy-up that adds them would quietly change what the app does.

    test(
      'a movement keeps a deleted supplier id rather than losing it',
      () async {
        await seedMinimalStore();
        await insertItem();
        await insertSupplier();

        await db.into(db.stockMovements).insert(
              StockMovementsCompanion.insert(
                id: 'mov-1',
                storeId: 'store-1',
                itemId: 'item-1',
                type: StockMovementType.stockIn,
                quantity: 10,
                occurredAt: DateTime(2026),
                userName: 'Sophie',
                supplierId: const Value('sup-1'),
              ),
            );

        await (db.delete(db.suppliers)..where((s) => s.id.equals('sup-1'))).go();

        final movement = await db.select(db.stockMovements).getSingle();
        expect(
          movement.supplierId,
          'sup-1',
          reason: 'the goods really moved; the supplier leaving does not unmake '
              'that, and the screen renders "Fournisseur supprimé"',
        );
      },
    );

    test('a closed order line survives its article being deleted', () async {
      await seedMinimalStore();
      await insertItem();

      await db.into(db.purchaseOrders).insert(
            PurchaseOrdersCompanion.insert(
              id: 'order-1',
              storeId: 'store-1',
              supplierId: 'sup-gone',
              reference: 'CMD-2026-001',
              status: PurchaseOrderStatus.received,
              createdAt: DateTime(2026),
            ),
          );
      await db.into(db.purchaseOrderLines).insert(
            PurchaseOrderLinesCompanion.insert(
              id: 'line-1',
              orderId: 'order-1',
              itemId: 'item-1',
              quantityOrdered: 4,
              unitPrice: 3,
              position: 0,
            ),
          );

      await (db.delete(db.items)..where((i) => i.id.equals('item-1'))).go();

      final line = await db.select(db.purchaseOrderLines).getSingle();
      expect(line.itemId, 'item-1');
    });
  });

  group('storage formats', () {
    test('enums are stored as their name, not their index', () async {
      await seedMinimalStore();
      await insertItem();
      await db.into(db.stockMovements).insert(
            StockMovementsCompanion.insert(
              id: 'mov-1',
              storeId: 'store-1',
              itemId: 'item-1',
              type: StockMovementType.stockOut,
              quantity: -2,
              occurredAt: DateTime(2026),
              userName: 'Sophie',
              reason: const Value(StockOutReason.waste),
            ),
          );

      final row = await db
          .customSelect('SELECT type, reason FROM stock_movements')
          .getSingle();
      expect(row.read<String>('type'), 'stockOut');
      expect(row.read<String>('reason'), 'waste');
    });

    test('dates are stored as text and keep sub-second precision', () async {
      final precise = DateTime(2026, 3, 4, 5, 6, 7, 890);
      await db.into(db.stores).insert(
            StoresCompanion.insert(
              id: 'store-1',
              name: 'Brasserie',
              addressLine: 'Rue Haute 1',
              postalCode: '1000',
              city: 'Bruxelles',
              phone: '+32 2 000 00 00',
              createdAt: precise,
            ),
          );

      final row = await db
          .customSelect('SELECT typeof(created_at) AS t FROM stores')
          .getSingle();
      expect(row.read<String>('t'), 'text');

      final store = await db.select(db.stores).getSingle();
      expect(store.createdAt, precise);
    });

    test(
      'a new store keeps a partial order open for a week by default',
      () async {
        await seedMinimalStore();
        final store = await db.select(db.stores).getSingle();
        expect(store.stalePartialOrderDays, 7);
      },
    );
  });
}
