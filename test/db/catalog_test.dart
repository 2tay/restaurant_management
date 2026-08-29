// Categories and units — the two things the brief insists the user creates
// rather than receives.
//
// Two rules run through all of it: names are unique within an establishment
// ignoring case and space, and nothing in use can be deleted.
//
// Ported from `test/catalog_test.dart` — same tests, same assertions, against a
// database instead of a list. The last group is the exception: Phase 1 checked a
// global revision counter, and there is no such thing any more, so it checks the
// property that counter existed to provide.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/mock_data/mock_data.dart' show StoreIds;
import 'package:stock_inventory/models/models.dart';

import '../support/db_fixture.dart';

void main() {
  late AppDatabase db;
  late CatalogRepository catalog;
  late ItemRepository items;

  setUp(() async {
    db = await openSeededDatabase();
    catalog = CatalogRepository(db);
    items = ItemRepository(db);
  });

  group('creating a category', () {
    test('adds it to the establishment and returns it', () async {
      final before = (await catalog.categories(StoreIds.sablon)).length;

      final created = await catalog.createCategory(
        storeId: StoreIds.sablon,
        name: 'Pâtisserie',
      );

      expect(created, isNotNull);
      expect(created!.name, 'Pâtisserie');
      expect(created.storeId, StoreIds.sablon);
      expect((await catalog.categories(StoreIds.sablon)).length, before + 1);
      // Returning the record is what lets the item form select what the user
      // just created without leaving the form.
      expect(await catalog.category(created.id), isNotNull);
    });

    test('trims the name rather than storing the spaces', () async {
      final created = await catalog.createCategory(
        storeId: StoreIds.sablon,
        name: '  Pâtisserie  ',
      );

      expect(created!.name, 'Pâtisserie');
    });

    test('refuses a name already used in the establishment', () async {
      final existing = (await catalog.categories(StoreIds.sablon)).first;

      expect(
        await catalog.createCategory(
          storeId: StoreIds.sablon,
          name: existing.name,
        ),
        isNull,
      );
    });

    test('compares names ignoring case and surrounding space', () async {
      final existing = (await catalog.categories(StoreIds.sablon)).first;

      expect(
        await catalog.createCategory(
          storeId: StoreIds.sablon,
          name: '  ${existing.name.toUpperCase()} ',
        ),
        isNull,
        reason: '"Boissons" and "boissons " are one category with a typo',
      );
    });

    test('allows the same name in a different establishment', () async {
      // Created here rather than taken from the seed: both establishments
      // already share some category names, which is the point being made, and a
      // name picked out of one store's list is only a fair test if the other
      // store does not happen to have it too.
      const name = 'Pâtisserie';
      expect(
        await catalog.createCategory(storeId: StoreIds.sablon, name: name),
        isNotNull,
      );
      expect(
        await catalog.createCategory(storeId: StoreIds.liege, name: name),
        isNotNull,
        reason: 'categories are per-store; two shops can both have Boissons',
      );
    });

    test('refuses an empty name', () async {
      expect(
        await catalog.createCategory(storeId: StoreIds.sablon, name: '   '),
        isNull,
      );
    });
  });

  group('renaming a category', () {
    test('changes the name in place', () async {
      final category = (await catalog.categories(StoreIds.sablon)).first;

      final renamed = await catalog.renameCategory(
        category.id,
        'Boissons froides',
      );

      expect(renamed, isNotNull);
      expect((await catalog.category(category.id))!.name, 'Boissons froides');
      expect(renamed!.id, category.id, reason: 'a rename is not a new record');
    });

    test('does not collide with itself', () async {
      final category = (await catalog.categories(StoreIds.sablon)).first;

      // Re-saving the same name, or only changing its case, has to work.
      expect(await catalog.renameCategory(category.id, category.name), isNotNull);
      expect(
        await catalog.renameCategory(category.id, category.name.toUpperCase()),
        isNotNull,
      );
    });

    test('refuses a name another category already has', () async {
      final categories = await catalog.categories(StoreIds.sablon);

      expect(
        await catalog.renameCategory(categories.first.id, categories[1].name),
        isNull,
      );
      expect(
        (await catalog.category(categories.first.id))!.name,
        categories.first.name,
        reason: 'a refused rename must not half-apply',
      );
    });
  });

  group('deleting a category', () {
    Future<Category> categoryInUse() async {
      for (final category in await catalog.categories(StoreIds.sablon)) {
        if (await catalog.itemCountInCategory(category.id) > 0) return category;
      }
      throw StateError('the seed has no category in use');
    }

    test('is refused while articles are filed under it', () async {
      final inUse = await categoryInUse();

      expect(await catalog.deleteCategory(inUse.id), isFalse);
      expect(await catalog.category(inUse.id), isNotNull);
    });

    test('succeeds once nothing references it', () async {
      final created = (await catalog.createCategory(
        storeId: StoreIds.sablon,
        name: 'Pâtisserie',
      ))!;

      expect(await catalog.itemCountInCategory(created.id), 0);
      expect(await catalog.deleteCategory(created.id), isTrue);
      expect(await catalog.category(created.id), isNull);
    });

    test('leaves no article pointing at a category that no longer exists',
        () async {
      for (final category in await catalog.categories(StoreIds.sablon)) {
        await catalog.deleteCategory(category.id);
      }

      for (final item in await items.items(StoreIds.sablon)) {
        expect(
          await catalog.category(item.categoryId),
          isNotNull,
          reason: '${item.name} was orphaned by a delete that should have been '
              'refused',
        );
      }
    });
  });

  group('creating a unit', () {
    test('stores the name and the abbreviation', () async {
      final created = await catalog.createUnit(
        storeId: StoreIds.sablon,
        name: 'Cageot',
        abbreviation: 'cag',
      );

      expect(created, isNotNull);
      expect(created!.name, 'Cageot');
      expect(created.abbreviation, 'cag');
    });

    test('refuses a duplicate name', () async {
      final existing = (await catalog.units(StoreIds.sablon)).first;

      expect(
        await catalog.createUnit(
          storeId: StoreIds.sablon,
          name: existing.name,
          abbreviation: 'zzz',
        ),
        isNull,
      );
    });

    test('refuses a duplicate abbreviation even under a different name',
        () async {
      final existing = (await catalog.units(StoreIds.sablon)).first;

      // The abbreviation is what appears next to every quantity in the app; two
      // units sharing one would make the inventory list unreadable.
      expect(
        await catalog.createUnit(
          storeId: StoreIds.sablon,
          name: 'Une unité au nom unique',
          abbreviation: existing.abbreviation,
        ),
        isNull,
      );
    });

    test('refuses a missing abbreviation', () async {
      expect(
        await catalog.createUnit(
          storeId: StoreIds.sablon,
          name: 'Cageot',
          abbreviation: '  ',
        ),
        isNull,
      );
    });
  });

  group('updating a unit', () {
    test('changes both fields in place', () async {
      final unit = (await catalog.units(StoreIds.sablon)).first;

      final updated = await catalog.updateUnit(
        unit.id,
        name: 'Kilo',
        abbreviation: 'kilo',
      );

      expect(updated, isNotNull);
      expect((await catalog.unit(unit.id))!.name, 'Kilo');
      expect((await catalog.unit(unit.id))!.abbreviation, 'kilo');
    });

    test('does not collide with itself', () async {
      final unit = (await catalog.units(StoreIds.sablon)).first;

      expect(
        await catalog.updateUnit(
          unit.id,
          name: unit.name,
          abbreviation: unit.abbreviation,
        ),
        isNotNull,
      );
    });

    test('refuses an abbreviation another unit already has', () async {
      final units = await catalog.units(StoreIds.sablon);

      expect(
        await catalog.updateUnit(
          units.first.id,
          name: units.first.name,
          abbreviation: units[1].abbreviation,
        ),
        isNull,
      );
      expect(
        (await catalog.unit(units.first.id))!.abbreviation,
        units.first.abbreviation,
      );
    });
  });

  group('deleting a unit', () {
    test('is refused while articles are measured in it', () async {
      UnitOfMeasure? inUse;
      for (final unit in await catalog.units(StoreIds.sablon)) {
        if (await catalog.itemCountUsingUnit(unit.id) > 0) {
          inUse = unit;
          break;
        }
      }

      expect(await catalog.deleteUnit(inUse!.id), isFalse);
      expect(await catalog.unit(inUse.id), isNotNull);
    });

    test('succeeds once nothing references it', () async {
      final created = (await catalog.createUnit(
        storeId: StoreIds.sablon,
        name: 'Cageot',
        abbreviation: 'cag',
      ))!;

      expect(await catalog.deleteUnit(created.id), isTrue);
      expect(await catalog.unit(created.id), isNull);
    });

    test('leaves no article measured in a unit that no longer exists', () async {
      for (final unit in await catalog.units(StoreIds.sablon)) {
        await catalog.deleteUnit(unit.id);
      }

      for (final item in await items.items(StoreIds.sablon)) {
        expect(
          await catalog.unit(item.unitId),
          isNotNull,
          reason: '${item.name} lost its unit',
        );
      }
    });
  });

  group('the change signal', () {
    // Phase 1 bumped a global revision counter after every successful write and
    // left it alone after a refused one, so screens redrew exactly when
    // something had changed. There is no counter now — the database pushes — so
    // what is checked is the property the counter existed to provide.
    test('a successful write reaches a watcher and a refused one does not',
        () async {
      final watcher = catalog.watchCategories(StoreIds.sablon);
      final seen = <int>[];
      final subscription = watcher.listen((rows) => seen.add(rows.length));
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      final initial = seen.length;
      expect(initial, greaterThan(0));

      await catalog.createCategory(
        storeId: StoreIds.sablon,
        name: 'Pâtisserie',
      );
      await pumpEventQueue();
      expect(seen.length, greaterThan(initial));

      final afterSuccess = seen.length;

      // A refused write changed nothing, so nothing should redraw.
      expect(
        await catalog.createCategory(
          storeId: StoreIds.sablon,
          name: 'Pâtisserie',
        ),
        isNull,
      );
      await pumpEventQueue();
      expect(seen.length, afterSuccess);
    });
  });
}
