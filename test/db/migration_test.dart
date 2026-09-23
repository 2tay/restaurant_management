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
//   v5 -> v6  drops `employees.contract_type` — every employee is now paid an
//             hourly rate.
//   v6 -> v7  a day can now hold several Pointer → Fin de journée cycles:
//             `attendances.clock_in_at` / `.clock_out_at` move onto a new
//             `attendance_sessions` child table, and `attendance_pauses`
//             moves from the day to the session.
//   v7 -> v8  no more fixed hours or heures supp.: drops the schedule columns
//             on `employees` / `attendances`, the store hours and overtime
//             settings on `stores`, and `payroll_periods.total_overtime_hours`.
//
// Regenerate the helpers with:
//   dart run drift_dev schema generate lib/data/database/migrations/ test/db/schema/

import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/data/database/app_database.dart';

import '../support/sqlite.dart';
import 'schema/schema.dart';
import 'schema/schema_v3.dart' as v3;
import 'schema/schema_v5.dart' as v5;
import 'schema/schema_v6.dart' as v6;
import 'schema/schema_v7.dart' as v7;

void main() {
  setUpAll(useTestSqlite);

  late SchemaVerifier verifier;

  setUp(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('a fresh database matches the version 8 schema', () async {
    final connection = await verifier.startAt(8);
    final db = AppDatabase.withExecutor(connection);
    await verifier.migrateAndValidate(db, 8);
    await db.close();
  });

  // The step every incremental migration gets wrong: an install that skipped a
  // release runs both branches back to back, and `onUpgrade` has to be written
  // so it can. There is no v1 -> v2 test any more, and there cannot be —
  // `schemaVersion` is 8, so an older install is never asked to stop short.
  test('a version 1 install upgrades all the way to version 8', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase.withExecutor(connection);

    await verifier.migrateAndValidate(db, 8);
    await db.close();
  });

  test('a version 2 install upgrades to version 8 cleanly', () async {
    final connection = await verifier.startAt(2);
    final db = AppDatabase.withExecutor(connection);
    await verifier.migrateAndValidate(db, 8);
    await db.close();
  });

  // The column default is what makes the upgrade honest: an article that
  // existed before the maximum did reads zero, which the ordering screen
  // treats as "no ceiling declared" rather than as "order none of this".
  test('maxStock defaults to zero on an upgraded install', () async {
    final connection = await verifier.startAt(2);
    final db = AppDatabase.withExecutor(connection);
    await verifier.migrateAndValidate(db, 8);

    final defaults = await db
        .customSelect('PRAGMA table_info(items)')
        .get();
    final column = defaults.firstWhere(
      (row) => row.read<String>('name') == 'max_stock',
    );

    expect(column.read<String?>('dflt_value'), '0.0');
    await db.close();
  });

  test('a version 3 install upgrades to version 8 cleanly', () async {
    final connection = await verifier.startAt(3);
    final db = AppDatabase.withExecutor(connection);

    // Runs AppDatabase.migration.onUpgrade(3 -> 8) and then checks every table,
    // column, default and index against drift_schema_v8.json.
    await verifier.migrateAndValidate(db, 8);
    await db.close();
  });

  test('a version 4 install upgrades to version 8 cleanly', () async {
    final connection = await verifier.startAt(4);
    final db = AppDatabase.withExecutor(connection);
    await verifier.migrateAndValidate(db, 8);
    await db.close();
  });

  test('a version 5 install upgrades to version 8 cleanly', () async {
    final connection = await verifier.startAt(5);
    final db = AppDatabase.withExecutor(connection);
    await verifier.migrateAndValidate(db, 8);
    await db.close();
  });

  test('a version 6 install upgrades to version 8 cleanly', () async {
    final connection = await verifier.startAt(6);
    final db = AppDatabase.withExecutor(connection);
    await verifier.migrateAndValidate(db, 8);
    await db.close();
  });

  test('a version 7 install upgrades to version 8 cleanly', () async {
    final connection = await verifier.startAt(7);
    final db = AppDatabase.withExecutor(connection);
    await verifier.migrateAndValidate(db, 8);
    await db.close();
  });

  test(
    'v7 -> v8 drops the fixed hours and overtime, and keeps everything else',
    () async {
      final schema = await verifier.schemaAt(7);
      final old = v7.DatabaseAtV7(schema.newConnection());

      await old.customStatement('''
        INSERT INTO stores (id, name, address_line, postal_code, city, phone,
          created_at, open_minutes, close_minutes, max_break_minutes,
          overtime_multiplier, working_days_per_month, stale_partial_order_days)
        VALUES ('store-1', 'S', 'x', 'x', 'x', 'x',
          '2026-01-01T00:00:00.000', 480, 1020, 30, 1.25, 26, 7)
      ''');
      await old.customStatement('''
        INSERT INTO employees (id, store_id, first_name, last_name, cin,
          phone, email, hire_date, role, pay, scheduled_start_minutes,
          scheduled_end_minutes, created_at)
        VALUES ('emp-1', 'store-1', 'A', 'B', 'emp-1', 'p', 'emp-1@x.c',
          '2026-01-01T00:00:00.000', 'staff', 15, 600, 1200,
          '2026-01-01T00:00:00.000')
      ''');
      await old.customStatement('''
        INSERT INTO payroll_periods (id, employee_id, store_id, start_date,
          end_date, worked_days, total_worked_hours, total_overtime_hours,
          applied_rate, computed_amount, status, created_at)
        VALUES ('pay-1', 'emp-1', 'store-1', '2026-02-01T00:00:00.000',
          '2026-02-28T00:00:00.000', 1, 9, 1, 15, 135, 'pending',
          '2026-03-01T00:00:00.000')
      ''');
      await old.customStatement('''
        INSERT INTO attendances (id, store_id, employee_id, date, status,
          scheduled_start_minutes, scheduled_end_minutes, max_break_minutes,
          payroll_period_id)
        VALUES ('att-1', 'store-1', 'emp-1', '2026-02-01T00:00:00.000', 'done',
          600, 1200, 30, 'pay-1')
      ''');
      await old.close();

      final db = AppDatabase.withExecutor(schema.newConnection());
      await verifier.migrateAndValidate(db, 8);

      Future<List<String>> columnsOf(String table) async => [
        for (final row
            in await db.customSelect('PRAGMA table_info($table)').get())
          row.read<String>('name'),
      ];
      expect(
        await columnsOf('employees'),
        isNot(anyOf(
          contains('scheduled_start_minutes'),
          contains('scheduled_end_minutes'),
        )),
      );
      expect(
        await columnsOf('attendances'),
        isNot(anyOf(
          contains('scheduled_start_minutes'),
          contains('scheduled_end_minutes'),
        )),
      );
      expect(
        await columnsOf('stores'),
        isNot(anyOf(
          contains('open_minutes'),
          contains('close_minutes'),
          contains('overtime_multiplier'),
          contains('working_days_per_month'),
        )),
      );
      expect(
        await columnsOf('payroll_periods'),
        isNot(contains('total_overtime_hours')),
      );

      final store = await db
          .customSelect('SELECT max_break_minutes m FROM stores')
          .getSingle();
      expect(store.read<int>('m'), 30);
      final employee =
          await db.customSelect('SELECT pay FROM employees').getSingle();
      expect(employee.read<double>('pay'), 15);
      final day = await db
          .customSelect(
            'SELECT max_break_minutes m, payroll_period_id p FROM attendances',
          )
          .getSingle();
      expect(day.read<int>('m'), 30);
      expect(day.read<String>('p'), 'pay-1');
      final period = await db
          .customSelect(
            'SELECT total_worked_hours h, computed_amount a FROM payroll_periods',
          )
          .getSingle();
      expect(period.read<double>('h'), 9);
      expect(period.read<double>('a'), 135);

      await db.close();
    },
  );

  test('v5 -> v8 drops the contract type column', () async {
    final schema = await verifier.schemaAt(5);
    final old = v5.DatabaseAtV5(schema.newConnection());

    await old.customStatement('''
      INSERT INTO stores (id, name, address_line, postal_code, city, phone,
        created_at, open_minutes, close_minutes, max_break_minutes,
        overtime_multiplier, working_days_per_month, stale_partial_order_days)
      VALUES ('store-1', 'S', 'x', 'x', 'x', 'x',
        '2026-01-01T00:00:00.000', 480, 1020, 30, 1.25, 26, 7)
    ''');
    await old.customStatement('''
      INSERT INTO employees (id, store_id, first_name, last_name, cin,
        phone, email, hire_date, role, contract_type, pay, created_at)
      VALUES ('emp-1', 'store-1', 'A', 'B', 'emp-1', 'p', 'emp-1@x.c',
        '2026-01-01T00:00:00.000', 'staff', 'fixed', 2000,
        '2026-01-01T00:00:00.000')
    ''');
    await old.close();

    final db = AppDatabase.withExecutor(schema.newConnection());
    await verifier.migrateAndValidate(db, 8);

    final columns = await db
        .customSelect('PRAGMA table_info(employees)')
        .get();
    expect(
      columns.map((row) => row.read<String>('name')),
      isNot(contains('contract_type')),
    );

    final row = await db.customSelect('SELECT pay FROM employees').getSingle();
    expect(row.read<double>('pay'), 2000);

    await db.close();
  });

  test(
    'v6 -> v8 turns each existing day into its first session, and its '
    'pauses along with it',
    () async {
      final schema = await verifier.schemaAt(6);
      final old = v6.DatabaseAtV6(schema.newConnection());

      await old.customStatement('''
        INSERT INTO stores (id, name, address_line, postal_code, city, phone,
          created_at, open_minutes, close_minutes, max_break_minutes,
          overtime_multiplier, working_days_per_month, stale_partial_order_days)
        VALUES ('store-1', 'S', 'x', 'x', 'x', 'x',
          '2026-01-01T00:00:00.000', 480, 1020, 30, 1.25, 26, 7)
      ''');
      await old.customStatement('''
        INSERT INTO employees (id, store_id, first_name, last_name, cin,
          phone, email, hire_date, role, pay, created_at)
        VALUES ('emp-1', 'store-1', 'A', 'B', 'emp-1', 'p', 'emp-1@x.c',
          '2026-01-01T00:00:00.000', 'staff', 15, '2026-01-01T00:00:00.000')
      ''');
      await old.customStatement('''
        INSERT INTO attendances (id, store_id, employee_id, date, status,
          clock_in_at, clock_out_at)
        VALUES ('att-1', 'store-1', 'emp-1', '2026-02-01T00:00:00.000', 'done',
          '2026-02-01T08:00:00.000', '2026-02-01T17:00:00.000')
      ''');
      await old.customStatement('''
        INSERT INTO attendance_pauses (id, attendance_id, position, start_at, end_at)
        VALUES ('pause-1', 'att-1', 0, '2026-02-01T12:00:00.000',
          '2026-02-01T12:30:00.000')
      ''');
      await old.close();

      final db = AppDatabase.withExecutor(schema.newConnection());
      await verifier.migrateAndValidate(db, 8);

      final sessions = await db
          .customSelect(
            'SELECT attendance_id a, position p, clock_in_at s, clock_out_at e '
            'FROM attendance_sessions',
          )
          .get();
      expect(sessions, hasLength(1));
      expect(sessions.single.read<String>('a'), 'att-1');
      expect(sessions.single.read<int>('p'), 0);
      expect(sessions.single.read<String>('s'), '2026-02-01T08:00:00.000');
      expect(sessions.single.read<String>('e'), '2026-02-01T17:00:00.000');
      const sessionId = 'att-1-session-0';

      final pauses = await db
          .customSelect(
            'SELECT session_id sid, position p, start_at s, end_at e '
            'FROM attendance_pauses',
          )
          .get();
      expect(pauses, hasLength(1));
      expect(pauses.single.read<String>('sid'), sessionId);
      expect(pauses.single.read<int>('p'), 0);

      final attendanceColumns = await db
          .customSelect('PRAGMA table_info(attendances)')
          .get();
      expect(
        attendanceColumns.map((row) => row.read<String>('name')),
        isNot(anyOf(contains('clock_in_at'), contains('clock_out_at'))),
      );

      await db.close();
    },
  );

  test(
    'v3 -> v8 backfills each day with its break allowance',
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
      await verifier.migrateAndValidate(db, 8);

      // The schedule half of the v4 backfill is dropped again by v8; the break
      // allowance is what survives, frozen from the store for every day.
      final rows = await db
          .customSelect(
            'SELECT id, max_break_minutes m FROM attendances ORDER BY id',
          )
          .get();
      final byId = {for (final r in rows) r.data['id'] as String: r.data};

      expect(byId['att-store']!['m'], 45);
      expect(byId['att-own']!['m'], 45);

      await db.close();
    },
  );
}
