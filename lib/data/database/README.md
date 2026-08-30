# Database

The drift schema and the `AppDatabase` class. **Nothing outside `lib/data/` imports this
folder** — screens talk to repositories.

- `app_database.dart` — the `@DriftDatabase` class, `schemaVersion`, and the two
  constructors: the real file one and `AppDatabase.memory()` for tests.
- `tables/` — table definitions, grouped by aggregate.
- `migrations/` — drift's generated schema dumps, from the second schema version onward.
  The `MigrationStrategy` itself is ten lines and lives in `app_database.dart`.

There is no `converters/`. The five stored enums use drift's `textEnum`, which already
stores them as their **name string** — the property that mattered, since an index shifts
the day somebody reorders the enum and the database outlives the source file. Hand-written
`TypeConverter`s would be the same behaviour spelled out at length.

## Two things that are easy to get wrong

**Foreign keys are off by default in SQLite.** Every `references()` in `tables/` is
decorative until `PRAGMA foreign_keys = ON` runs in `beforeOpen`. It does.

**`schemaVersion` starts at 1 with a real migration strategy**, not with a
`throw UnimplementedError()`. Phase 3 adds columns; the habit costs nothing now and is
expensive to retrofit onto a database that already has a user's data in it.
