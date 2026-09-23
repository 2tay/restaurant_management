// The employee form (Phase 7): Propriétaire is never assignable from it, and
// an owner being edited keeps the role rather than being demoted by a save.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';

import 'support/app_harness.dart';

const _owner = ValueKey('role-option-owner');
const _manager = ValueKey('role-option-manager');
const _staff = ValueKey('role-option-staff');

Future<void> _open(WidgetTester tester, String path, {Size? size}) async {
  await pumpApp(
    tester,
    size: size ?? const Size(1280, 900),
    asEmployeeId: EmployeeIds.marc,
  );
  appRouter.go(path);
  await tester.pumpAndSettle();
}

void main() {
  testApp('creating offers Gérant and Employé, never Propriétaire', (
    tester,
  ) async {
    await _open(tester, Routes.toAddEmployee(StoreIds.sablon));

    expect(tester.takeException(), isNull);
    expect(find.byKey(_manager), findsOneWidget);
    expect(find.byKey(_staff), findsOneWidget);
    expect(find.byKey(_owner), findsNothing);
  });

  testApp('editing a manager offers the same two roles', (tester) async {
    await _open(
      tester,
      Routes.toEditEmployee(StoreIds.sablon, EmployeeIds.amelie),
    );

    expect(find.byKey(_manager), findsOneWidget);
    expect(find.byKey(_staff), findsOneWidget);
    expect(find.byKey(_owner), findsNothing);
  });

  testApp('editing the owner keeps Propriétaire as the only role', (
    tester,
  ) async {
    await _open(
      tester,
      Routes.toEditEmployee(StoreIds.sablon, EmployeeIds.marc),
    );

    expect(find.byKey(_owner), findsOneWidget);
    expect(find.byKey(_manager), findsNothing);
    expect(find.byKey(_staff), findsNothing);
  });

  testApp('the tightened form has no contract section and fits a phone', (
    tester,
  ) async {
    await _open(
      tester,
      Routes.toAddEmployee(StoreIds.sablon),
      size: const Size(390, 844),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Identité'), findsOneWidget);
    expect(find.text('Contrat et rémunération'), findsNothing);
    expect(find.byKey(_manager), findsOneWidget);
  });
}
