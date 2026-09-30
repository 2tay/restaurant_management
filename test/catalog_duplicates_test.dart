// Duplicate category names, as two offline tablets can create them
// (SYNC_PLAN.md, Phase 7): the page points them out and merges them.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart'
    show CategoryIds, StoreIds;

import 'support/app_harness.dart';
import 'support/db_fixture.dart';

void main() {
  testApp('a duplicated category is pointed out and merged', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final db = await openSeededDatabase();
    // The seed has "Boissons"; a second tablet created it again offline.
    await db.customStatement(
      'INSERT INTO categories (id, store_id, name, updated_at) '
      "VALUES ('cat-boissons-2', ?, 'Boissons', '2026-09-30T10:00:00.000Z')",
      [StoreIds.sablon],
    );
    await pumpAppWith(tester, db);

    appRouter.go(Routes.toCategories(StoreIds.sablon));
    await tester.pumpAndSettle();

    expect(find.textContaining('existe en double'), findsOneWidget);
    await tester.tap(find.text('Fusionner'));
    await tester.pumpAndSettle();
    // The confirmation's own button.
    await tester.tap(find.text('Fusionner').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('existe en double'), findsNothing);
    final names = (await CatalogRepository(
      db,
    ).categories(StoreIds.sablon)).where((c) => c.name == 'Boissons');
    expect(
      names.single.id,
      CategoryIds.boissons,
      reason: 'the one with articles',
    );
  });
}
