// The pointage kiosk board after the redesign: centered cards without the CIN,
// the employee selector that pins the board to one card, and POINTER as a
// colourless outline action.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';

import 'support/app_harness.dart';

Future<void> _openBoard(WidgetTester tester) async {
  await pumpApp(tester, size: const Size(1280, 800));
  appRouter.go(Routes.toTimeclock(StoreIds.sablon));
  await tester.pumpAndSettle();
}

String _name(String id) {
  final e = mockEmployees.firstWhere((e) => e.id == id);
  return '${e.firstName} ${e.lastName}';
}

void main() {
  testApp('cards show the name but never the CIN', (tester) async {
    await _openBoard(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(EmployeeAvatar), findsWidgets);
    final marc = mockEmployees.firstWhere((e) => e.id == EmployeeIds.marc);
    expect(find.text(_name(EmployeeIds.marc)), findsWidgets);
    expect(find.textContaining(marc.cin), findsNothing);
  });

  testApp('POINTER is an outline action, not a filled colour', (tester) async {
    await _openBoard(tester);
    // Several seeded employees have not clocked in today.
    expect(find.widgetWithText(OutlinedButton, 'POINTER'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'POINTER'), findsNothing);
  });

  testApp('the selector pins the board to one card, then clears back', (
    tester,
  ) async {
    await _openBoard(tester);
    final karim = mockEmployees.firstWhere((e) => e.id == EmployeeIds.karim);

    await tester.tap(find.byType(EmployeeSelector));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, karim.firstName);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('employee-option-${EmployeeIds.karim}')),
    );
    await tester.pumpAndSettle();

    expect(find.text(_name(EmployeeIds.marc)), findsNothing);

    await tester.tap(find.byTooltip('Effacer'));
    await tester.pumpAndSettle();
    expect(find.text(_name(EmployeeIds.marc)), findsWidgets);
  });
}
