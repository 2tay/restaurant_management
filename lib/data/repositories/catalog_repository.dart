import 'package:drift/drift.dart';

import '../../core/utils/name_matching.dart';
import '../../models/category.dart';
import '../../models/unit_of_measure.dart';
import '../database/app_database.dart';
import '../mappers/mappers.dart';

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
