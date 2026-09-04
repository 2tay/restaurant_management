# Migrations

Schema **version 2** (Phase 2 employé — the Gestion Employée module joined the database).

- `drift_schema_v1.json` / `drift_schema_v2.json` — drift's schema dumps, one per version,
  written by
  `dart run drift_dev schema dump lib/data/database/app_database.dart lib/data/database/migrations/`.
  They are what `test/db/migration_test.dart` opens: build a v1 database, run the migration,
  assert the result matches v2 column for column — rather than asserting the migration code
  did not throw.
- The `MigrationStrategy` itself lives in `app_database.dart`. `Migrator.createTable` does
  **not** create the table's `@TableIndex` entries — they are separate schema objects and
  `onUpgrade` creates them by hand after each table.
- The test helpers under `test/db/schema/` are regenerated with
  `dart run drift_dev schema generate lib/data/database/migrations/ test/db/schema/`.

Bump `schemaVersion` and dump the schema in the **same** commit as the table change: a
schema change that ships without its dump cannot be tested against afterwards, because the
old shape no longer exists anywhere to compare with. Dump v(N) **before** touching the
tables, then v(N+1) after.
