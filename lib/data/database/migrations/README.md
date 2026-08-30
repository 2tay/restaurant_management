# Migrations

Empty, and correctly so: the schema is at version 1 and has never been upgraded.

The `MigrationStrategy` itself lives in `app_database.dart` — at ten lines it does not
earn a file. What lands here is what arrives with the *second* version:

- drift's schema dumps, one JSON file per version, written by
  `dart run drift_dev schema dump lib/data/database/app_database.dart lib/data/database/migrations/`.
  They are what lets a test open a version 1 database, run the migration, and assert the
  result matches version 2 — rather than asserting that the migration code did not throw.
- the step-by-step migration functions, once there is more than one step to keep straight.

Bump `schemaVersion` and dump the schema in the **same** commit as the table change. A
schema change that ships without its dump cannot be tested against afterwards, because the
old shape no longer exists anywhere to compare with.
