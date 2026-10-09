// The notification centre shows signalements (SYNC_PERSONNEL_PLAN.md, step 3):
// a « Personnel » filter, a tap that opens the employee's pointage history,
// and a read that counts for the signed-in role only.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/models/models.dart';

import 'support/app_harness.dart';

const _title = 'Double pointage : Noah';

Future<AppDatabase> _openAsManager(
  WidgetTester tester, {
  Size size = const Size(1400, 900),
}) async {
  final db = await pumpApp(
    tester,
    size: size,
    asEmployeeId: EmployeeIds.amelie,
  );
  await AccountRepository(db).signal(
    storeId: StoreIds.sablon,
    key: 'double_clock_in:test',
    title: _title,
    body: 'Deux arrivées regroupées : à vérifier.',
    employeeId: EmployeeIds.noah,
  );
  appRouter.go(Routes.toNotifications(StoreIds.sablon));
  await tester.pumpAndSettle();
  return db;
}

void main() {
  testApp('a signalement is listed under the « Personnel » filter', (
    tester,
  ) async {
    await _openAsManager(tester);

    expect(find.text(_title), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('notifications-filter-personnel')),
    );
    await tester.pumpAndSettle();

    expect(find.text(_title), findsOneWidget);
  });

  testApp(
    'on a phone the filters and the card fit, and the menu marks it read',
    (tester) async {
      await _openAsManager(tester, size: const Size(390, 844));

      expect(find.text(_title), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('notifications-filter-personnel')),
      );
      await tester.pumpAndSettle();
      expect(find.text(_title), findsOneWidget);

      await tester.tap(find.byTooltip("Plus d'actions").first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marquer comme lue'));
      await tester.pumpAndSettle();

      expect(find.text('Notification marquée comme lue.'), findsOneWidget);
    },
  );

  testApp('tapping it opens the employee history, read for the manager only', (
    tester,
  ) async {
    final db = await _openAsManager(tester);

    await tester.tap(find.text(_title));
    await tester.pumpAndSettle();

    expect(
      appRouter.state.uri.path,
      Routes.toAttendanceHistory(StoreIds.sablon),
    );
    expect(appRouter.state.uri.queryParameters['employee'], EmployeeIds.noah);

    final account = AccountRepository(db);
    final asManager = await account.notifications(
      StoreIds.sablon,
      viewer: (id: EmployeeIds.amelie, role: EmployeeRole.manager),
    );
    final asOwner = await account.notifications(
      StoreIds.sablon,
      viewer: (id: EmployeeIds.marc, role: EmployeeRole.owner),
    );
    bool readIn(List<NotificationItem> items) =>
        items.singleWhere((n) => n.title == _title).isRead;
    expect(readIn(asManager), isTrue);
    expect(readIn(asOwner), isFalse);
  });
}
