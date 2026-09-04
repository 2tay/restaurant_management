import 'package:drift/drift.dart';

import 'stores.dart';

/// A grouping for articles — Légumes, Viandes, Boissons.
///
/// Per store: two establishments keep their own catalogue, and one renaming a
/// category must not rename it for the other.
///
/// Uniqueness of the name within a store is **not** a schema constraint. It is
/// case-folded but not accent-folded (`Épicerie` and `Epicerie` are two
/// categories on purpose), and SQLite's only built-in case-insensitive
/// collation is ASCII-only — so a unique index here would enforce a subtly
/// different rule than the one the app states. It stays in the repository,
/// where it can say so in French.
@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get id => text().withLength(min: 1, max: 64)();
  TextColumn get storeId =>
      text().references(Stores, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A unit of measure — kg, L, pièce.
///
/// [abbreviation] is what appears next to every quantity in the app; [name] is
/// what appears in the picker. Both are the store's own wording.
@DataClassName('UnitRow')
class Units extends Table {
  TextColumn get id => text().withLength(min: 1, max: 64)();
  TextColumn get storeId =>
      text().references(Stores, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get abbreviation => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
