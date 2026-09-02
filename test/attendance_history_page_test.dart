// Historique de pointage after the redesign: the compact table, the employee
// selector filter, and the right-side detail drawer with its timeline.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';

import 'support/app_harness.dart';

Future<void> _open(WidgetTester tester) async {
  await pumpApp(tester, size: const Size(1400, 900));
  appRouter.go(Routes.toAttendanceHistory(StoreIds.sablon));
  await tester.pumpAndSettle();
}

void main() {
  testApp('opens with the compact table and no export button', (tester) async {
    await _open(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Horaires'), findsOneWidget);
    expect(find.text('Alertes'), findsWidgets);
    // The brief forbids an export affordance here.
    expect(find.text('Exporter'), findsNothing);
  });

  testApp('clicking a row opens the detail drawer, Échap-free close works', (
    tester,
  ) async {
    await _open(tester);

    // The row's detail button → drawer.
    expect(find.byTooltip('Voir le détail'), findsWidgets);
    await tester.tap(find.byTooltip('Voir le détail').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    expect(find.byType(DetailDrawer), findsOneWidget);
    expect(find.text('Détail du pointage'), findsOneWidget);
    expect(find.text('Chronologie'), findsOneWidget);
    expect(find.byType(AttendanceTimeline), findsOneWidget);

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(find.byType(DetailDrawer), findsNothing);
  });

  testApp('the employee selector filters the table', (tester) async {
    await _open(tester);

    final karim = mockEmployees.firstWhere((e) => e.id == EmployeeIds.karim);
    await tester.tap(find.byType(EmployeeSelector));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, karim.firstName);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('employee-option-${EmployeeIds.karim}')),
    );
    await tester.pumpAndSettle();

    // Every visible employee cell is Karim now.
    final marc = mockEmployees.firstWhere((e) => e.id == EmployeeIds.marc);
    expect(find.text('${marc.firstName} ${marc.lastName}'), findsNothing);
    expect(
      find.text('${karim.firstName} ${karim.lastName}'),
      findsWidgets,
    );
  });
}
