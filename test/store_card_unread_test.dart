// The store grid carries each store's bell: an owner with several
// establishments sees which one has something unread before opening it — a
// « Paiement en double » filed in one store does not wait for the owner to
// happen to open that store.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/models/models.dart';

import 'support/app_harness.dart';

const NotificationViewer _owner = (
  id: EmployeeIds.marc,
  role: EmployeeRole.owner,
);

Future<AppDatabase> _openGrid(WidgetTester tester) async {
  final db = await pumpApp(
    tester,
    size: const Size(1400, 900),
    asEmployeeId: EmployeeIds.marc,
  );
  // Only what this test files is unread.
  for (final store in await StoreRepository(db).stores()) {
    await AccountRepository(db).markAllRead(store.id, viewer: _owner);
  }
  appRouter.go(Routes.stores);
  await tester.pumpAndSettle();
  return db;
}

Future<void> _signal(AppDatabase db, String key) => AccountRepository(db).signal(
  storeId: StoreIds.sablon,
  key: key,
  title: 'Paiement en double : Noah',
  body: 'À vérifier.',
  employeeId: EmployeeIds.noah,
);

void main() {
  testApp('a store with nothing unread shows no bell', (tester) async {
    await _openGrid(tester);

    expect(find.byTooltip('1 notification'), findsNothing);
  });

  testApp('a signalement shows on its store card, counted', (tester) async {
    final db = await _openGrid(tester);

    await _signal(db, 'double_payment:a');
    await tester.pumpAndSettle();
    expect(find.byTooltip('1 notification'), findsOneWidget);

    await _signal(db, 'double_payment:b');
    await tester.pumpAndSettle();
    expect(find.byTooltip('2 notifications'), findsOneWidget);
  });

  // The card counts for whoever is signed in: a manager reading the
  // signalement does not clear it from the owner's grid.
  testApp('a manager reading it leaves it on the owner\'s card', (
    tester,
  ) async {
    final db = await _openGrid(tester);
    await _signal(db, 'double_payment:a');
    await AccountRepository(db).markAllRead(
      StoreIds.sablon,
      viewer: (id: EmployeeIds.amelie, role: EmployeeRole.manager),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('1 notification'), findsOneWidget);

    await AccountRepository(db).markAllRead(StoreIds.sablon, viewer: _owner);
    await tester.pumpAndSettle();
    expect(find.byTooltip('1 notification'), findsNothing);
  });
}
