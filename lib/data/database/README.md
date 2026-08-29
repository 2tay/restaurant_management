# Database

The drift schema and the `AppDatabase` class. **Nothing outside `lib/data/` imports this
folder** — screens talk to repositories.

- `app_database.dart` — the `@DriftDatabase` class, `schemaVersion`, and the two
  constructors: the real file one and `AppDatabase.memory()` for tests.
- `tables/` — table definitions, grouped by aggregate.
- `converters/` — `TypeConverter`s for the model enums. Enums are stored as their **name
  string**, never their index: an index shifts the day somebody reorders the enum, and the
  database outlives the source file.
- `migrations/` — the `MigrationStrategy` and drift's generated schema dumps.

## Two things that are easy to get wrong

**Foreign keys are off by default in SQLite.** Every `references()` in `tables/` is
decorative until `PRAGMA foreign_keys = ON` runs in `beforeOpen`. It does.

**`schemaVersion` starts at 1 with a real migration strategy**, not with a
`throw UnimplementedError()`. Phase 3 adds columns; the habit costs nothing now and is
expensive to retrofit onto a database that already has a user's data in it.
