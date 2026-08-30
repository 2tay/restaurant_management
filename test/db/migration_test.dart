// The v1 -> v2 migration (Phase 2 employé), checked against drift's schema
// dumps rather than against "the code did not throw".
//
// `drift_schema_v1.json` was captured before the tables changed;
// `drift_schema_v2.json` after. `SchemaVerifier` builds a database at the old
// shape, runs `AppDatabase.migration`, and asserts the result matches the new
// shape column for column and index for index.
//
// Regenerate the helpers with:
//   dart run drift_dev schema generate lib/data/database/migrations/ test/db/schema/

import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/data/database/app_database.dart';

import '../support/sqlite.dart';
import 'schema/schema.dart';

void main() {
  setUpAll(useTestSqlite);

  late SchemaVerifier verifier;

  setUp(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('a fresh database matches the version 2 schema', () async {
    final connection = await verifier.startAt(2);
    final db = AppDatabase.withExecutor(connection);
    await verifier.migrateAndValidate(db, 2);
    await db.close();
  });

  test('a version 1 install upgrades to version 2 cleanly', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase.withExecutor(connection);

    // Runs AppDatabase.migration.onUpgrade(1 -> 2) and then checks every table,
    // column, default and index against drift_schema_v2.json.
    await verifier.migrateAndValidate(db, 2);
    await db.close();
  });
}
