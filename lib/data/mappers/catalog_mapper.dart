import '../../models/category.dart';
import '../../models/unit_of_measure.dart';
import '../database/app_database.dart';

Category categoryFromRow(CategoryRow row) =>
    Category(id: row.id, storeId: row.storeId, name: row.name);

CategoriesCompanion categoryToRow(Category category) =>
    CategoriesCompanion.insert(
      id: category.id,
      storeId: category.storeId,
      name: category.name,
    );

UnitOfMeasure unitFromRow(UnitRow row) => UnitOfMeasure(
  id: row.id,
  storeId: row.storeId,
  name: row.name,
  abbreviation: row.abbreviation,
);

UnitsCompanion unitToRow(UnitOfMeasure unit) => UnitsCompanion.insert(
  id: unit.id,
  storeId: unit.storeId,
  name: unit.name,
  abbreviation: unit.abbreviation,
);
