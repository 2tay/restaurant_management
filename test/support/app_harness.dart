// Pumps the whole app against a real database.
//
// The widget suites used to pump `ProviderScope(child: StockInventoryApp())`
// with no overrides, and that was safe only because the data was compiled in:
// every screen read a global list that existed before the test did. From stage
// 8 the shell resolves its establishment through `databaseProvider`, which has
// no default on purpose, so a pump without an override throws before the first
// frame.
//
// One seeded in-memory database per test, closed when the test ends. Seeding is
// a few milliseconds, which buys the route walk a realistic fixture rather than
// a hand-built minimal one — the same trade `db_fixture.dart` makes for the
// data suites.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/app.dart';
import 'package:stock_inventory/data/current_employee.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/providers.dart';
import 'package:stock_inventory/data/repositories/session_repository.dart';
import 'package:stock_inventory/models/employee.dart';

import 'db_fixture.dart';

/// Pumps the app at [size] against a seeded database, and settles it.
///
/// Returns the database so a test can write to it and watch the screen follow.
Future<AppDatabase> pumpApp(
  WidgetTester tester, {
  Size? size,
  String? asEmployeeId,
}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  final AppDatabase db = await openSeededDatabase();
  await pumpAppWith(tester, db, asEmployeeId: asEmployeeId);
  return db;
}

/// A minimal signed-in owner for the shell suites that pump against an empty or
/// deliberately-failing database — one that has no `employees` row to resolve a
/// real session from. The guard only reads `role` and `storeId`.
Employee fakeOwner({String storeId = 'store-sablon'}) => Employee(
  id: 'test-owner',
  storeId: storeId,
  firstName: 'Test',
  lastName: 'Owner',
  cin: '00.00.00-000.00',
  phone: '',
  email: 'test.owner@example.test',
  hireDate: DateTime(2020),
  role: EmployeeRole.owner,
  contractType: ContractType.fixed,
  pay: 0,
  createdAt: DateTime(2020),
);

/// Pumps the app against a database the caller made — an empty one, or one
/// rigged to fail.
///
/// [asEmployeeId] sets the signed-in session `main()` would have hydrated: the
/// seeded owner (`meta.currentEmployeeId`, written by `openSeededDatabase`) by
/// default, or a named employee for the permission suites. Pass the empty
/// string for a signed-out app. [asEmployee] sets the session directly, for a
/// database with no `employees` row to resolve one from.
Future<void> pumpAppWith(
  WidgetTester tester,
  AppDatabase db, {
  String? asEmployeeId,
  Employee? asEmployee,
}) async {
  final session = SessionRepository(db);
  final Employee? employee;
  if (asEmployee != null) {
    employee = asEmployee;
  } else if (asEmployeeId == null) {
    employee = await session.currentEmployee();
  } else if (asEmployeeId.isEmpty) {
    employee = null;
    await session.signOut();
  } else {
    employee = await session.signIn(asEmployeeId);
  }
  seedCurrentEmployeeSnapshot(employee);
  addTearDown(() => seedCurrentEmployeeSnapshot(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const StockInventoryApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// A widget test that pumps the app, and therefore has to put it down again.
///
/// Cancelling a drift query stream schedules a zero-duration timer — drift
/// holds a cancelled query for one turn of the event loop so a quick re-listen
/// reuses it rather than re-preparing the statement. Riverpod cancels every
/// subscription when the `ProviderScope` unmounts, and `flutter_test` unmounts
/// the tree itself once the body returns, then immediately checks that no timer
/// is pending. The check loses that race every time, and the test fails with
/// *"A Timer is still pending even after the widget tree was disposed"* —
/// a true statement about a timer no test asked for.
///
/// `addTearDown` cannot fix it: teardowns run after the invariant check. So the
/// unmount happens here, at the end of the body, followed by a pump that
/// elapses zero time — which is what fires a zero-duration timer under
/// `fake_async`. By the time the framework tears down, there is nothing left
/// holding the database.
///
/// A failing body skips both, deliberately: `flutter_test` stops checking
/// invariants once a test has failed, and a cleanup pump on a broken tree
/// replaces the real failure with a confusing one.
void testApp(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
