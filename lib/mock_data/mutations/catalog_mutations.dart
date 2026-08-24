import '../../models/models.dart';
import '../mock_categories.dart';
import '../mock_queries.dart';
import '../mock_units.dart';
import 'mock_write.dart';

/// Writes against the catalogue — categories and units of measure.
///
/// These are the two things the brief insists the user creates rather than
/// receives: a Belgian kitchen counts beer in `bac` and produce in `caisse`,
/// and no shipped list would have guessed that.
///
/// Two rules run through everything here:
///
/// 1. **Names are unique within a store, ignoring case and surrounding space.**
///    Two categories called "Boissons" and "boissons " are one category with a
///    typo, and letting both exist means half the drinks end up filed under the
///    wrong one.
/// 2. **Nothing in use can be deleted.** A category or unit is referenced by
///    id from every item that uses it, so deleting one in use would leave those
///    items pointing at nothing — rendering as "—" with no way for the user to
///    find out what they used to say. The screens check first and explain;
///    these methods refuse as a backstop.
abstract final class CatalogMutations {
  // ---------------------------------------------------------------------------
  // Categories
  // ---------------------------------------------------------------------------

  /// Creates a category and returns it, or null if the name is already taken.
  ///
  /// Returning the record rather than a bare success flag is what lets the item
  /// form select what the user just created — the whole point of the inline
  /// "+ Créer" row is that they do not lose their place.
  static Category? createCategory({
    required String storeId,
    required String name,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    if (MockQueries.categoryNamed(storeId, trimmed) != null) return null;

    final category = Category(
      id: MockWrite.id('cat'),
      storeId: storeId,
      name: trimmed,
    );
    mockCategories.add(category);
    MockWrite.changed();
    return category;
  }

  /// Renames a category. Returns null when the new name collides.
  static Category? renameCategory(String id, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;

    final index = mockCategories.indexWhere((c) => c.id == id);
    if (index == -1) return null;

    final existing = mockCategories[index];
    // Excluding itself, or renaming "Boissons" to "Boissons" would collide with
    // itself and fail.
    if (MockQueries.categoryNamed(
          existing.storeId,
          trimmed,
          excludingId: id,
        ) !=
        null) {
      return null;
    }

    final renamed = existing.copyWith(name: trimmed);
    mockCategories[index] = renamed;
    MockWrite.changed();
    return renamed;
  }

  /// Deletes a category. Refuses while any item is filed under it.
  static bool deleteCategory(String id) {
    if (MockQueries.itemCountInCategory(id) > 0) return false;
    if (!mockCategories.any((c) => c.id == id)) return false;

    mockCategories.removeWhere((c) => c.id == id);
    MockWrite.changed();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Units
  // ---------------------------------------------------------------------------

  /// Creates a unit and returns it, or null if the name or the abbreviation is
  /// already taken.
  ///
  /// The abbreviation is checked as well as the name because it is what appears
  /// next to every quantity in the app. Two units abbreviated "cs" would make
  /// the inventory list unreadable however different their full names were.
  static UnitOfMeasure? createUnit({
    required String storeId,
    required String name,
    required String abbreviation,
  }) {
    final trimmedName = name.trim();
    final trimmedAbbreviation = abbreviation.trim();
    if (trimmedName.isEmpty || trimmedAbbreviation.isEmpty) return null;
    if (MockQueries.unitNamed(storeId, trimmedName) != null) return null;
    if (MockQueries.unitAbbreviated(storeId, trimmedAbbreviation) != null) {
      return null;
    }

    final unit = UnitOfMeasure(
      id: MockWrite.id('unit'),
      storeId: storeId,
      name: trimmedName,
      abbreviation: trimmedAbbreviation,
    );
    mockUnits.add(unit);
    MockWrite.changed();
    return unit;
  }

  /// Renames a unit or changes its abbreviation. Null when either collides.
  static UnitOfMeasure? updateUnit(
    String id, {
    required String name,
    required String abbreviation,
  }) {
    final trimmedName = name.trim();
    final trimmedAbbreviation = abbreviation.trim();
    if (trimmedName.isEmpty || trimmedAbbreviation.isEmpty) return null;

    final index = mockUnits.indexWhere((u) => u.id == id);
    if (index == -1) return null;

    final existing = mockUnits[index];
    if (MockQueries.unitNamed(
          existing.storeId,
          trimmedName,
          excludingId: id,
        ) !=
        null) {
      return null;
    }
    if (MockQueries.unitAbbreviated(
          existing.storeId,
          trimmedAbbreviation,
          excludingId: id,
        ) !=
        null) {
      return null;
    }

    final updated = existing.copyWith(
      name: trimmedName,
      abbreviation: trimmedAbbreviation,
    );
    mockUnits[index] = updated;
    MockWrite.changed();
    return updated;
  }

  /// Deletes a unit. Refuses while any item is measured in it.
  static bool deleteUnit(String id) {
    if (MockQueries.itemCountUsingUnit(id) > 0) return false;
    if (!mockUnits.any((u) => u.id == id)) return false;

    mockUnits.removeWhere((u) => u.id == id);
    MockWrite.changed();
    return true;
  }
}
