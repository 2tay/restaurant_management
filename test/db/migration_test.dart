// The migrations, checked against drift's schema dumps rather than against
// "the code did not throw".
//
// Each `drift_schema_vN.json` was captured at that version. `SchemaVerifier`
// builds a database at an old shape, runs `AppDatabase.migration`, and asserts
// the result matches the new shape column for column and index for index.
//
// v1 -> v2 is Phase 2 employé (five tables, five columns on `stores`).
// v2 -> v3 adds `items.maxStock`.
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

  test('a fresh database matches the version 3 schema', () async {
    final connection = await verifier.startAt(3);
    final db = AppDatabase.withExecutor(connection);
    await verifier.migrateAndValidate(db, 3);
    await db.close();
  });

  test('a version 2 install upgrades to version 3 cleanly', () async {
    final connection = await verifier.startAt(2);
    final db = AppDatabase.withExecutor(connection);

    // Runs AppDatabase.migration.onUpgrade(2 -> 3) and then checks every table,
    // column, default and index against drift_schema_v3.json.
    await verifier.migrateAndValidate(db, 3);
    await db.close();
  });

  // The step every incremental migration gets wrong: an install that skipped a
  // release runs both branches back to back, and `onUpgrade` has to be written
  // so it can. There is no v1 -> v2 test any more, and there cannot be —
  // `schemaVersion` is 3, so a v1 install is never asked to stop at 2.
  test('a version 1 install upgrades all the way to version 3', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase.withExecutor(connection);

    await verifier.migrateAndValidate(db, 3);
    await db.close();
  });

  // The column default is what makes the upgrade honest: an article that
  // existed before the maximum did reads zero, which the ordering screen
  // treats as "no ceiling declared" rather than as "order none of this".
  test('maxStock defaults to zero on an upgraded install', () async {
    final connection = await verifier.startAt(2);
    final db = AppDatabase.withExecutor(connection);
    await verifier.migrateAndValidate(db, 3);

    final defaults = await db
        .customSelect('PRAGMA table_info(items)')
        .get();
    final column = defaults.firstWhere(
      (row) => row.read<String>('name') == 'max_stock',
    );

    expect(column.read<String?>('dflt_value'), '0.0');
    await db.close();
  });
}
