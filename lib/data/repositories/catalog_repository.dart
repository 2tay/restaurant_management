import 'package:drift/drift.dart';

import '../../core/utils/name_matching.dart';
import '../../models/category.dart';
import '../../models/unit_of_measure.dart';
import '../database/app_database.dart';
import '../mappers/mappers.dart';
import '../view_models/catalog_row_views.dart';
import 'new_id.dart';

/// Categories and units of measure — the establishment's own vocabulary.
///
/// Both are created by the user inside the app and never hardcoded, which is
/// why every category and unit dropdown carries an inline "+ Créer".
class CatalogRepository {
  const CatalogRepository(this._db);

  final AppDatabase _db;

  // ---------------------------------------------------------------------------
  // Categories
  // ---------------------------------------------------------------------------

  Stream<List<Category>> watchCategories(String storeId) =>
      _categoryQuery(storeId).watch().map(_toCategories);

  Future<List<Category>> categories(String storeId) =>
      _categoryQuery(storeId).get().then(_toCategories);

  Future<Category?> category(String id) =>
      (_db.select(_db.categories)..where((c) => c.id.equals(id)))
          .getSingleOrNull()
          .then((row) => row == null ? null : categoryFromRow(row));

  /// The category of this establishment already using this name, if any.
  ///
  /// [excludingId] lets a rename ignore itself, without which every edit would
  /// fail against the row it is editing.
  ///
  /// The comparison happens in Dart rather than in SQL, and
  /// `core/utils/name_matching.dart` says why: SQLite folds ASCII only, and the
  /// rule here is Unicode case-folding without accent-folding. One
  /// establishment's categories are tens of rows.
  Future<Category?> categoryNamed(
    String storeId,
    String name, {
    String? excludingId,
  }) async {
    final needle = normaliseName(name);
    if (needle.isEmpty) return null;

    for (final category in await categories(storeId)) {
      if (category.id == excludingId) continue;
      if (normaliseName(category.name) == needle) return category;
    }
    return null;
  }

  /// How many articles are filed under this category.
  ///
  /// Every category with the number of articles filed under it.
  ///
  /// What the categories screen draws. It used to count per row, which is one
  /// scan of the article table per category, twice over — the row shows the
  /// count and the delete button checks it.
  ///
  /// `LEFT OUTER JOIN` so an unused category still produces a row: an empty
  /// category is precisely the one that can be deleted, and an inner join would
  /// hide it.
  Stream<List<CategoryRowView>> watchCategoryRows(String storeId) {
    final count = _db.items.id.count();
    final query = _categoryJoin(storeId, count);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          CategoryRowView(
            category: categoryFromRow(row.readTable(_db.categories)),
            itemCount: row.read(count) ?? 0,
          ),
      ],
    );
  }

  /// The number the delete confirmation shows. The schema also refuses the
  /// delete outright — `items.categoryId` is `ON DELETE RESTRICT` — but a
  /// constraint violation cannot say "3 articles utilisent cette catégorie",
  /// and that sentence is the whole point of asking first.
  Future<int> itemCountInCategory(String categoryId) =>
      _countItems(_db.items.categoryId.equals(categoryId));

  // ---------------------------------------------------------------------------
  // Units
  // ---------------------------------------------------------------------------

  Stream<List<UnitOfMeasure>> watchUnits(String storeId) =>
      _unitQuery(storeId).watch().map(_toUnits);

  Future<List<UnitOfMeasure>> units(String storeId) =>
      _unitQuery(storeId).get().then(_toUnits);

  Future<UnitOfMeasure?> unit(String id) =>
      (_db.select(_db.units)..where((u) => u.id.equals(id)))
          .getSingleOrNull()
          .then((row) => row == null ? null : unitFromRow(row));

  Future<UnitOfMeasure?> unitNamed(
    String storeId,
    String name, {
    String? excludingId,
  }) => _findUnit(storeId, name, excludingId, (unit) => unit.name);

  /// The unit of this establishment already using this abbreviation, if any.
  ///
  /// Guarded as well as the name, because the abbreviation is what appears next
  /// to every quantity in the app: two units both abbreviated "cs" would make
  /// the inventory list unreadable however different their full names were.
  Future<UnitOfMeasure?> unitAbbreviated(
    String storeId,
    String abbreviation, {
    String? excludingId,
  }) => _findUnit(
    storeId,
    abbreviation,
    excludingId,
    (unit) => unit.abbreviation,
  );

  Future<int> itemCountUsingUnit(String unitId) =>
      _countItems(_db.items.unitId.equals(unitId));

  /// Every unit with the number of articles measured in it. Same shape and same
  /// reason as [watchCategoryRows].
  Stream<List<UnitRowView>> watchUnitRows(String storeId) {
    final count = _db.items.id.count();
    final query = _unitJoin(storeId, count);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          UnitRowView(
            unit: unitFromRow(row.readTable(_db.units)),
            itemCount: row.read(count) ?? 0,
          ),
      ],
    );
  }


  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------
  //
  // Two rules run through all of them:
  //
  // 1. Names are unique within an establishment, ignoring case and surrounding
  //    space. Two categories called "Boissons" and "boissons " are one category
  //    with a typo, and letting both exist means half the drinks end up filed
  //    under the wrong one.
  // 2. Nothing in use can be deleted. A category or unit is referenced by id
  //    from every article that uses it, so deleting one in use would leave those
  //    articles pointing at nothing. The screens check first and explain; these
  //    refuse as a backstop; the schema refuses as the backstop's backstop.

  /// Creates a category and returns it, or null if the name is already taken.
  ///
  /// Returning the record rather than a bare success flag is what lets the item
  /// form select what the user just created — the whole point of the inline
  /// "+ Créer" row is that they do not lose their place.
  Future<Category?> createCategory({
    required String storeId,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;

    return _db.transaction(() async {
      if (await categoryNamed(storeId, trimmed) != null) return null;

      final category = Category(
        id: newId(),
        storeId: storeId,
        name: trimmed,
      );
      await _db.into(_db.categories).insert(categoryToRow(category));
      return category;
    });
  }

  /// Renames a category. Returns null when the new name collides.
  Future<Category?> renameCategory(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;

    return _db.transaction(() async {
      final existing = await category(id);
      if (existing == null) return null;

      // Excluding itself, or renaming "Boissons" to "Boissons" would collide
      // with the row being renamed and fail.
      final clash = await categoryNamed(
        existing.storeId,
        trimmed,
        excludingId: id,
      );
      if (clash != null) return null;

      final renamed = existing.copyWith(name: trimmed);
      await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(name: Value(trimmed)),
      );
      return renamed;
    });
  }

  /// Deletes a category. Refuses while any article is filed under it.
  Future<bool> deleteCategory(String id) {
    return _db.transaction(() async {
      if (await itemCountInCategory(id) > 0) return false;

      final removed = await (_db.delete(
        _db.categories,
      )..where((c) => c.id.equals(id))).go();
      return removed > 0;
    });
  }

  /// Creates a unit and returns it, or null if the name or the abbreviation is
  /// already taken.
  Future<UnitOfMeasure?> createUnit({
    required String storeId,
    required String name,
    required String abbreviation,
  }) async {
    final trimmedName = name.trim();
    final trimmedAbbreviation = abbreviation.trim();
    if (trimmedName.isEmpty || trimmedAbbreviation.isEmpty) return null;

    return _db.transaction(() async {
      if (await unitNamed(storeId, trimmedName) != null) return null;
      if (await unitAbbreviated(storeId, trimmedAbbreviation) != null) {
        return null;
      }

      final unit = UnitOfMeasure(
        id: newId(),
        storeId: storeId,
        name: trimmedName,
        abbreviation: trimmedAbbreviation,
      );
      await _db.into(_db.units).insert(unitToRow(unit));
      return unit;
    });
  }

  /// Renames a unit or changes its abbreviation. Null when either collides.
  Future<UnitOfMeasure?> updateUnit(
    String id, {
    required String name,
    required String abbreviation,
  }) async {
    final trimmedName = name.trim();
    final trimmedAbbreviation = abbreviation.trim();
    if (trimmedName.isEmpty || trimmedAbbreviation.isEmpty) return null;

    return _db.transaction(() async {
      final existing = await unit(id);
      if (existing == null) return null;

      final nameClash = await unitNamed(
        existing.storeId,
        trimmedName,
        excludingId: id,
      );
      if (nameClash != null) return null;

      final abbreviationClash = await unitAbbreviated(
        existing.storeId,
        trimmedAbbreviation,
        excludingId: id,
      );
      if (abbreviationClash != null) return null;

      await (_db.update(_db.units)..where((u) => u.id.equals(id))).write(
        UnitsCompanion(
          name: Value(trimmedName),
          abbreviation: Value(trimmedAbbreviation),
        ),
      );
      return existing.copyWith(
        name: trimmedName,
        abbreviation: trimmedAbbreviation,
      );
    });
  }

  /// Deletes a unit. Refuses while any article is measured in it.
  Future<bool> deleteUnit(String id) {
    return _db.transaction(() async {
      if (await itemCountUsingUnit(id) > 0) return false;

      final removed = await (_db.delete(
        _db.units,
      )..where((u) => u.id.equals(id))).go();
      return removed > 0;
    });
  }
  // ---------------------------------------------------------------------------

  Future<UnitOfMeasure?> _findUnit(
    String storeId,
    String value,
    String? excludingId,
    String Function(UnitOfMeasure unit) field,
  ) async {
    final needle = normaliseName(value);
    if (needle.isEmpty) return null;

    for (final unit in await units(storeId)) {
      if (unit.id == excludingId) continue;
      if (normaliseName(field(unit)) == needle) return unit;
    }
    return null;
  }

  Future<int> _countItems(Expression<bool> predicate) async {
    final count = _db.items.id.count();
    final query = _db.selectOnly(_db.items)
      ..addColumns([count])
      ..where(predicate);
    return (await query.getSingle()).read(count) ?? 0;
  }

  /// A category's rows joined to its articles, grouped and counted.
  ///
  /// The `ORDER BY` matches [_categoryQuery] so the counted list and the plain
  /// list are in the same order — the two are read side by side, and a screen
  /// that switched between them would reshuffle.
  JoinedSelectStatement<HasResultSet, dynamic> _categoryJoin(
    String storeId,
    Expression<int> count,
  ) {
    final query = _db.select(_db.categories).join([
      leftOuterJoin(_db.items, _db.items.categoryId.equalsExp(_db.categories.id)),
    ]);
    query
      ..where(_db.categories.storeId.equals(storeId))
      ..addColumns([count])
      ..groupBy([_db.categories.id])
      ..orderBy([OrderingTerm(expression: _db.categories.name)]);
    return query;
  }

  JoinedSelectStatement<HasResultSet, dynamic> _unitJoin(
    String storeId,
    Expression<int> count,
  ) {
    final query = _db.select(_db.units).join([
      leftOuterJoin(_db.items, _db.items.unitId.equalsExp(_db.units.id)),
    ]);
    query
      ..where(_db.units.storeId.equals(storeId))
      ..addColumns([count])
      ..groupBy([_db.units.id])
      ..orderBy([OrderingTerm(expression: _db.units.name)]);
    return query;
  }

  SimpleSelectStatement<$CategoriesTable, CategoryRow> _categoryQuery(
    String storeId,
  ) =>
      _db.select(_db.categories)
        ..where((c) => c.storeId.equals(storeId))
        ..orderBy([(c) => OrderingTerm(expression: c.name)]);

  SimpleSelectStatement<$UnitsTable, UnitRow> _unitQuery(String storeId) =>
      _db.select(_db.units)
        ..where((u) => u.storeId.equals(storeId))
        ..orderBy([(u) => OrderingTerm(expression: u.name)]);

  List<Category> _toCategories(List<CategoryRow> rows) =>
      rows.map(categoryFromRow).toList();

  List<UnitOfMeasure> _toUnits(List<UnitRow> rows) =>
      rows.map(unitFromRow).toList();
}
