// The notification centre shows arrivées and départs: a « Pointage » filter,
// and a tap that opens the employee's pointage history.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/models/models.dart';

import 'support/app_harness.dart';

const _arrival = 'Arrivée : Noah Van Damme';
const _departure = 'Départ : Noah Van Damme';

Future<void> _open(WidgetTester tester) async {
  final db = await pumpApp(tester, size: const Size(1400, 900));
  final account = AccountRepository(db);
  await account.emit(
    storeId: StoreIds.sablon,
    kind: NotificationKind.clockIn,
    key: 'clock_in:test',
    title: _arrival,
    body: 'A pointé à 08:02.',
    relatedEmployeeId: EmployeeIds.noah,
    window: Duration.zero,
  );
  await account.emit(
    storeId: StoreIds.sablon,
    kind: NotificationKind.clockOut,
    key: 'clock_out:test',
    title: _departure,
    body: 'A terminé sa journée à 17:31.',
    relatedEmployeeId: EmployeeIds.noah,
    window: Duration.zero,
  );
  appRouter.go(Routes.toNotifications(StoreIds.sablon));
  await tester.pumpAndSettle();
}

void main() {
  testApp('arrivées and départs are listed under the « Pointage » filter', (
    tester,
  ) async {
    await _open(tester);

    await tester.tap(
      find.byKey(const ValueKey('notifications-filter-pointage')),
    );
    await tester.pumpAndSettle();

    expect(find.text(_arrival), findsOneWidget);
    expect(find.text(_departure), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testApp('tapping an arrivée opens the employee history', (tester) async {
    await _open(tester);

    await tester.tap(find.text(_arrival));
    await tester.pumpAndSettle();

    expect(appRouter.state.uri.path, Routes.toAttendanceHistory(StoreIds.sablon));
    expect(appRouter.state.uri.queryParameters['employee'], EmployeeIds.noah);
  });
}
