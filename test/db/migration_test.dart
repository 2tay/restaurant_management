// The schema migrations, checked against drift's schema dumps rather than
// against "the code did not throw".
//
// Each `drift_schema_v{n}.json` is a dump of the schema at that version.
// `SchemaVerifier` builds a database at an old shape, runs
// `AppDatabase.migration`, and asserts the result matches the new shape column
// for column and index for index.
//
//   v1 -> v2  Phase 2 employé: the Gestion Employée module joins.
//   v2 -> v3  `items.maxStock`, the figure a commande tops up to.
//   v3 -> v4  the three `attendances` columns that freeze a day's evaluation
//             context (retroactivité des réglages).
//   v4 -> v5  `items.imagePath`, the product photo.
//
// Regenerate the helpers with:
//   dart run drift_dev schema generate lib/data/database/migrations/ test/db/schema/

import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/data/database/app_database.dart';

import '../support/sqlite.dart';
import 'schema/schema.dart';
import 'schema/schema_v3.dart' as v3;

void main() {
  setUpAll(useTestSqlite);

  late SchemaVerifier verifier;

  setUp(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('a fresh database matches the version 5 schema', () async {
    final connection = await verifier.startAt(5);
    final db = AppDatabase.withExecutor(connection);
    await verifier.migrateAndValidate(db, 5);
    await db.close();
  });

  // The step every incremental migration gets wrong: an install that skipped a
  // release runs both branches back to back, and `onUpgrade` has to be written
  // so it can. There is no v1 -> v2 test any more, and there cannot be —
  // `schemaVersion` is 5, so an older install is never asked to stop short.
  test('a version 1 install upgrades all the way to version 5', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase.withExecutor(connection);

    await verifier.migrateAndValidate(db, 5);
    await db.close();
  });

  test('a version 2 install upgrades to version 3 cleanly', () async {
    final connection = await verifier.startAt(2);
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
    await verifier.migrateAndValidate(db, 5);

    final defaults = await db
        .customSelect('PRAGMA table_info(items)')
        .get();
    final column = defaults.firstWhere(
      (row) => row.read<String>('name') == 'max_stock',
    );

    expect(column.read<String?>('dflt_value'), '0.0');
    await db.close();
  });

  test('a version 3 install upgrades to version 4 cleanly', () async {
    final connection = await verifier.startAt(3);
    final db = AppDatabase.withExecutor(connection);

    // Runs AppDatabase.migration.onUpgrade(3 -> 4) and then checks every table,
    // column, default and index against drift_schema_v4.json.
    await verifier.migrateAndValidate(db, 4);
    await db.close();
  });

  test('a version 4 install upgrades to version 5 cleanly', () async {
    final connection = await verifier.startAt(4);
    final db = AppDatabase.withExecutor(connection);
    await verifier.migrateAndValidate(db, 5);
    await db.close();
  });

  test(
    'v3 -> v4 backfills each day with its resolved evaluation context',
    () async {
      final schema = await verifier.schemaAt(3);
      final old = v3.DatabaseAtV3(schema.newConnection());

      // Raw SQL rather than the (companion-less) generated schema classes.
      // DateTimes are stored as ISO-8601 text — see build.yaml.
      await old.customStatement('''
      INSERT INTO stores (id, name, address_line, postal_code, city, phone,
        created_at, open_minutes, close_minutes, max_break_minutes,
        overtime_multiplier, working_days_per_month, stale_partial_order_days)
      VALUES ('store-1', 'S', 'x', 'x', 'x', 'x',
        '2026-01-01T00:00:00.000', 540, 1320, 45, 1.25, 26, 7)
    ''');
      for (final (id, s, e) in [
        ('emp-store', 'NULL', 'NULL'),
        ('emp-own', '600', '1200'),
      ]) {
        await old.customStatement('''
        INSERT INTO employees (id, store_id, first_name, last_name, cin,
          phone, email, hire_date, role, contract_type, pay,
          scheduled_start_minutes, scheduled_end_minutes, created_at)
        VALUES ('$id', 'store-1', 'A', 'B', '$id', 'p', '$id@x.c',
          '2026-01-01T00:00:00.000', 'staff', 'fixed', 2000, $s, $e,
          '2026-01-01T00:00:00.000')
      ''');
      }
      for (final (id, emp) in [
        ('att-store', 'emp-store'),
        ('att-own', 'emp-own'),
      ]) {
        await old.customStatement('''
        INSERT INTO attendances (id, store_id, employee_id, date, status,
          clock_in_at, clock_out_at)
        VALUES ('$id', 'store-1', '$emp', '2026-02-01T00:00:00.000', 'done',
          '2026-02-01T08:00:00.000', '2026-02-01T17:00:00.000')
      ''');
      }
      await old.close();

      final db = AppDatabase.withExecutor(schema.newConnection());
      await verifier.migrateAndValidate(db, 4);

      final rows = await db
          .customSelect(
            'SELECT id, scheduled_start_minutes s, scheduled_end_minutes e, '
            'max_break_minutes m FROM attendances ORDER BY id',
          )
          .get();
      final byId = {for (final r in rows) r.data['id'] as String: r.data};

      // Employee with no own schedule → the store's hours.
      expect(byId['att-store']!['s'], 540);
      expect(byId['att-store']!['e'], 1320);
      expect(byId['att-store']!['m'], 45);

      // Employee with an own schedule → their hours, store's break allowance.
      expect(byId['att-own']!['s'], 600);
      expect(byId['att-own']!['e'], 1200);
      expect(byId['att-own']!['m'], 45);

      await db.close();
    },
  );
}
