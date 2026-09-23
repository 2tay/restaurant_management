// Personnel (Phase 8): cards or a table behind one toggle, and a click opens
// the employee's detail in a drawer over the roster instead of a new page.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/features/employees/presentation/pages/add_edit_employee_page.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';

import 'support/app_harness.dart';

const _karim = 'Karim Haddouch';

Future<AppDatabase> _open(
  WidgetTester tester, {
  Size size = const Size(1440, 900),
}) async {
  final db = await pumpApp(
    tester,
    size: size,
    asEmployeeId: EmployeeIds.marc,
  );
  appRouter.go(Routes.toEmployees(StoreIds.sablon));
  await tester.pumpAndSettle();
  return db;
}

Future<void> _toList(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Vue liste'));
  await tester.pumpAndSettle();
}

/// A `DataRow` is not a widget, so there is nothing per row to scope a finder
/// to: the eye button is picked by Karim's position among the table's rows.
Future<void> _openKarimFromList(WidgetTester tester) async {
  final table = tester.widget<DataTable>(find.byType(DataTable));
  final index = table.rows.indexWhere(
    (r) => r.key == const ValueKey('employee-row-${EmployeeIds.karim}'),
  );
  expect(index, isNonNegative);
  final eye = find
      .descendant(
        of: find.byType(DataTable),
        matching: find.widgetWithIcon(IconButton, LucideIcons.eye),
      )
      .at(index);
  await tester.ensureVisible(eye);
  await tester.tap(eye);
  await tester.pumpAndSettle();
}

void main() {
  testApp('opens on the card grid, with the toggle on cards', (tester) async {
    await _open(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(ViewModeToggle), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
    expect(find.text(_karim), findsOneWidget);
  });

  testApp('the toggle switches to the table and back', (tester) async {
    await _open(tester);
    await _toList(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('Tarif'), findsOneWidget);
    expect(find.text(_karim), findsOneWidget);

    await tester.tap(find.byTooltip('Vue grille'));
    await tester.pumpAndSettle();
    expect(find.byType(DataTable), findsNothing);
  });

  testApp('a card opens the detail drawer, not a page', (tester) async {
    await _open(tester);
    final location = appRouter.routerDelegate.currentConfiguration.uri
        .toString();

    await tester.tap(find.text(_karim));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(DetailDrawer), findsOneWidget);
    expect(find.text('Coordonnées'), findsOneWidget);
    expect(find.text('karim.haddouch@brasserie-sablon.be'), findsOneWidget);
    // Still on the roster underneath.
    expect(
      appRouter.routerDelegate.currentConfiguration.uri.toString(),
      location,
    );

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(find.byType(DetailDrawer), findsNothing);
  });

  testApp('a table row opens the same drawer', (tester) async {
    await _open(tester);
    await _toList(tester);
    await _openKarimFromList(tester);

    expect(find.byType(DetailDrawer), findsOneWidget);
    expect(find.text('karim.haddouch@brasserie-sablon.be'), findsWidgets);
  });

  testApp('Modifier in the drawer closes it and opens the form', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.text(_karim));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(DetailDrawer),
        matching: find.widgetWithText(SecondaryButton, 'Modifier'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DetailDrawer), findsNothing);
    // The edit form is pushed on top of the roster (a push keeps the base
    // location, so the form is checked for rather than the URL).
    expect(find.byType(AddEditEmployeePage), findsOneWidget);
    expect(find.byKey(const ValueKey('role-option-staff')), findsOneWidget);
  });

  testApp('Retirer in the drawer archives, and the drawer follows', (
    tester,
  ) async {
    final db = await _open(tester);
    await tester.tap(find.text(_karim));
    await tester.pumpAndSettle();

    final retire = find.descendant(
      of: find.byType(DetailDrawer),
      matching: find.widgetWithText(DestructiveButton, 'Retirer'),
    );
    await tester.ensureVisible(retire);
    await tester.tap(retire);
    await tester.pumpAndSettle();
    // The confirmation dialog's own button.
    await tester.tap(find.widgetWithText(FilledButton, 'Retirer').last);
    await tester.pumpAndSettle();

    final karim = await EmployeeRepository(db).employee(EmployeeIds.karim);
    expect(karim!.archivedAt, isNotNull);
    // The open drawer re-renders as archived: Restaurer replaces Retirer.
    expect(
      find.descendant(
        of: find.byType(DetailDrawer),
        matching: find.widgetWithText(SecondaryButton, 'Restaurer'),
      ),
      findsOneWidget,
    );
  });

  testApp('both views and the drawer fit a phone', (tester) async {
    // Opened wide, then narrowed: the start-up screen before Personnel has its
    // own phone-width overflow, which is not what this test is about.
    await _open(tester);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(_karim), findsOneWidget);

    await _toList(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(DataTable), findsOneWidget);

    await _openKarimFromList(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(DetailDrawer), findsOneWidget);
  });
}
