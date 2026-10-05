// Group F: categories, units, suppliers and settings, and Group G: alerts
// (SYNC_TESTS_PLAN.md).

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/features/catalog/presentation/widgets/duplicate_notice.dart';
import 'package:stock_inventory/models/models.dart';

import '../support/restaurant_tablets.dart';

void main() {
  late Restaurant r;

  setUp(() async => r = await Restaurant.open());

  void offline(List<String> names) {
    for (final n in names) {
      r[n].offline();
    }
  }

  Future<void> backAndSettle() async {
    for (final t in r.tablets.values) {
      t.online();
    }
    await r.settle();
  }

  Future<Item> product(Tablet t, String name, String categoryId) async =>
      (await t.items.create(
        storeId: r.storeId,
        name: name,
        categoryId: categoryId,
        unitId: r.kg.id,
        lowStockThreshold: 1,
      ))!;

  Future<List<DuplicateGroup<Category>>> duplicatesOn(Tablet t) async {
    final categories = await t.catalog.categories(r.storeId);
    final counts = {
      for (final c in categories)
        c.id: await t.catalog.itemCountInCategory(c.id),
    };
    return duplicateGroups(
      categories,
      name: (c) => c.name,
      id: (c) => c.id,
      itemCount: (c) => counts[c.id]!,
    );
  }

  group('F — catalog and settings', () {
    test('F1 — the same category made on two tablets offline is pointed out '
        'everywhere, and one merge fixes it everywhere', () async {
      offline(['Cuisine', 'Bar']);
      final a = (await r['Cuisine'].catalog.createCategory(
        storeId: r.storeId,
        name: 'Épices',
      ))!;
      final b = (await r['Bar'].catalog.createCategory(
        storeId: r.storeId,
        name: 'Épices',
      ))!;
      await product(r['Cuisine'], 'Cumin', a.id);
      await product(r['Bar'], 'Paprika', b.id);
      await backAndSettle();
      for (final t in r.tablets.values) {
        expect(await duplicatesOn(t), hasLength(1), reason: '$t');
      }

      final group = (await duplicatesOn(r['Bureau'])).single;
      for (final other in group.others) {
        expect(
          await r['Bureau'].catalog.mergeCategories(other.id, group.keep.id),
          isTrue,
        );
      }
      await r.settle();
      for (final t in r.tablets.values) {
        expect(await duplicatesOn(t), isEmpty, reason: '$t');
        expect(
          await t.catalog.itemCountInCategory(group.keep.id),
          2,
          reason: '$t',
        );
      }
    });

    test(
      'F2 — a product added offline to a category merged away elsewhere '
      'is not left without a category',
      () async {
        offline(['Cuisine', 'Bar']);
        final a = (await r['Cuisine'].catalog.createCategory(
          storeId: r.storeId,
          name: 'Épices',
        ))!;
        final b = (await r['Bar'].catalog.createCategory(
          storeId: r.storeId,
          name: 'Épices',
        ))!;
        await backAndSettle();
        final group = (await duplicatesOn(r['Bureau'])).single;
        final merged = group.others.single;

        r['Bar'].offline();
        await r['Bureau'].catalog.mergeCategories(merged.id, group.keep.id);
        await r.syncAll();
        final late = await product(r['Bar'], 'Curry', merged.id);
        expect([a.id, b.id], contains(merged.id));
        await backAndSettle();

        for (final t in r.tablets.values) {
          final item = (await t.items.item(late.id))!;
          expect(
            await t.catalog.category(item.categoryId),
            isNotNull,
            reason: '$t: Curry sits in a deleted category',
          );
        }
      },
      skip: knownIssue(
        'F9: a product can end up in a category that another '
        'tablet deleted or merged away',
      ),
    );

    test('F3 — the same unit made on two tablets offline: both kept, merge '
        'works everywhere', () async {
      offline(['Cuisine', 'Bar']);
      final a = (await r['Cuisine'].catalog.createUnit(
        storeId: r.storeId,
        name: 'Botte',
        abbreviation: 'bt',
      ))!;
      final b = (await r['Bar'].catalog.createUnit(
        storeId: r.storeId,
        name: 'Botte',
        abbreviation: 'bt',
      ))!;
      await backAndSettle();
      expect(await r['Bureau'].catalog.units(r.storeId), hasLength(3));
      expect(await r['Bureau'].catalog.mergeUnits(b.id, a.id), isTrue);
      await r.settle();
      for (final t in r.tablets.values) {
        expect(await t.catalog.units(r.storeId), hasLength(2), reason: '$t');
      }
    });

    test(
      'F4 — a category deleted on the office PC while the kitchen filed a '
      'product under it offline',
      () async {
        final herbes = (await r['Bureau'].catalog.createCategory(
          storeId: r.storeId,
          name: 'Herbes',
        ))!;
        await r.settle();
        r['Cuisine'].offline();
        expect(await r['Bureau'].catalog.deleteCategory(herbes.id), isTrue);
        await r.syncAll();
        final persil = await product(r['Cuisine'], 'Persil', herbes.id);
        await backAndSettle();
        for (final t in r.tablets.values) {
          final item = (await t.items.item(persil.id))!;
          expect(
            await t.catalog.category(item.categoryId),
            isNotNull,
            reason: '$t: Persil sits in a deleted category',
          );
        }
      },
      skip: knownIssue(
        'F9: a product can end up in a category that another '
        'tablet deleted or merged away',
      ),
    );

    test('F5 — the same supplier linked to a product on two tablets offline: '
        'one link, and a default', () async {
      offline(['Cuisine', 'Bar']);
      await r['Cuisine'].suppliers.linkItem(
        itemId: r.tomates.id,
        supplierId: r.metro.id,
        pricePerUnit: 2,
      );
      await r['Bar'].suppliers.linkItem(
        itemId: r.tomates.id,
        supplierId: r.metro.id,
        pricePerUnit: 2.2,
      );
      await backAndSettle();
      for (final t in r.tablets.values) {
        expect(
          await t.suppliers.pricesForItem(r.tomates.id),
          hasLength(1),
          reason: '$t',
        );
        expect(
          await t.suppliers.defaultPriceForItem(r.tomates.id),
          isNotNull,
          reason: '$t',
        );
      }
    });

    test(
      'F6 — the default supplier changed on two tablets: one default, the '
      'same everywhere',
      () async {
        final promo = await r['Bureau'].suppliers.create(
          storeId: r.storeId,
          name: 'Promocash',
          contactName: '',
          email: '',
          phone: '',
          addressLine: '',
          postalCode: '',
          city: '',
        );
        final m = (await r['Bureau'].suppliers.linkItem(
          itemId: r.tomates.id,
          supplierId: r.metro.id,
          pricePerUnit: 2,
        ))!;
        final p = (await r['Bureau'].suppliers.linkItem(
          itemId: r.tomates.id,
          supplierId: promo.id,
          pricePerUnit: 1.9,
        ))!;
        await r.settle();
        offline(['Cuisine', 'Bar']);
        await r['Cuisine'].suppliers.setDefault(p.id);
        await r['Bar'].suppliers.setDefault(m.id);
        await backAndSettle();
        for (final t in r.tablets.values) {
          final defaults = [
            for (final price in await t.suppliers.pricesForItem(r.tomates.id))
              if (price.isDefault) price,
          ];
          expect(defaults, hasLength(1), reason: '$t');
        }
      },
      skip: knownIssue(
        'F11: the default supplier lives on each price row; two tablets can each set a different one',
      ),
    );

    test(
      'F7 — two different settings changed on two tablets offline: both '
      'kept',
      () async {
        offline(['Bureau', 'Bar']);
        await r['Bureau'].stores.setStalePartialOrderDays(r.storeId, 9);
        await r['Bar'].calendar.setReminderDays(r.storeId, 5);
        await backAndSettle();
        for (final t in r.tablets.values) {
          expect(
            (await t.stores.settings(r.storeId)).stalePartialOrderDays,
            9,
            reason: '$t',
          );
          final row = await t.db
              .customSelect(
                'SELECT busy_reminder_days FROM stores WHERE id = ?',
                variables: [Variable(r.storeId)],
              )
              .getSingle();
          expect(row.data['busy_reminder_days'], 5, reason: '$t');
        }
      },
      skip: knownIssue(
        'F3: the establishment sends its whole row, the last '
        'one drops the other tablet\'s setting',
      ),
    );

    test(
      'F8 — a busy day marked on two tablets, then unmarked on one',
      () async {
        final day = DateTime(2026, 12, 24);
        offline(['Cuisine', 'Bar']);
        await r['Cuisine'].calendar.toggleDate(r.storeId, day);
        await r['Bar'].calendar.toggleDate(r.storeId, day);
        await backAndSettle();
        for (final t in r.tablets.values) {
          expect((await t.calendar.calendar(r.storeId)).dates, contains(day));
        }
        await r['Bar'].calendar.toggleDate(r.storeId, day);
        await r.settle();
        for (final t in r.tablets.values) {
          expect(
            (await t.calendar.calendar(r.storeId)).dates,
            isNot(contains(day)),
            reason: '$t',
          );
        }
      },
    );
  });

  group('G — alerts', () {
    Future<List<NotificationItem>> alertsFor(Tablet t, Item item) async => [
      for (final n in await AccountRepository(t.db).notifications(r.storeId))
        if (n.relatedItemId == item.id) n,
    ];

    Future<void> takeOut(Tablet t, Item item, double q) =>
        t.movements.recordStockOut(
          storeId: r.storeId,
          itemId: item.id,
          quantity: q,
          reason: StockOutReason.sale,
        );

    test(
      'G1 — a low-stock alert made in the kitchen shows on every tablet',
      () async {
        await takeOut(r['Cuisine'], r.tomates, 8);
        await r.settle();
        for (final t in r.tablets.values) {
          expect(await alertsFor(t, r.tomates), hasLength(1), reason: '$t');
        }
      },
    );

    test(
      'G2 — both tablets cross the threshold offline: the owner sees one '
      'alert',
      () async {
        offline(['Cuisine', 'Bar']);
        await takeOut(r['Cuisine'], r.tomates, 8);
        await takeOut(r['Bar'], r.tomates, 8);
        await backAndSettle();
        expect(await alertsFor(r['Bureau'], r.tomates), hasLength(1));
      },
      skip: knownIssue(
        'F10: each offline tablet makes its own low-stock '
        'alert for the same product',
      ),
    );

    test(
      'G3 — a tablet receiving a stock-out does not make a second alert',
      () async {
        await takeOut(r['Cuisine'], r.tomates, 8);
        await r['Cuisine'].sync();
        await r['Bar'].sync();
        await r.settle();
        expect(await alertsFor(r['Bar'], r.tomates), hasLength(1));
      },
    );

    test('G4 — an alert read on one tablet stays read everywhere', () async {
      await takeOut(r['Cuisine'], r.tomates, 8);
      await r.settle();
      final alert = (await alertsFor(r['Bureau'], r.tomates)).single;
      await AccountRepository(r['Bureau'].db).markRead(alert.id);
      await r.settle();
      await takeOut(r['Bar'], r.tomates, 1);
      await r.settle();
      for (final t in r.tablets.values) {
        final again = (await alertsFor(
          t,
          r.tomates,
        )).where((n) => n.id == alert.id).single;
        expect(again.isRead, isTrue, reason: '$t');
      }
    });

    test('G5 — after the merge takes the stock below zero, the alert is there '
        'and the figures agree with it', () async {
      offline(['Cuisine', 'Bar']);
      await takeOut(r['Cuisine'], r.saumon, 4);
      await takeOut(r['Bar'], r.saumon, 4);
      await backAndSettle();
      expect(await r['Bureau'].stockOf(r.saumon.id), -3);
      expect(await alertsFor(r['Bureau'], r.saumon), isNotEmpty);
    });
  });
}
