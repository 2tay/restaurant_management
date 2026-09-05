import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';

import 'support/app_harness.dart';

void main() {
  testApp('attendance history renders cards at a narrow width', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(420, 900));
    appRouter.go(Routes.toAttendanceHistory(StoreIds.sablon));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
