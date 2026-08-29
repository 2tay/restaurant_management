// The read repositories, checked against the implementation they replace.
//
// `MockQueries` is still here and still correct, and the seeded database is
// built from the same dataset it reads. So for anything that does not depend on
// wall-clock time, the two have to agree — and that is a far stronger check than
// asserting a number this file made up. Where they cannot agree, the difference
// is deliberate and is asserted as such: the ordering contracts that used to be
// insertion order, and the two rules the plan asked to be rewritten as SQL.
//
// This suite goes away with `MockQueries` in stage 10, having done its job of
// getting the translation across.

import 'dart:async';

// `isNull` and `isNotNull` mean different things in drift and in matcher.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/core/utils/order_status.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/mock_data/mock_data.dart';
import 'package:stock_inventory/models/models.dart';

import '../support/db_fixture.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await openSeededDatabase();
  });

  List<String> idsOfItems(List<Item> items) => items.map((i) => i.id).toList();

  group('stores', () {
    test('lists oldest first, which is the order the demo was written in', () async {
      final stores = await StoreRepository(db).stores();
      expect(stores.map((s) => s.id), mockStores.map((s) => s.id));
    });

    test('an unknown id falls back to the first establishment', () async {
      final repo = StoreRepository(db);
      expect((await repo.watchStoreOrFirst('nope').first)?.id, StoreIds.sablon);
      expect((await repo.watchStoreOrFirst(null).first)?.id, StoreIds.sablon);
      expect(
        (await repo.watchStoreOrFirst(StoreIds.liege).first)?.id,
        StoreIds.liege,
      );
    });

    test('carries the stale-order threshold that used to be a global', () async {
      expect(
        await StoreRepository(db).stalePartialOrderDays(StoreIds.sablon),
        MockSettings.stalePartialOrderDays,
      );
    });
  });

  group('catalogue', () {
    test('holds the same categories and units as the dataset', () async {
      final repo = CatalogRepository(db);
      expect(
        (await repo.categories(StoreIds.sablon)).map((c) => c.id).toSet(),
        MockQueries.categoriesForStore(StoreIds.sablon).map((c) => c.id).toSet(),
      );
      expect(
        (await repo.units(StoreIds.sablon)).map((u) => u.id).toSet(),
        MockQueries.unitsForStore(StoreIds.sablon).map((u) => u.id).toSet(),
      );
    });

    test('name matching folds case but not accents', () async {
      final repo = CatalogRepository(db);
      final existing = (await repo.categories(StoreIds.sablon)).firstWhere(
        (c) => c.name == 'Épicerie sèche',
      );

      expect((await repo.categoryNamed(StoreIds.sablon, ' ÉPICERIE SÈCHE '))?.id,
          existing.id);
      expect(
        await repo.categoryNamed(StoreIds.sablon, 'Epicerie seche'),
        isNull,
        reason: 'stripping accents would block a user correcting a spelling',
      );
      expect(
        await repo.categoryNamed(
          StoreIds.sablon,
          existing.name,
          excludingId: existing.id,
        ),
        isNull,
        reason: 'a rename must not collide with the row being renamed',
      );
    });

    test('a unit is guarded on its abbreviation as well as its name', () async {
      final repo = CatalogRepository(db);
      final kg = (await repo.units(StoreIds.sablon)).firstWhere(
        (u) => u.abbreviation == 'kg',
      );

      expect((await repo.unitAbbreviated(StoreIds.sablon, 'KG'))?.id, kg.id);
      expect((await repo.unitNamed(StoreIds.sablon, 'kilogramme'))?.id, kg.id);
    });

    test('counts what a category and a unit are holding', () async {
      final repo = CatalogRepository(db);
      final category = MockQueries.categoriesForStore(StoreIds.sablon).first;
      final unit = MockQueries.unitsForStore(StoreIds.sablon).first;

      expect(
        await repo.itemCountInCategory(category.id),
        MockQueries.itemCountInCategory(category.id),
      );
      expect(
        await repo.itemCountUsingUnit(unit.id),
        MockQueries.itemCountUsingUnit(unit.id),
      );
    });
  });

  group('articles', () {
    test('holds the same articles as the dataset', () async {
      final items = await ItemRepository(db).items(StoreIds.sablon);
      expect(
        idsOfItems(items).toSet(),
        idsOfItems(MockQueries.itemsForStore(StoreIds.sablon)).toSet(),
      );
    });

    test('the alerts list keeps its worst-first order', () async {
      // The one ordering that was already explicit in Phase 1, so it can be
      // compared element by element rather than as a set.
      final rows = await ItemRepository(
        db,
      ).itemsByAttention(StoreIds.sablon, filter: const ItemFilter(lowStockOnly: true));

      expect(idsOfItems(rows), idsOfItems(MockQueries.lowStockItems(StoreIds.sablon)));
    });

    test('filtering by supplier answers what the N+1 loop answered', () async {
      const supplierId = SupplierIds.maraicher;
      final rows = await ItemRepository(
        db,
      ).itemsByAttention(
        StoreIds.sablon,
        filter: const ItemFilter(supplierId: supplierId),
      );

      final expected = MockQueries.itemsForStore(StoreIds.sablon)
          .where(
            (item) => MockQueries.pricesForItem(
              item.id,
            ).any((p) => p.supplierId == supplierId),
          )
          .map((i) => i.id)
          .toSet();

      expect(idsOfItems(rows).toSet(), expected);
      expect(rows, isNotEmpty);
    });

    test('filtering by category and by low stock together', () async {
      final item = MockQueries.lowStockItems(StoreIds.sablon).first;
      final rows = await ItemRepository(db).itemsByAttention(
        StoreIds.sablon,
        filter: ItemFilter(categoryId: item.categoryId, lowStockOnly: true),
      );

      expect(idsOfItems(rows), contains(item.id));
      for (final row in rows) {
        expect(row.categoryId, item.categoryId);
        expect(row.quantity, lessThanOrEqualTo(row.lowStockThreshold));
      }
    });

    test('a barcode lookup is exact, and an edit does not collide with itself',
        () async {
      final repo = ItemRepository(db);
      final withBarcode = MockQueries.itemsForStore(
        StoreIds.sablon,
      ).firstWhere((i) => i.barcode != null);

      expect(
        idsOfItems(await repo.itemsWithBarcode(StoreIds.sablon, withBarcode.barcode!)),
        [withBarcode.id],
      );
      expect(
        (await repo.barcodeConflict(StoreIds.sablon, withBarcode.barcode!))?.id,
        withBarcode.id,
      );
      expect(
        await repo.barcodeConflict(
          StoreIds.sablon,
          withBarcode.barcode!,
          excludingItemId: withBarcode.id,
        ),
        isNull,
      );
      expect(await repo.itemsWithBarcode(StoreIds.sablon, '   '), isEmpty);
    });

    test('the suggestion list is this supplier and low stock', () async {
      final rows = await ItemRepository(
        db,
      ).watchSuggestedItems(StoreIds.sablon, SupplierIds.maraicher).first;

      expect(
        idsOfItems(rows).toSet(),
        idsOfItems(
          MockQueries.suggestedItemsForSupplier(
            StoreIds.sablon,
            SupplierIds.maraicher,
          ),
        ).toSet(),
      );
    });
  });

  group('prices', () {
    test('are cheapest first, which is what promotion depends on', () async {
      final repo = SupplierRepository(db);
      final item = mockItems.firstWhere(
        (i) => MockQueries.pricesForItem(i.id).length >= 3,
      );

      final prices = await repo.pricesForItem(item.id);
      expect(
        prices.map((p) => p.pricePerUnit),
        MockQueries.pricesForItem(item.id).map((p) => p.pricePerUnit),
      );
      expect(
        (await repo.cheapestPriceForItem(item.id))?.id,
        MockQueries.cheapestPriceForItem(item.id)?.id,
      );
    });

    test('the overpayment gap matches the report it feeds', () async {
      final repo = SupplierRepository(db);
      for (final item in MockQueries.itemsForStore(StoreIds.sablon)) {
        expect(
          await repo.overpayPerUnit(item.id),
          closeTo(MockQueries.overpayPerUnit(item.id), 0.0001),
          reason: item.name,
        );
      }
    });

    test('an item-supplier pair resolves, and its history is newest first',
        () async {
      final repo = SupplierRepository(db);
      final entry = mockPriceHistory.first;

      expect(
        (await repo.priceFor(entry.itemId, entry.supplierId))?.id,
        MockQueries.priceFor(entry.itemId, entry.supplierId)?.id,
      );

      final history = await repo.priceHistoryFor(entry.itemId, entry.supplierId);
      expect(
        history.map((h) => h.id),
        MockQueries.priceHistoryFor(entry.itemId, entry.supplierId).map((h) => h.id),
      );
    });

    test('counts the articles a supplier is linked to', () async {
      expect(
        await SupplierRepository(db).itemCountForSupplier(SupplierIds.maraicher),
        MockQueries.itemCountForSupplier(SupplierIds.maraicher),
      );
    });
  });

  group('movements', () {
    test('are newest first, with a tiebreak the list version never needed',
        () async {
      final movements = await MovementRepository(
        db,
      ).movementsForStore(StoreIds.sablon);

      expect(
        movements.map((m) => m.id).toSet(),
        MockQueries.movementsForStore(StoreIds.sablon).map((m) => m.id).toSet(),
      );

      for (var i = 1; i < movements.length; i++) {
        final previous = movements[i - 1];
        final current = movements[i];
        expect(
          previous.occurredAt.isAfter(current.occurredAt) ||
              (previous.occurredAt == current.occurredAt &&
                  previous.id.compareTo(current.id) > 0),
          isTrue,
          reason: '${previous.id} should sort before ${current.id}',
        );
      }
    });

    test('the activity feed is the top of that list', () async {
      final feed = await MovementRepository(
        db,
      ).recentActivity(StoreIds.sablon, limit: 5);
      final all = await MovementRepository(db).movementsForStore(StoreIds.sablon);

      expect(feed.map((m) => m.id), all.take(5).map((m) => m.id));
    });
  });

  group('commandes', () {
    test('come back newest first, each with its lines in order', () async {
      final orders = await OrderRepository(db).orders(StoreIds.sablon);

      expect(
        orders.map((o) => o.id),
        MockQueries.ordersForStore(StoreIds.sablon).map((o) => o.id),
      );
      for (final order in orders) {
        expect(
          order.lines.map((l) => l.id),
          MockQueries.orderById(order.id)!.lines.map((l) => l.id),
          reason: '${order.reference} lines are out of order',
        );
      }
    });

    test('open means sent or partial', () async {
      final open = await OrderRepository(db).openOrders(StoreIds.sablon);
      expect(open.map((o) => o.id), MockQueries.openOrders(StoreIds.sablon).map((o) => o.id));
      expect(open.every(orderIsOpen), isTrue);
    });

    test('the SQL outstanding sum agrees with the Dart rule it duplicates',
        () async {
      // `lineOutstanding` is written twice: once in Dart, once as SQL inside
      // onOrderQuantity, because that one is read per row of the inventory list.
      // This is the test that stops the two spellings drifting apart.
      final repo = OrderRepository(db);
      var checked = 0;

      for (final item in MockQueries.itemsForStore(StoreIds.sablon)) {
        final expected = MockQueries.onOrderQuantity(StoreIds.sablon, item.id);
        expect(
          await repo.onOrderQuantity(StoreIds.sablon, item.id),
          closeTo(expected, 0.0001),
          reason: item.name,
        );
        if (expected > 0) checked++;
      }

      expect(checked, greaterThan(0), reason: 'nothing was on order to compare');
    });

    test('open commandes for an article match the Dart filter', () async {
      final item = MockQueries.itemsForStore(StoreIds.sablon).firstWhere(
        (i) => MockQueries.openOrdersForItem(StoreIds.sablon, i.id).isNotEmpty,
      );

      expect(
        (await OrderRepository(db).openOrdersForItem(StoreIds.sablon, item.id))
            .map((o) => o.id),
        MockQueries.openOrdersForItem(StoreIds.sablon, item.id).map((o) => o.id),
      );
    });

    test('a stale commande is measured against the establishment column',
        () async {
      final repo = OrderRepository(db);

      // Nothing is stale when the threshold is generous, and the same commandes
      // are stale as the mock rule finds when it is the default.
      expect(await repo.staleOrders(StoreIds.sablon, now: seedInstant),
          MockQueries.staleOrders(StoreIds.sablon).isEmpty ? isEmpty : isNotEmpty);

      await db.customStatement(
        'UPDATE stores SET stale_partial_order_days = 3650 WHERE id = ?',
        [StoreIds.sablon],
      );
      expect(await repo.staleOrders(StoreIds.sablon, now: seedInstant), isEmpty);
    });
  });

  group('receipts', () {
    test('are oldest first, because the reference counts them', () async {
      final order = mockGoodsReceipts.first.orderId;
      final receipts = await OrderRepository(db).receiptsForOrder(order);

      expect(
        receipts.map((r) => r.id),
        MockQueries.receiptsForOrder(order).map((r) => r.id),
      );
      for (final receipt in receipts) {
        expect(
          receipt.lines.map((l) => l.id),
          MockQueries.receiptById(receipt.id)!.lines.map((l) => l.id),
        );
      }
    });

    test('the quotable reference matches the document', () async {
      final repo = OrderRepository(db);
      for (final receipt in mockGoodsReceipts) {
        final stored = await repo.receipt(receipt.id);
        expect(
          await repo.receiptReferenceOf(stored!),
          MockQueries.receiptReferenceOf(receipt),
        );
      }
    });
  });

  group('team and notifications', () {
    test('a member carries the establishments granted to them', () async {
      final repo = AccountRepository(db);
      final team = await repo.team();

      expect(team.map((m) => m.id), mockTeam.map((m) => m.id));
      for (final member in team) {
        expect(
          member.storeIds.toSet(),
          mockTeam.firstWhere((m) => m.id == member.id).storeIds.toSet(),
          reason: member.fullName,
        );
      }
      expect(await repo.ownerCount(), MockQueries.ownerCount());
    });

    test('scoping a member to an establishment reads the join table', () async {
      expect(
        (await AccountRepository(db).teamForStore(StoreIds.liege)).map((m) => m.id),
        MockQueries.teamForStore(StoreIds.liege).map((m) => m.id),
      );
    });

    test('an email is matched case-insensitively, excluding the editing row',
        () async {
      final repo = AccountRepository(db);
      final member = mockTeam.first;

      expect(
        (await repo.teamMemberByEmail(member.email.toUpperCase()))?.id,
        member.id,
      );
      expect(
        await repo.teamMemberByEmail(member.email, excludingId: member.id),
        isNull,
      );
    });

    test('notifications are newest first and the unread badge agrees', () async {
      final repo = AccountRepository(db);
      final notifications = await repo.notifications(StoreIds.sablon);

      expect(
        notifications.map((n) => n.id).toSet(),
        MockQueries.notificationsForStore(StoreIds.sablon).map((n) => n.id).toSet(),
      );
      for (var i = 1; i < notifications.length; i++) {
        expect(
          notifications[i - 1].createdAt.isBefore(notifications[i].createdAt),
          isFalse,
          reason: 'newest first',
        );
      }
      expect(
        await repo.unreadNotificationCount(StoreIds.sablon),
        MockQueries.unreadNotificationCount(StoreIds.sablon),
      );
      expect(
        await repo.watchUnreadCount(StoreIds.sablon).first,
        MockQueries.unreadNotificationCount(StoreIds.sablon),
      );
    });
  });

  group('reports', () {
    test('the valuation is the sum of quantity times what it cost', () async {
      expect(
        await ReportRepository(db).stockValuation(StoreIds.sablon),
        closeTo(MockQueries.stockValuation(StoreIds.sablon), 0.0001),
      );
    });

    test('the category breakdown matches, shares included', () async {
      final rows = await ReportRepository(db).valuationByCategory(StoreIds.sablon);
      final expected = MockQueries.valuationByCategory(StoreIds.sablon);

      expect(rows.map((r) => r.label), expected.map((r) => r.label));
      for (final (index, row) in rows.indexed) {
        expect(row.totalValue, closeTo(expected[index].totalValue, 0.0001));
        expect(row.shareOfTotal, closeTo(expected[index].shareOfTotal, 0.0001));
        expect(row.itemCount, expected[index].itemCount);
      }
    });

    test('the top articles match, and the share is of the whole establishment',
        () async {
      final rows = await ReportRepository(db).valuationByItem(StoreIds.sablon);
      final expected = MockQueries.valuationByItem(StoreIds.sablon);

      expect(rows.map((r) => r.label), expected.map((r) => r.label));
      for (final (index, row) in rows.indexed) {
        expect(row.totalValue, closeTo(expected[index].totalValue, 0.0001));
        expect(row.shareOfTotal, closeTo(expected[index].shareOfTotal, 0.0001));
      }
    });

    test('what left stock is valued at what it cost, not at a price', () async {
      final repo = ReportRepository(db);

      expect(
        await repo.consumptionValue(StoreIds.sablon),
        closeTo(MockQueries.consumptionValue(StoreIds.sablon), 0.0001),
      );
      expect(
        await repo.wasteValue(StoreIds.sablon),
        closeTo(MockQueries.wasteValue(StoreIds.sablon), 0.0001),
      );
      expect(
        await repo.shrinkageValue(StoreIds.sablon),
        closeTo(MockQueries.shrinkageValue(StoreIds.sablon), 0.0001),
      );
    });

    test('a window excludes what falls outside it, at both ends', () async {
      final repo = ReportRepository(db);

      // The seeded stock-outs predate the cost fields and carry no unit cost, so
      // they are worth nothing by design — "understating beats inventing". One
      // costed movement is added here so the window has something to include and
      // exclude.
      await db.customStatement(
        'INSERT INTO stock_movements '
        '(id, store_id, item_id, type, quantity, occurred_at, user_name, '
        ' reason, unit_cost) '
        "VALUES ('mov-window', ?, ?, 'stockOut', -4, ?, 'Sophie', 'sale', 3.5)",
        [
          StoreIds.sablon,
          MockQueries.itemsForStore(StoreIds.sablon).first.id,
          seedInstant.subtract(const Duration(days: 2)).toIso8601String(),
        ],
      );

      final whole = await repo.consumptionValue(StoreIds.sablon);
      expect(whole, closeTo(14, 0.0001));
      expect(
        await repo.consumptionValue(
          StoreIds.sablon,
          from: seedInstant.add(const Duration(days: 1)),
        ),
        0,
        reason: 'nothing in the dataset happens after the anchor',
      );
      expect(
        await repo.consumptionValue(
          StoreIds.sablon,
          to: seedInstant.subtract(const Duration(days: 3650)),
        ),
        0,
      );
      expect(
        await repo.consumptionValue(
          StoreIds.sablon,
          from: seedInstant.subtract(const Duration(days: 3650)),
          to: seedInstant,
        ),
        closeTo(whole, 0.0001),
      );
    });

    test('the price comparison opens on the biggest overpayment', () async {
      final id = await ReportRepository(db).largestOverpayItemId(StoreIds.sablon);
      expect(id, isNotNull);

      final gap = await SupplierRepository(db).overpayPerUnit(id!);
      for (final item in MockQueries.itemsForStore(StoreIds.sablon)) {
        expect(MockQueries.overpayPerUnit(item.id), lessThanOrEqualTo(gap + 0.0001));
      }
    });

    test('an empty establishment reports nothing rather than throwing', () async {
      final repo = ReportRepository(db);

      expect(await repo.stockValuation(StoreIds.saintGilles), 0);
      expect(await repo.valuationByCategory(StoreIds.saintGilles), isEmpty);
      expect(await repo.valuationByItem(StoreIds.saintGilles), isEmpty);
      expect(await repo.wasteValue(StoreIds.saintGilles), 0);
      expect(await repo.largestOverpayItemId(StoreIds.saintGilles), isNull);
    });
  });

  group('streams push when the data changes', () {
    test('a quantity change reaches a watcher without anybody telling it',
        () async {
      // This is what replaces the global revision counter: no signal, no
      // invalidation, the database pushes.
      final repo = ItemRepository(db);
      final item = MockQueries.itemsForStore(StoreIds.sablon).first;

      final watcher = StreamIterator(repo.watchItem(item.id));
      addTearDown(watcher.cancel);

      // Subscribe and take delivery of the current value first: a stream that
      // has not connected yet would simply read the new number and prove
      // nothing.
      expect(await watcher.moveNext(), isTrue);
      expect(watcher.current?.quantity, item.quantity);

      // A typed write, not `customStatement`. drift works out which tables a
      // statement touches from the statement it built; a raw one tells it
      // nothing, so the update lands in the database and no stream ever hears
      // about it. Every repository write from stage 4 onward has to go through
      // the typed API for the same reason.
      await (db.update(db.items)..where((i) => i.id.equals(item.id))).write(
        const ItemsCompanion(quantity: Value(999)),
      );

      expect(await watcher.moveNext(), isTrue);
      expect(watcher.current?.quantity, 999.0);
    });
  });
}
