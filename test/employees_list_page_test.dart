// Personnel (Phase 8): cards or a table behind one toggle, and a click opens
// the employee's detail in a drawer over the roster instead of a new page.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/core/utils/formatters.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/features/employees/presentation/widgets/employee_card.dart';
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

  testApp('a 4th KPI: the average hourly rate of the active roster', (
    tester,
  ) async {
    final db = await _open(tester);
    final active = await EmployeeRepository(db).activeEmployees(StoreIds.sablon);
    final average =
        active.map((e) => e.pay).reduce((a, b) => a + b) / active.length;

    final tile = find.byKey(const ValueKey('kpi-average-rate'));
    expect(tile, findsOneWidget);
    expect(
      find.descendant(of: tile, matching: find.text('Tarif moyen')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: tile,
        matching: find.text('${Formatters.price(average)} /h'),
      ),
      findsOneWidget,
    );
  });

  testApp('a 5th KPI: the highest hourly rate', (tester) async {
    final db = await _open(tester);
    final active = await EmployeeRepository(db).activeEmployees(StoreIds.sablon);
    final highest = active.map((e) => e.pay).reduce((a, b) => a > b ? a : b);

    final tile = find.byKey(const ValueKey('kpi-max-rate'));
    expect(
      find.descendant(of: tile, matching: find.text('Tarif max')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: tile,
        matching: find.text('${Formatters.price(highest)} /h'),
      ),
      findsOneWidget,
    );
  });

  testApp('KPI cards: no border, a green icon on a light green disc', (
    tester,
  ) async {
    await _open(tester);
    final tile = find.byKey(const ValueKey('kpi-max-rate'));

    expect(
      tester.widget<AppCard>(
        find.descendant(of: tile, matching: find.byType(AppCard)),
      ).bordered,
      isFalse,
    );
    final icon = tester.widget<Icon>(
      find.descendant(of: tile, matching: find.byType(Icon)),
    );
    expect(icon.color, const Color(0xFF0F766E));
    // …on a translucent green disc.
    final disc = tester.widget<Container>(
      find.ancestor(of: find.byWidget(icon), matching: find.byType(Container))
          .first,
    );
    final discColor = (disc.decoration! as BoxDecoration).color!;
    expect(discColor.a, lessThan(0.3));
  });

  testApp('search: white, #777 placeholder and icon, green on focus', (
    tester,
  ) async {
    await _open(tester);
    final decoration = tester
        .widget<TextField>(
          find.descendant(
            of: find.byType(SearchField),
            matching: find.byType(TextField),
          ),
        )
        .decoration!;

    expect(decoration.fillColor, Colors.white);
    expect(
      (decoration.enabledBorder! as OutlineInputBorder).borderSide,
      BorderSide.none,
    );
    expect(decoration.hintStyle?.color, const Color(0xFF777777));
    const green = Color(0xFF0F766E);
    expect(
      (decoration.focusedBorder! as OutlineInputBorder).borderSide.color,
      green,
    );
    final iconColor = decoration.prefixIconColor! as WidgetStateColor;
    expect(iconColor.resolve(const <WidgetState>{}), const Color(0xFF777777));
    expect(iconColor.resolve(const {WidgetState.focused}), green);
  });

  testApp('view toggle and archived filter: flat and 40dp high', (
    tester,
  ) async {
    await _open(tester);
    expect(tester.getSize(find.byType(ViewModeToggle)).height, 40);
    // Small icons inside the toggle.
    for (final icon in tester.widgetList<Icon>(
      find.descendant(
        of: find.byType(ViewModeToggle),
        matching: find.byType(Icon),
      ),
    )) {
      expect(icon.size, 18); // AppSizing.iconSm, down from 22
    }
    final pill = find.byType(FilterPill);
    expect(tester.getSize(pill).height, 40);
    final toggleBox = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(ViewModeToggle),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((toggleBox.decoration! as BoxDecoration).border, isNull);
  });

  testApp('search, archived filter and view toggle share one line, the '
      'controls under the last KPI', (tester) async {
    await _open(tester);

    final search = tester.getRect(find.byType(SearchField));
    final toggle = tester.getRect(find.byType(ViewModeToggle));
    final kpi = tester.getRect(find.byKey(const ValueKey('kpi-max-rate')));

    // Same line…
    expect((search.center.dy - toggle.center.dy).abs(), lessThan(8));
    // …the toggle's right edge on the 4th KPI's, the search on the left.
    expect((toggle.right - kpi.right).abs(), lessThan(1));
    expect(search.left, lessThan(kpi.left));
    expect(toggle.left, greaterThan(kpi.left - 400));
  });

  testApp('on a phone the two controls move under the search', (tester) async {
    await _open(tester);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();

    final search = tester.getRect(find.byType(SearchField));
    final toggle = tester.getRect(find.byType(ViewModeToggle));
    expect(toggle.top, greaterThan(search.bottom));
  });

  testApp('the card: identity, status, role, contact, rate, hire date, '
      'position — stacked vertically', (tester) async {
    final db = await _open(tester);
    final amelie = (await EmployeeRepository(db).employee(
      EmployeeIds.amelie,
    ))!;
    final card = find.byKey(ValueKey('employee-card-${amelie.id}'));
    Finder inCard(String text) =>
        find.descendant(of: card, matching: find.text(text));

    expect(inCard('Amélie Vandenberghe'), findsOneWidget);
    expect(inCard('PIN ${amelie.pin}'), findsOneWidget);
    expect(inCard('Actif'), findsOneWidget);
    expect(inCard('Gérant'), findsWidgets); // the badge, and « Poste »
    expect(inCard(amelie.phone), findsOneWidget);
    expect(inCard(amelie.email), findsOneWidget);
    expect(inCard('${Formatters.price(amelie.pay)} /h'), findsOneWidget);
    expect(inCard('Salaire horaire'), findsOneWidget);
    expect(inCard('Embauché le'), findsOneWidget);
    expect(inCard(Formatters.date(amelie.hireDate)), findsOneWidget);
    expect(inCard('Poste'), findsOneWidget);

    // Vertical: name, then contact, then the rate, then the foot row.
    double y(String text) => tester.getTopLeft(inCard(text)).dy;
    expect(y(amelie.phone), greaterThan(y('Amélie Vandenberghe')));
    expect(y('Salaire horaire'), greaterThan(y(amelie.email)));
    expect(y('Embauché le'), greaterThan(y('Salaire horaire')));
    // Outlined on hover.
    expect(
      tester.widget<AppCard>(
        find.descendant(of: card, matching: find.byType(AppCard)).first,
      ).outlineOnHover,
      isTrue,
    );
  });

  testApp('the card menu: Modifier opens the edit pop-up', (tester) async {
    await _open(tester);
    final card = find.byKey(const ValueKey('employee-card-${EmployeeIds.karim}'));
    await tester.tap(
      find.descendant(
        of: card,
        matching: find.byKey(const ValueKey('employee-card-menu')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retirer'), findsOneWidget);

    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    expect(find.byType(WizardDialog), findsOneWidget);
    expect(find.byType(DetailDrawer), findsNothing);
  });

  testApp('the card menu: Retirer asks, then archives', (tester) async {
    final db = await _open(tester);
    final card = find.byKey(const ValueKey('employee-card-${EmployeeIds.karim}'));
    await tester.tap(
      find.descendant(
        of: card,
        matching: find.byKey(const ValueKey('employee-card-menu')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retirer'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Retirer').last);
    await tester.pumpAndSettle();

    final karim = await EmployeeRepository(db).employee(EmployeeIds.karim);
    expect(karim!.archivedAt, isNotNull);
  });

  testApp("a retired employee's card says Retiré and offers Restaurer", (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.byType(FilterPill)); // show the retired
    await tester.pumpAndSettle();

    final retired = find.byWidgetPredicate(
      (w) =>
          w is LabelChip &&
          w.key == const ValueKey('employee-card-status') &&
          w.label == 'Retiré',
    );
    expect(retired, findsWidgets);
    final card = find.ancestor(
      of: retired.first,
      matching: find.byType(EmployeeCard),
    );
    await tester.tap(
      find.descendant(
        of: card,
        matching: find.byKey(const ValueKey('employee-card-menu')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Restaurer'), findsOneWidget);
    expect(find.text('Retirer'), findsNothing);
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
    // In the drawer (the card behind shows the email too).
    expect(
      find.descendant(
        of: find.byType(DetailDrawer),
        matching: find.text('karim.haddouch@brasserie-sablon.be'),
      ),
      findsOneWidget,
    );
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

  testApp('Modifier in the drawer closes it and opens the edit pop-up', (
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
    // The edit wizard opens as a pop-up over the roster.
    expect(find.byType(WizardDialog), findsOneWidget);
    expect(
      appRouter.routerDelegate.currentConfiguration.uri.toString(),
      Routes.toEmployees(StoreIds.sablon),
    );
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
