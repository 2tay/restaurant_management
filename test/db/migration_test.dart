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
//   v5 -> v6  `stock_movements.employeeId`, who recorded the movement at the
//             kitchen tablet.
//   v6 -> v7  `goods_receipts.receivedByEmployeeId`, the same for a delivery.
//   v7 -> v8  the four notification preferences on `stores`.
//   v8 -> v9  `items.holidayLowStockThreshold`, the busy-week minimum.
//   v9 -> v10  drops `employees.contract_type` — every employee is now paid an
//              hourly rate.
//   v10 -> v11  a day can now hold several Pointer → Fin de journée cycles:
//               `attendances.clock_in_at` / `.clock_out_at` move onto a new
//               `attendance_sessions` child table, and `attendance_pauses`
//               moves from the day to the session.
//   v11 -> v12  no more fixed hours or heures supp.: drops the schedule
//               columns on `employees` / `attendances`, the store hours and
//               overtime settings on `stores`, and
//               `payroll_periods.total_overtime_hours`.
//   v12 -> v13  vocabulary: `employees.cin` becomes `.pin` (and its unique
//               index), `employee_credentials.pin_hash` becomes
//               `.password_hash`.
//   v13 -> v14  the busy-day calendar: `stores.busyWeekdays`,
//               `.busyReminderDays`, `.notifyBusyDays`, and `busy_dates`.
//   v14 -> v15  ready for sync (SYNC_PLAN.md, Phase 1): `updated_at` and
//               `deleted_at` on every synced table, `store_id` on the child
//               tables, the stock baseline on `items` and `stock_movements`,
//               the `*_touch` triggers, and real password hashes.
//   v15 -> v16  the outbox (SYNC_PLAN.md, Phase 2): the `outbox` table and
//               the `*_outbox_insert` / `*_outbox_update` triggers.
//   v16 -> v17  `sync_errors`, the changes the server refused (Phase 5).
//   v17 -> v18  the `*_touch` triggers stay silent during quiet writes, so a
//               row received from the server keeps its stamp (Phase 6).
//
// The two branches that built v6–v9 each numbered their own steps v6–v9; on
// merging, the stock steps kept those numbers and the pointage steps moved to
// v10–v13. `drift_schema_v10`–`v12.json` were assembled from the pointage
// dumps plus the stock columns (no commit ever held those shapes as code);
// v13 is a dump of the merged code, and the same assembly reproduces it
// exactly.
//
// Regenerate the helpers with:
//   dart run drift_dev schema generate lib/data/database/migrations/ test/db/schema/

import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/database/sync_tables.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';

import '../support/sqlite.dart';
import 'schema/schema.dart';
import 'schema/schema_v3.dart' as v3;
import 'schema/schema_v9.dart' as v9;
import 'schema/schema_v10.dart' as v10;
import 'schema/schema_v11.dart' as v11;
import 'schema/schema_v12.dart' as v12;
import 'schema/schema_v13.dart' as v13;
import 'schema/schema_v14.dart' as v14;
import 'schema/schema_v15.dart' as v15;

void main() {
  setUpAll(useTestSqlite);

  late SchemaVerifier verifier;

  setUp(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('a fresh database matches the version 18 schema', () async {
    final connection = await verifier.startAt(18);
    final db = AppDatabase.withExecutor(connection);
    await verifier.migrateAndValidate(db, 18);
    await db.close();
  });

  // The step every incremental migration gets wrong: an install that skipped a
  // release runs both branches back to back, and `onUpgrade` has to be written
  // so it can. There is no v1 -> v2 test any more, and there cannot be —
  // `schemaVersion` is 18, so an older install is never asked to stop short.
  test('a version 1 install upgrades all the way to version 18', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase.withExecutor(connection);

    await verifier.migrateAndValidate(db, 18);
    await db.close();
  });

  test('a version 2 install upgrades to version 18 cleanly', () async {
    final connection = await verifier.startAt(2);
    final db = AppDatabase.withExecutor(connection);
    await verifier.migrateAndValidate(db, 18);
    await db.close();
  });

  // The column default is what makes the upgrade honest: an article that
  // existed before the maximum did reads zero, which the ordering screen
  // treats as "no ceiling declared" rather than as "order none of this".
  test('maxStock defaults to zero on an upgraded install', () async {
    final connection = await verifier.startAt(2);
    final db = AppDatabase.withExecutor(connection);
    await verifier.migrateAndValidate(db, 18);

    final defaults = await db.customSelect('PRAGMA table_info(items)').get();
    final column = defaults.firstWhere(
      (row) => row.read<String>('name') == 'max_stock',
    );

    expect(column.read<String?>('dflt_value'), '0.0');
    await db.close();
  });

  test('a version 3 install upgrades to version 18 cleanly', () async {
    final connection = await verifier.startAt(3);
    final db = AppDatabase.withExecutor(connection);

    // Runs AppDatabase.migration.onUpgrade(3 -> 13) and then checks every table,
    // column, default and index against drift_schema_v14.json.
    await verifier.migrateAndValidate(db, 18);
    await db.close();
  });

  test('a version 4 install upgrades to version 18 cleanly', () async {
    final connection = await verifier.startAt(4);
    final db = AppDatabase.withExecutor(connection);
    await verifier.migrateAndValidate(db, 18);
    await db.close();
  });

  test('a version 5 install upgrades to version 18 cleanly', () async {
    final connection = await verifier.startAt(5);
    final db = AppDatabase.withExecutor(connection);
    await verifier.migrateAndValidate(db, 18);
    await db.close();
  });

  test('a version 6 install upgrades to version 18 cleanly', () async {
    final connection = await verifier.startAt(6);
    final db = AppDatabase.withExecutor(connection);
    await verifier.migrateAndValidate(db, 18);
    await db.close();
  });

  test('a version 7 install upgrades to version 18 cleanly', () async {
    final connection = await verifier.startAt(7);
    final db = AppDatabase.withExecutor(connection);
    await verifier.migrateAndValidate(db, 18);
    await db.close();
  });

  // The four notification preferences arrive switched to what the preferences
  // screen already displayed — on except deliveries — so an install upgraded in
  // place opens on the settings it appeared to have.
  test(
    'v7 -> v8 gives every store the displayed notification defaults',
    () async {
      final connection = await verifier.startAt(7);
      final db = AppDatabase.withExecutor(connection);
      await verifier.migrateAndValidate(db, 18);

      final columns = await db.customSelect('PRAGMA table_info(stores)').get();
      Object? defaultOf(String name) => columns
          .firstWhere((row) => row.read<String>('name') == name)
          .read<String?>('dflt_value');

      expect(defaultOf('notify_low_stock'), '1');
      expect(defaultOf('notify_price_change'), '1');
      expect(defaultOf('notify_large_adjustment'), '1');
      expect(defaultOf('notify_deliveries'), '0');
      await db.close();
    },
  );

  test('a version 8 install upgrades to version 18 cleanly', () async {
    final connection = await verifier.startAt(8);
    final db = AppDatabase.withExecutor(connection);
    await verifier.migrateAndValidate(db, 18);
    await db.close();
  });

  test('a version 9 install upgrades to version 18 cleanly', () async {
    final connection = await verifier.startAt(9);
    final db = AppDatabase.withExecutor(connection);
    await verifier.migrateAndValidate(db, 18);
    await db.close();
  });

  test('a version 10 install upgrades to version 18 cleanly', () async {
    final connection = await verifier.startAt(10);
    final db = AppDatabase.withExecutor(connection);
    await verifier.migrateAndValidate(db, 18);
    await db.close();
  });

  test('a version 11 install upgrades to version 18 cleanly', () async {
    final connection = await verifier.startAt(11);
    final db = AppDatabase.withExecutor(connection);
    await verifier.migrateAndValidate(db, 18);
    await db.close();
  });

  test('a version 12 install upgrades to version 18 cleanly', () async {
    final connection = await verifier.startAt(12);
    final db = AppDatabase.withExecutor(connection);
    await verifier.migrateAndValidate(db, 18);
    await db.close();
  });

  test('a version 13 install upgrades to version 18 cleanly', () async {
    final connection = await verifier.startAt(13);
    final db = AppDatabase.withExecutor(connection);
    await verifier.migrateAndValidate(db, 18);
    await db.close();
  });

  // An upgraded establishment starts where a new one does: Friday to Sunday,
  // a one-day reminder, the notification on, and no one-off dates.
  test('v13 -> v14 gives existing stores the default calendar', () async {
    final schema = await verifier.schemaAt(13);
    final old = v13.DatabaseAtV13(schema.newConnection());
    await old.customStatement('''
      INSERT INTO stores (id, name, address_line, postal_code, city, phone,
        created_at)
      VALUES ('store-1', 'S', 'a', '1000', 'c', 'p',
        '2026-01-01T00:00:00.000')
    ''');
    await old.close();

    final db = AppDatabase.withExecutor(schema.newConnection());
    await verifier.migrateAndValidate(db, 18);

    final calendar = await CalendarRepository(db).calendar('store-1');
    expect(calendar.weekdays, {DateTime.friday, DateTime.saturday, DateTime.sunday});
    expect(calendar.reminderDays, 1);
    expect(calendar.dates, isEmpty);
    final store = await db.select(db.stores).getSingle();
    expect(store.notifyBusyDays, isTrue);
    await db.close();
  });

  // Null, not zero, and no backfill: null is the meaningful state. It means
  // nobody has set a busy-week minimum, which is what lets the figure be
  // derived as twice the ordinary one and keep following it.
  test('v8 -> v9 leaves every article without a busy-week minimum', () async {
    final connection = await verifier.startAt(8);
    final db = AppDatabase.withExecutor(connection);
    await verifier.migrateAndValidate(db, 18);

    final columns = await db.customSelect('PRAGMA table_info(items)').get();
    final column = columns.firstWhere(
      (row) => row.read<String>('name') == 'holiday_low_stock_threshold',
    );
    expect(column.read<int>('notnull'), 0);
    expect(column.read<String?>('dflt_value'), isNull);
    await db.close();
  });

  // Receipts from before v7 name nobody by id, like the movements before v6.
  test('v6 -> v7 leaves existing receipts with no employee id', () async {
    final connection = await verifier.startAt(6);
    final db = AppDatabase.withExecutor(connection);
    await verifier.migrateAndValidate(db, 18);

    final columns = await db
        .customSelect('PRAGMA table_info(goods_receipts)')
        .get();
    final column = columns.firstWhere(
      (row) => row.read<String>('name') == 'received_by_employee_id',
    );
    expect(column.read<int>('notnull'), 0);
    expect(column.read<String?>('dflt_value'), isNull);
    await db.close();
  });

  // Movements recorded before v6 name nobody by id: the column arrives empty
  // and the name they always carried is untouched.
  test('v5 -> v7 leaves existing movements with no employee id', () async {
    final connection = await verifier.startAt(5);
    final db = AppDatabase.withExecutor(connection);
    await verifier.migrateAndValidate(db, 18);

    final columns = await db
        .customSelect('PRAGMA table_info(stock_movements)')
        .get();
    final column = columns.firstWhere(
      (row) => row.read<String>('name') == 'employee_id',
    );
    expect(column.read<int>('notnull'), 0);
    expect(column.read<String?>('dflt_value'), isNull);
    await db.close();
  });

  test(
    'v12 -> v13 renames CIN to PIN and PIN to password, keeping every value',
    () async {
      final schema = await verifier.schemaAt(12);
      final old = v12.DatabaseAtV12(schema.newConnection());

      await old.customStatement('''
        INSERT INTO stores (id, name, address_line, postal_code, city, phone,
          created_at, max_break_minutes, stale_partial_order_days)
        VALUES ('store-1', 'S', 'x', 'x', 'x', 'x',
          '2026-01-01T00:00:00.000', 30, 7)
      ''');
      await old.customStatement('''
        INSERT INTO employees (id, store_id, first_name, last_name, cin,
          phone, email, hire_date, role, pay, created_at)
        VALUES ('emp-1', 'store-1', 'A', 'B', '78.02.14-153.24', 'p',
          'emp-1@x.c', '2026-01-01T00:00:00.000', 'manager', 15,
          '2026-01-01T00:00:00.000')
      ''');
      await old.customStatement('''
        INSERT INTO employee_credentials (id, employee_id, pin_hash)
        VALUES ('cred-1', 'emp-1', 'pin:1234')
      ''');
      await old.close();

      final db = AppDatabase.withExecutor(schema.newConnection());
      await verifier.migrateAndValidate(db, 18);

      final employee = await db
          .customSelect('SELECT pin FROM employees')
          .getSingle();
      expect(employee.read<String>('pin'), '78.02.14-153.24');

      // The login still works end to end: the renamed hash matches.
      final attempt = await CredentialRepository(
        db,
      ).authenticate('78.02.14-153.24', '1234');
      expect(attempt.outcome, LoginOutcome.success);

      await db.close();
    },
  );

  test(
    'v11 -> v13 drops the fixed hours and overtime, and keeps everything else',
    () async {
      final schema = await verifier.schemaAt(11);
      final old = v11.DatabaseAtV11(schema.newConnection());

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
      await verifier.migrateAndValidate(db, 18);

      Future<List<String>> columnsOf(String table) async => [
        for (final row
            in await db.customSelect('PRAGMA table_info($table)').get())
          row.read<String>('name'),
      ];
      expect(
        await columnsOf('employees'),
        isNot(
          anyOf(
            contains('scheduled_start_minutes'),
            contains('scheduled_end_minutes'),
          ),
        ),
      );
      expect(
        await columnsOf('attendances'),
        isNot(
          anyOf(
            contains('scheduled_start_minutes'),
            contains('scheduled_end_minutes'),
          ),
        ),
      );
      expect(
        await columnsOf('stores'),
        isNot(
          anyOf(
            contains('open_minutes'),
            contains('close_minutes'),
            contains('overtime_multiplier'),
            contains('working_days_per_month'),
          ),
        ),
      );
      expect(
        await columnsOf('payroll_periods'),
        isNot(contains('total_overtime_hours')),
      );

      final store = await db
          .customSelect('SELECT max_break_minutes m FROM stores')
          .getSingle();
      expect(store.read<int>('m'), 30);
      final employee = await db
          .customSelect('SELECT pay FROM employees')
          .getSingle();
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

  test('v9 -> v13 drops the contract type column', () async {
    final schema = await verifier.schemaAt(9);
    final old = v9.DatabaseAtV9(schema.newConnection());

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
    await verifier.migrateAndValidate(db, 18);

    final columns = await db.customSelect('PRAGMA table_info(employees)').get();
    expect(
      columns.map((row) => row.read<String>('name')),
      isNot(contains('contract_type')),
    );

    final row = await db.customSelect('SELECT pay FROM employees').getSingle();
    expect(row.read<double>('pay'), 2000);

    await db.close();
  });

  test('v10 -> v13 turns each existing day into its first session, and its '
      'pauses along with it', () async {
    final schema = await verifier.schemaAt(10);
    final old = v10.DatabaseAtV10(schema.newConnection());

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
    await verifier.migrateAndValidate(db, 18);

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
  });

  test('v3 -> v13 backfills each day with its break allowance', () async {
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
    await verifier.migrateAndValidate(db, 18);

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
  });
  // Every table is rebuilt in this step, so this one fills a version 14
  // database with a row in every table and checks nothing was lost, the new
  // columns were filled from the right place, and the foreign keys still hold.
  test('v14 -> v15 keeps every row and fills the sync columns', () async {
    final schema = await verifier.schemaAt(14);
    final old = v14.DatabaseAtV14(schema.newConnection());
    const t = "'2026-03-01T10:00:00.000'";
    for (final sql in [
      'INSERT INTO stores (id, name, address_line, postal_code, city, phone, '
          "created_at) VALUES ('s1', 'S', 'a', '1000', 'c', 'p', $t)",
      "INSERT INTO categories (id, store_id, name) VALUES ('c1', 's1', 'C')",
      'INSERT INTO units (id, store_id, name, abbreviation) '
          "VALUES ('u1', 's1', 'Kilo', 'kg')",
      'INSERT INTO items (id, store_id, name, category_id, unit_id, quantity, '
          'low_stock_threshold, updated_at, average_cost) '
          "VALUES ('i1', 's1', 'I', 'c1', 'u1', 42, 5, $t, 2.5)",
      'INSERT INTO suppliers (id, store_id, name, contact_name, email, phone, '
          'address_line, postal_code, city) '
          "VALUES ('f1', 's1', 'F', 'x', 'x', 'x', 'x', 'x', 'x')",
      'INSERT INTO supplier_prices (id, item_id, supplier_id, price_per_unit, '
          "effective_date, is_default) VALUES ('sp1', 'i1', 'f1', 2, $t, 1)",
      'INSERT INTO price_history (id, item_id, supplier_id, old_price, '
          'new_price, changed_at, changed_by_name) '
          "VALUES ('ph1', 'i1', 'f1', 1, 2, $t, 'M')",
      'INSERT INTO stock_movements (id, store_id, item_id, type, quantity, '
          'occurred_at, user_name) '
          "VALUES ('m1', 's1', 'i1', 'stockIn', 7, $t, 'M')",
      'INSERT INTO purchase_orders (id, store_id, supplier_id, reference, '
          'status, created_at) '
          "VALUES ('o1', 's1', 'f1', 'CMD-1', 'received', $t)",
      'INSERT INTO purchase_order_lines (id, order_id, item_id, '
          'quantity_ordered, unit_price, position) '
          "VALUES ('ol1', 'o1', 'i1', 7, 2, 0)",
      'INSERT INTO goods_receipts (id, order_id, store_id, received_at, '
          "received_by_name) VALUES ('r1', 'o1', 's1', $t, 'M')",
      'INSERT INTO goods_receipt_lines (id, receipt_id, item_id, '
          'quantity_ordered, quantity_received, actual_unit_price, position) '
          "VALUES ('rl1', 'r1', 'i1', 7, 7, 2, 0)",
      'INSERT INTO notifications (id, store_id, kind, title, body, created_at) '
          "VALUES ('n1', 's1', 'lowStock', 'T', 'B', $t)",
      'INSERT INTO employees (id, store_id, first_name, last_name, pin, phone, '
          'email, hire_date, role, pay, created_at) '
          "VALUES ('e1', 's1', 'A', 'B', 'PIN-1', 'p', 'e1@x.c', $t, "
          "'manager', 15, $t)",
      'INSERT INTO employee_credentials (id, employee_id, password_hash) '
          "VALUES ('cr1', 'e1', 'password:1234')",
      'INSERT INTO payroll_periods (id, employee_id, store_id, start_date, '
          'end_date, worked_days, total_worked_hours, applied_rate, '
          'computed_amount, status, created_at) '
          "VALUES ('pp1', 'e1', 's1', $t, $t, 1, 8, 15, 120, 'paid', $t)",
      'INSERT INTO attendances (id, store_id, employee_id, date, status) '
          "VALUES ('a1', 's1', 'e1', $t, 'done')",
      'INSERT INTO attendance_sessions (id, attendance_id, position, '
          "clock_in_at) VALUES ('as1', 'a1', 0, $t)",
      'INSERT INTO attendance_pauses (id, session_id, position, start_at) '
          "VALUES ('ap1', 'as1', 0, $t)",
      "INSERT INTO busy_dates (store_id, day) VALUES ('s1', '2026-12-24')",
    ]) {
      await old.customStatement(sql);
    }
    await old.close();

    final db = AppDatabase.withExecutor(schema.newConnection());
    await verifier.migrateAndValidate(db, 18);

    for (final table in SyncTables.synced) {
      final rows = await db.customSelect('SELECT * FROM $table').get();
      expect(rows, hasLength(1), reason: '$table lost or gained a row');
      expect(rows.single.read<String?>('updated_at'), isNotNull, reason: table);
      expect(rows.single.read<String?>('deleted_at'), isNull, reason: table);
    }
    for (final table in SyncTables.withCopiedStore) {
      final row = await db
          .customSelect('SELECT store_id FROM $table')
          .getSingle();
      expect(row.read<String>('store_id'), 's1', reason: table);
    }

    // `updated_at` came from the row's own date, converted to UTC. The raw
    // value had no offset, which SQLite reads as UTC already.
    final store = await db.select(db.stores).getSingle();
    expect(store.updatedAt, DateTime.parse('2026-03-01T10:00:00.000Z'));

    // The stock baseline is today's stock, and the old history is part of it.
    final item = await db.select(db.items).getSingle();
    expect(item.baselineQuantity, 42);
    expect(item.baselineAverageCost, 2.5);
    final movement = await db.select(db.stockMovements).getSingle();
    expect(movement.inBaseline, isTrue);
    expect(await StockLedger(db).rebuildItem('i1'), isFalse);

    // The marker password became a real hash, and it still logs in.
    final credential = await db.select(db.employeeCredentials).getSingle();
    expect(credential.passwordHash, startsWith(r'pbkdf2-sha256$'));
    final login = await CredentialRepository(db).authenticate('PIN-1', '1234');
    expect(login.outcome, LoginOutcome.success);

    // Rebuilding `stores` with foreign keys on would have cascaded; nothing
    // points anywhere it should not.
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);

    // The triggers exist and fire.
    await db.customStatement("UPDATE categories SET name = 'D' WHERE id = 'c1'");
    final category = await db.select(db.categories).getSingle();
    expect(category.updatedAt.year, DateTime.now().year);

    await db.close();
  });

  // What an install already holds is not queued by the upgrade: uploading it
  // is a step of its own (Phase 9). The first change afterwards is.
  test('v15 -> v16 queues nothing old, then queues the next change', () async {
    final schema = await verifier.schemaAt(15);
    final old = v15.DatabaseAtV15(schema.newConnection());
    await old.customStatement('''
      INSERT INTO stores (id, name, address_line, postal_code, city, phone,
        created_at, updated_at)
      VALUES ('s1', 'S', 'a', '1000', 'c', 'p',
        '2026-03-01T10:00:00.000', '2026-03-01T10:00:00.000Z')
    ''');
    await old.customStatement(
      'INSERT INTO categories (id, store_id, name, updated_at) '
      "VALUES ('c1', 's1', 'C', '2026-03-01T10:00:00.000Z')",
    );
    await old.close();

    final db = AppDatabase.withExecutor(schema.newConnection());
    await verifier.migrateAndValidate(db, 18);

    expect(await OutboxRepository(db).pendingCount(), 0);

    await CatalogRepository(db).renameCategory('c1', 'Renommée');
    final pending = await OutboxRepository(db).pending();
    expect(pending.single.changedTable, 'categories');
    expect(pending.single.rowKey, 'c1');
    expect(pending.single.storeId, 's1');

    await db.close();
  });
}
