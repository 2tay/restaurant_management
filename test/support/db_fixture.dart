// A database per test.
//
// Replaces `mock_reset.dart`, whose job was to undo one test's writes to a set
// of global lists. There is nothing global to undo any more: each test gets its
// own in-memory database, and it goes away at the end of the test. Isolation by
// construction rather than by cleanup.
//
// In-memory is fast enough that seeding the whole demo dataset in `setUp` costs
// a few milliseconds, which is why every suite can afford a realistic fixture
// instead of a hand-built minimal one.

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/database/meta_keys.dart';
import 'package:stock_inventory/data/seed/demo_seed.dart';
import 'package:stock_inventory/mock_data/mock_employees.dart' show EmployeeIds;

import 'sqlite.dart';

/// The instant a seeded test database reads as having been written.
///
/// Fixed, so the dataset's dates are the same on every run. The mock lists
/// anchor everything to `DateTime.now()` at library load, which is why
/// `mock_data_test.dart` had to open by saying nothing here asserts on dates.
/// Passing the anchor in removes that restriction: "sent three days ago" is now
/// a date a test can name.
final DateTime seedInstant = DateTime(2026, 8, 29, 12);

/// An in-memory database holding the demo dataset.
///
/// Closes itself at the end of the test.
Future<AppDatabase> openSeededDatabase({DateTime? at}) async {
  final AppDatabase db = openEmptyDatabase();
  await seedDemoData(db, at: at ?? seedInstant);

  // Sign the fixture in as the account owner. `MockSession` starts every
  // mock-backed widget test as Marc; this is the database equivalent, so the
  // route / navigation / permission suites need no login step in their bodies.
  await db
      .into(db.meta)
      .insert(
        MetaCompanion.insert(
          key: MetaKeys.currentEmployeeId,
          value: EmployeeIds.marc,
        ),
      );
  return db;
}

/// An in-memory database with the schema and nothing in it.
///
/// Closes itself at the end of the test.
AppDatabase openEmptyDatabase() {
  useTestSqlite();

  // A handful of tests hold two databases at once — comparing two seeds, or
  // seeding a fresh one alongside the fixture. drift warns about that because
  // two database objects sharing one executor race each other and can corrupt
  // the file. These do not share anything: every `NativeDatabase.memory()` is a
  // private connection that ceases to exist at the end of the test.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final AppDatabase db = AppDatabase.memory();
  addTearDown(db.close);
  return db;
}
