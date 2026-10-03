// The outbox: every change to shared data queues itself (SYNC_PLAN.md,
// Phase 2).
//
// Nothing is sent anywhere yet. These tests hold what the sender (Phase 5)
// will rely on:
//
//   - a change and its entry land in the same transaction, from triggers, so
//     no repository can forget;
//   - one entry per row, holding the row as it is now, in the order rows
//     first changed (a parent before its children);
//   - a delete is an entry with `deleted_at` set;
//   - the figures every device recomputes never travel;
//   - the seed, a stock rebuild and anything run through `SyncQuiet` queue
//     nothing, and a demo reset empties the queue.

import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/database/meta_keys.dart';
import 'package:stock_inventory/data/database/sync_tables.dart';
import 'package:stock_inventory/data/providers.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart'
    show CategoryIds, EmployeeIds, ItemIds, StoreIds, SupplierIds, UnitIds;
import 'package:stock_inventory/models/models.dart';
import 'package:stock_inventory/shared/widgets/offline_banner.dart';

import '../support/db_fixture.dart';

void main() {
  late AppDatabase db;
  late OutboxRepository outbox;

  setUp(() async {
    db = await openSeededDatabase();
    outbox = OutboxRepository(db);
  });

  Future<List<OutboxRow>> entriesFor(String table) => (db.select(db.outbox)
        ..where((o) => o.changedTable.equals(table))
        ..orderBy([(o) => OrderingTerm(expression: o.id)]))
      .get();

  Map<String, Object?> payloadOf(OutboxRow row) =>
      jsonDecode(row.payload) as Map<String, Object?>;

  Future<Item> newItem(String name) async => (await ItemRepository(db).create(
    storeId: StoreIds.sablon,
    name: name,
    categoryId: CategoryIds.epicerie,
    unitId: UnitIds.kg,
    lowStockThreshold: 1,
  ))!;

  test('the demo seed queues nothing', () async {
    expect(await outbox.pendingCount(), 0);
  });

  group('what gets queued', () {
    test('a new article is one entry holding the row', () async {
      final item = await newItem('Cardamome');

      final entries = await entriesFor('items');
      expect(entries, hasLength(1));
      final entry = entries.single;
      expect(entry.rowKey, item.id);
      expect(entry.storeId, StoreIds.sablon);
      final payload = payloadOf(entry);
      expect(payload['name'], 'Cardamome');
      expect(payload['deleted_at'], isNull);
    });

    test('three edits leave one entry, with the last version', () async {
      final item = await newItem('Muscade');
      final firstId = (await entriesFor('items')).single.id;

      final items = ItemRepository(db);
      for (final name in ['Muscade moulue', 'Muscade entière', 'Noix de muscade']) {
        await items.update(
          item.id,
          name: name,
          categoryId: CategoryIds.epicerie,
          unitId: UnitIds.kg,
          lowStockThreshold: 1,
        );
      }

      final entries = await entriesFor('items');
      expect(entries, hasLength(1));
      expect(payloadOf(entries.single)['name'], 'Noix de muscade');
      expect(
        entries.single.id,
        firstId,
        reason: 'the entry keeps the place of the first change',
      );
    });

    test('the entry holds the stamp the touch trigger wrote', () async {
      await CatalogRepository(
        db,
      ).renameCategory(CategoryIds.legumes, 'Légumes du jour');

      final row = await (db.select(
        db.categories,
      )..where((c) => c.id.equals(CategoryIds.legumes))).getSingle();
      final entry = (await entriesFor('categories')).single;
      expect(
        DateTime.parse(payloadOf(entry)['updated_at']! as String),
        row.updatedAt,
      );
    });

    test('a delete is an entry with deleted_at set', () async {
      final catalog = CatalogRepository(db);
      final category = (await catalog.createCategory(
        storeId: StoreIds.sablon,
        name: 'Éphémère',
      ))!;
      await catalog.deleteCategory(category.id);

      final entry = (await entriesFor('categories')).single;
      expect(entry.rowKey, category.id);
      expect(payloadOf(entry)['deleted_at'], isNotNull);
    });

    test('a movement queues itself and the article, without its stock figures',
        () async {
      final movement = await MovementRepository(db).recordStockIn(
        storeId: StoreIds.sablon,
        itemId: ItemIds.tomates,
        quantity: 4,
        unitPrice: 2.2,
      );

      final movements = await entriesFor('stock_movements');
      expect(movements.single.rowKey, movement.id);
      expect(payloadOf(movements.single)['quantity'], 4);
      expect(payloadOf(movements.single)['unit_cost'], isNotNull);

      final itemPayload = payloadOf((await entriesFor('items')).single);
      expect(itemPayload.containsKey('quantity'), isFalse);
      expect(itemPayload.containsKey('average_cost'), isFalse);
      expect(itemPayload['baseline_quantity'], isNotNull);
    });

    test('a parent is queued before its children', () async {
      final draft = await OrderRepository(db).createDraft(
        storeId: StoreIds.sablon,
        supplierId: SupplierIds.grossisteCentral,
        lines: const [
          PurchaseOrderLine(
            id: 'x',
            itemId: ItemIds.tomates,
            quantityOrdered: 2,
            unitPrice: 1,
          ),
        ],
      );
      // Editing the order afterwards must not move it behind its line.
      await OrderRepository(db).updateDraft(draft.id, note: 'Livrer le matin');

      final order = (await entriesFor('purchase_orders')).single;
      final line = (await entriesFor('purchase_order_lines')).single;
      expect(order.id, lessThan(line.id));
      expect(payloadOf(order)['note'], 'Livrer le matin');
    });

    test('a busy day is keyed by store and date', () async {
      await CalendarRepository(
        db,
      ).toggleDate(StoreIds.sablon, DateTime(2026, 12, 31));
      final entry = (await entriesFor('busy_dates')).single;
      expect(entry.rowKey, '${StoreIds.sablon}|2026-12-31');
    });

    test('a store is its own establishment', () async {
      await StoreRepository(db).setStalePartialOrderDays(StoreIds.liege, 9);
      final entry = (await entriesFor('stores')).single;
      expect(entry.rowKey, StoreIds.liege);
      expect(entry.storeId, StoreIds.liege);
    });

    test('a failed change queues nothing', () async {
      await expectLater(
        db.transaction(() async {
          await newItem('Annulé');
          throw StateError('rolled back');
        }),
        throwsStateError,
      );
      expect(await outbox.pendingCount(), 0);
    });
  });

  group('what does not get queued', () {
    test('a stock rebuild', () async {
      await (db.update(db.items)..where((i) => i.id.equals(ItemIds.tomates)))
          .write(const ItemsCompanion(quantity: Value(-1)));
      await db.delete(db.outbox).go();

      expect(await StockLedger(db).rebuildItem(ItemIds.tomates), isTrue);
      expect(await outbox.pendingCount(), 0);
    });

    test('anything run quietly, and the switch goes off afterwards', () async {
      await SyncQuiet.run(db, () => newItem('Silencieux'));
      expect(await outbox.pendingCount(), 0);
      expect(await SyncQuiet.isOn(db), isFalse);

      await newItem('Bruyant');
      expect(await outbox.pendingCount(), 1);
    });

    test('a failure inside a quiet write does not leave the switch on',
        () async {
      await expectLater(
        SyncQuiet.run(db, () async {
          await newItem('Échec');
          throw StateError('boom');
        }),
        throwsStateError,
      );
      expect(await SyncQuiet.isOn(db), isFalse);
      final key = await (db.select(
        db.meta,
      )..where((m) => m.key.equals(MetaKeys.syncQuiet))).getSingleOrNull();
      expect(key, isNull);
    });

    test('nested quiet writes stay quiet to the end', () async {
      await SyncQuiet.run(db, () async {
        await SyncQuiet.run(db, () => newItem('Intérieur'));
        await newItem('Extérieur');
      });
      expect(await outbox.pendingCount(), 0);
    });
  });

  test('a demo reset empties the queue', () async {
    await newItem('Walkthrough');
    expect(await outbox.pendingCount(), greaterThan(0));

    await DemoRepository(db).resetDemo();
    expect(await outbox.pendingCount(), 0);
  });

  test('the banner count follows the queue', () async {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(pendingChangesProvider, (_, _) {});
    addTearDown(subscription.close);

    await container.read(outboxPendingCountProvider.future);
    expect(container.read(pendingChangesProvider), 0);

    await newItem('Compté');
    await pumpEventQueue();
    expect(container.read(pendingChangesProvider), 1);
  });

  group('the triggers match the tables', () {
    test('every synced table queues inserts and updates', () async {
      final triggers = {
        for (final row in await db
            .customSelect("SELECT name FROM sqlite_master WHERE type = 'trigger'")
            .get())
          row.read<String>('name'),
      };
      for (final table in SyncTables.synced) {
        expect(triggers, contains('${table}_outbox_insert'), reason: table);
        expect(triggers, contains('${table}_outbox_update'), reason: table);
      }
    });

    // A column added to a synced table without regenerating the triggers
    // would never reach the server. Run tool/generate_outbox_triggers.py.
    test('every column travels, except the recomputed ones', () async {
      for (final table in SyncTables.synced) {
        final columns = {
          for (final row in await db
              .customSelect('PRAGMA table_info($table)')
              .get())
            row.read<String>('name'),
        };
        final sql = (await db
                .customSelect(
                  'SELECT sql FROM sqlite_master WHERE name = ?',
                  variables: [Variable<String>('${table}_outbox_insert')],
                )
                .getSingle())
            .read<String>('sql');
        final payloadSql = sql.substring(sql.indexOf('json_object('));
        final sent = {
          for (final match in RegExp(
            r"'([a-z_]+)', ([a-z_]+)",
          ).allMatches(payloadSql))
            match.group(1)!,
        };
        final expected = table == 'items'
            ? columns.difference({'quantity', 'average_cost'})
            : columns;
        expect(sent, expected, reason: table);
      }
    });
  });

  // SYNC_PERSONNEL_PLAN.md, step 4 (rules E2, E3): an edit of a personnel row
  // names the columns it changed, so the server overwrites only those.
  group('only the changed fields of a personnel row', () {
    Set<String>? columnsOf(OutboxRow row) => row.changedColumns == null
        ? null
        : {for (final c in jsonDecode(row.changedColumns!) as List) c as String};

    test('an edit names its columns, and the stamp', () async {
      await EmployeeRepository(db).update(EmployeeIds.noah, phone: '0499');

      final entry = (await entriesFor('employees')).single;
      expect(columnsOf(entry), {'phone', 'updated_at'});
      // The payload is still the whole row: a server without the row can
      // insert it.
      expect(payloadOf(entry)['first_name'], isNotNull);
    });

    test('two edits while offline add up', () async {
      final employees = EmployeeRepository(db);
      await employees.update(EmployeeIds.noah, phone: '0499');
      await employees.update(EmployeeIds.noah, lastName: 'Martin');
      await employees.archive(EmployeeIds.noah);

      final entry = (await entriesFor('employees')).single;
      expect(columnsOf(entry), {
        'phone',
        'last_name',
        'archived_at',
        'updated_at',
      });
    });

    test('a new row stays whole, even edited before it is sent', () async {
      final created = (await EmployeeRepository(db).create(
        storeId: StoreIds.sablon,
        firstName: 'Zoé',
        lastName: 'Neuve',
        pin: 'PIN-ZOE',
        phone: '081',
        email: 'zoe@resto.be',
        role: EmployeeRole.staff,
        pay: 15,
      ))!;
      await EmployeeRepository(db).update(created.id, phone: '0499');

      final entry = (await entriesFor(
        'employees',
      )).singleWhere((e) => e.rowKey == created.id);
      expect(entry.changedColumns, isNull);
    });

    test('other tables still send the whole row', () async {
      final item = await newItem('Sel fin');
      await outbox.clear();
      await ItemRepository(db).update(item.id, name: 'Sel de mer');

      expect((await entriesFor('items')).single.changedColumns, isNull);
    });
  });
}
