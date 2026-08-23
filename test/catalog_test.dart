// Categories and units — the two things the brief insists the user creates
// rather than receives.
//
// Two rules run through all of it: names are unique within a store ignoring
// case and space, and nothing in use can be deleted.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/mock_data/mock_data.dart';

import 'support/mock_reset.dart';

void main() {
  setUp(restoreMockData);

  group('creating a category', () {
    test('adds it to the store and returns it', () {
      final before = MockQueries.categoriesForStore(StoreIds.sablon).length;

      final created = CatalogMutations.createCategory(
        storeId: StoreIds.sablon,
        name: 'Pâtisserie',
      );

      expect(created, isNotNull);
      expect(created!.name, 'Pâtisserie');
      expect(created.storeId, StoreIds.sablon);
      expect(
        MockQueries.categoriesForStore(StoreIds.sablon).length,
        before + 1,
      );
      // Returning the record is what lets the item form select what the user
      // just created without leaving the form.
      expect(MockQueries.categoryById(created.id), isNotNull);
    });

    test('trims the name rather than storing the spaces', () {
      final created = CatalogMutations.createCategory(
        storeId: StoreIds.sablon,
        name: '  Pâtisserie  ',
      );

      expect(created!.name, 'Pâtisserie');
    });

    test('refuses a name already used in the store', () {
      final existing = MockQueries.categoriesForStore(StoreIds.sablon).first;

      expect(
        CatalogMutations.createCategory(
          storeId: StoreIds.sablon,
          name: existing.name,
        ),
        isNull,
      );
    });

    test('compares names ignoring case and surrounding space', () {
      final existing = MockQueries.categoriesForStore(StoreIds.sablon).first;

      expect(
        CatalogMutations.createCategory(
          storeId: StoreIds.sablon,
          name: '  ${existing.name.toUpperCase()} ',
        ),
        isNull,
        reason: '"Boissons" and "boissons " are one category with a typo',
      );
    });

    test('allows the same name in a different store', () {
      final existing = MockQueries.categoriesForStore(StoreIds.sablon).first;

      expect(
        CatalogMutations.createCategory(
          storeId: StoreIds.liege,
          name: existing.name,
        ),
        isNotNull,
        reason: 'categories are per-store; two shops can both have Boissons',
      );
    });

    test('refuses an empty name', () {
      expect(
        CatalogMutations.createCategory(storeId: StoreIds.sablon, name: '   '),
        isNull,
      );
    });
  });

  group('renaming a category', () {
    test('changes the name in place', () {
      final category = MockQueries.categoriesForStore(StoreIds.sablon).first;

      final renamed = CatalogMutations.renameCategory(
        category.id,
        'Boissons froides',
      );

      expect(renamed, isNotNull);
      expect(MockQueries.categoryById(category.id)!.name, 'Boissons froides');
      expect(renamed!.id, category.id, reason: 'a rename is not a new record');
    });

    test('does not collide with itself', () {
      final category = MockQueries.categoriesForStore(StoreIds.sablon).first;

      // Re-saving the same name, or only changing its case, has to work.
      expect(
        CatalogMutations.renameCategory(category.id, category.name),
        isNotNull,
      );
      expect(
        CatalogMutations.renameCategory(
          category.id,
          category.name.toUpperCase(),
        ),
        isNotNull,
      );
    });

    test('refuses a name another category already has', () {
      final categories = MockQueries.categoriesForStore(StoreIds.sablon);

      expect(
        CatalogMutations.renameCategory(
          categories.first.id,
          categories[1].name,
        ),
        isNull,
      );
      expect(
        MockQueries.categoryById(categories.first.id)!.name,
        categories.first.name,
        reason: 'a refused rename must not half-apply',
      );
    });
  });

  group('deleting a category', () {
    test('is refused while items are filed under it', () {
      final inUse = MockQueries.categoriesForStore(
        StoreIds.sablon,
      ).firstWhere((c) => MockQueries.itemCountInCategory(c.id) > 0);

      expect(CatalogMutations.deleteCategory(inUse.id), isFalse);
      expect(MockQueries.categoryById(inUse.id), isNotNull);
    });

    test('succeeds once nothing references it', () {
      final created = CatalogMutations.createCategory(
        storeId: StoreIds.sablon,
        name: 'Pâtisserie',
      )!;

      expect(MockQueries.itemCountInCategory(created.id), 0);
      expect(CatalogMutations.deleteCategory(created.id), isTrue);
      expect(MockQueries.categoryById(created.id), isNull);
    });

    test('leaves no item pointing at a category that no longer exists', () {
      for (final category in List.of(mockCategories)) {
        CatalogMutations.deleteCategory(category.id);
      }

      for (final item in mockItems) {
        expect(
          MockQueries.categoryById(item.categoryId),
          isNotNull,
          reason:
              '${item.name} was orphaned by a delete that should have '
              'been refused',
        );
      }
    });
  });

  group('creating a unit', () {
    test('stores the name and the abbreviation', () {
      final created = CatalogMutations.createUnit(
        storeId: StoreIds.sablon,
        name: 'Cageot',
        abbreviation: 'cag',
      );

      expect(created, isNotNull);
      expect(created!.name, 'Cageot');
      expect(created.abbreviation, 'cag');
    });

    test('refuses a duplicate name', () {
      final existing = MockQueries.unitsForStore(StoreIds.sablon).first;

      expect(
        CatalogMutations.createUnit(
          storeId: StoreIds.sablon,
          name: existing.name,
          abbreviation: 'zzz',
        ),
        isNull,
      );
    });

    test('refuses a duplicate abbreviation even under a different name', () {
      final existing = MockQueries.unitsForStore(StoreIds.sablon).first;

      // The abbreviation is what appears next to every quantity in the app;
      // two units sharing one would make the inventory list unreadable.
      expect(
        CatalogMutations.createUnit(
          storeId: StoreIds.sablon,
          name: 'Une unité au nom unique',
          abbreviation: existing.abbreviation,
        ),
        isNull,
      );
    });

    test('refuses a missing abbreviation', () {
      expect(
        CatalogMutations.createUnit(
          storeId: StoreIds.sablon,
          name: 'Cageot',
          abbreviation: '  ',
        ),
        isNull,
      );
    });
  });

  group('updating a unit', () {
    test('changes both fields in place', () {
      final unit = MockQueries.unitsForStore(StoreIds.sablon).first;

      final updated = CatalogMutations.updateUnit(
        unit.id,
        name: 'Kilo',
        abbreviation: 'kilo',
      );

      expect(updated, isNotNull);
      expect(MockQueries.unitById(unit.id)!.name, 'Kilo');
      expect(MockQueries.unitAbbreviationOf(unit.id), 'kilo');
    });

    test('does not collide with itself', () {
      final unit = MockQueries.unitsForStore(StoreIds.sablon).first;

      expect(
        CatalogMutations.updateUnit(
          unit.id,
          name: unit.name,
          abbreviation: unit.abbreviation,
        ),
        isNotNull,
      );
    });

    test('refuses an abbreviation another unit already has', () {
      final units = MockQueries.unitsForStore(StoreIds.sablon);

      expect(
        CatalogMutations.updateUnit(
          units.first.id,
          name: units.first.name,
          abbreviation: units[1].abbreviation,
        ),
        isNull,
      );
      expect(
        MockQueries.unitById(units.first.id)!.abbreviation,
        units.first.abbreviation,
      );
    });
  });

  group('deleting a unit', () {
    test('is refused while items are measured in it', () {
      final inUse = MockQueries.unitsForStore(
        StoreIds.sablon,
      ).firstWhere((u) => MockQueries.itemCountUsingUnit(u.id) > 0);

      expect(CatalogMutations.deleteUnit(inUse.id), isFalse);
      expect(MockQueries.unitById(inUse.id), isNotNull);
    });

    test('succeeds once nothing references it', () {
      final created = CatalogMutations.createUnit(
        storeId: StoreIds.sablon,
        name: 'Cageot',
        abbreviation: 'cag',
      )!;

      expect(CatalogMutations.deleteUnit(created.id), isTrue);
      expect(MockQueries.unitById(created.id), isNull);
    });

    test('leaves no item measured in a unit that no longer exists', () {
      for (final unit in List.of(mockUnits)) {
        CatalogMutations.deleteUnit(unit.id);
      }

      for (final item in mockItems) {
        expect(
          MockQueries.unitById(item.unitId),
          isNotNull,
          reason: '${item.name} lost its unit',
        );
      }
    });
  });

  group('the change signal', () {
    test('fires for a successful write and not for a refused one', () {
      final before = MockWrite.revision.value;

      CatalogMutations.createCategory(
        storeId: StoreIds.sablon,
        name: 'Pâtisserie',
      );
      final afterSuccess = MockWrite.revision.value;
      expect(afterSuccess, greaterThan(before));

      // A refused write changed nothing, so nothing should redraw.
      CatalogMutations.createCategory(
        storeId: StoreIds.sablon,
        name: 'Pâtisserie',
      );
      expect(MockWrite.revision.value, afterSuccess);
    });
  });
}
