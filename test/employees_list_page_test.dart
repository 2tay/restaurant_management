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

/// The whole row opens the drawer — tap Karim's name in the table.
Future<void> _openKarimFromList(WidgetTester tester) async {
  final name = find.descendant(
    of: find.byType(DataTable),
    matching: find.text(_karim),
  );
  await tester.ensureVisible(name);
  await tester.tap(name);
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

  testApp('the card: identity, status, role, contact, rate, hire date — '
      'stacked vertically', (tester) async {
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
    expect(inCard('Gérant'), findsOneWidget); // the badge — no « Poste »
    expect(inCard('Poste'), findsNothing);
    expect(inCard(amelie.phone), findsOneWidget);
    expect(inCard(amelie.email), findsOneWidget);
    expect(inCard('${Formatters.price(amelie.pay)} /h'), findsOneWidget);
    expect(inCard('Salaire horaire'), findsOneWidget);
    // One foot line: « Embauché le » and the date, in the rate's green.
    final hired = find.descendant(
      of: card,
      matching: find.byKey(const ValueKey('employee-card-hired')),
    );
    // The text's RichText, not the icon's.
    final line = tester.widget<RichText>(
      find.descendant(
        of: hired,
        matching: find.byWidgetPredicate(
          (w) =>
              w is RichText && w.text.toPlainText().contains('Embauché le'),
        ),
      ),
    );
    expect(line.text.toPlainText(), contains('Embauché le'));
    expect(
      line.text.toPlainText(),
      contains(Formatters.date(amelie.hireDate)),
    );
    // Text.rich wraps the span in a root one: root → caption → date.
    final caption = (line.text as TextSpan).children!.single as TextSpan;
    final dateSpan = caption.children!.single as TextSpan;
    expect(dateSpan.style?.color, const Color(0xFF0F766E));

    // Vertical: name, then contact, then the rate, then the foot row.
    double y(String text) => tester.getTopLeft(inCard(text)).dy;
    expect(y(amelie.phone), greaterThan(y('Amélie Vandenberghe')));
    expect(y('Salaire horaire'), greaterThan(y(amelie.email)));
    expect(tester.getTopLeft(hired).dy, greaterThan(y('Salaire horaire')));
    // No hover effect on the card.
    expect(
      tester.widget<AppCard>(
        find.descendant(of: card, matching: find.byType(AppCard)).first,
      ).hoverFeedback,
      isFalse,
    );
    // A little room between each icon and its text.
    final phoneLine = find
        .ancestor(of: inCard(amelie.phone), matching: find.byType(InfoLine))
        .first;
    // The spacer between them (not the icon's own box): no height, 12 wide.
    final gaps = tester
        .widgetList<SizedBox>(
          find.descendant(of: phoneLine, matching: find.byType(SizedBox)),
        )
        .where((box) => box.height == null && box.child == null);
    expect(gaps.map((box) => box.width), [12]);
  });

  testApp('the owner is neither a card nor a table row', (
    tester,
  ) async {
    await _open(tester);
    expect(
      find.byKey(const ValueKey('employee-card-${EmployeeIds.marc}')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('employee-card-${EmployeeIds.amelie}')),
      findsOneWidget,
    );

    await _toList(tester);
    final table = tester.widget<DataTable>(find.byType(DataTable));
    final keys = table.rows.map((r) => r.key);
    expect(
      keys,
      isNot(contains(const ValueKey('employee-row-${EmployeeIds.marc}'))),
    );
    expect(keys, contains(const ValueKey('employee-row-${EmployeeIds.amelie}')));
  });

  testApp("a retired person's row: red badge, red hover", (tester) async {
    final db = await _open(tester);
    await tester.tap(find.byType(FilterPill)); // show the retired
    await tester.pumpAndSettle();
    await _toList(tester);

    final chip = tester.widget<LabelChip>(
      find.byKey(const ValueKey('employee-row-retired')).first,
    );
    expect(chip.foreground, const Color(0xFF8E1B1B));

    final all = await EmployeeRepository(db).employees(StoreIds.sablon);
    final table = tester.widget<DataTable>(find.byType(DataTable));
    for (final row in table.rows) {
      final id = (row.key! as ValueKey<String>).value.replaceFirst(
        'employee-row-',
        '',
      );
      final retired = all.firstWhere((e) => e.id == id).archivedAt != null;
      final hover = row.color?.resolve(const {WidgetState.hovered});
      if (retired) {
        expect(hover!.withValues(alpha: 1), const Color(0xFFC62828));
      } else {
        expect(hover, isNull, reason: id);
      }
    }
  });

  testApp('the ⋮ is green; its menu is white, an icon beside each action', (
    tester,
  ) async {
    await _open(tester);
    final card = find.byKey(const ValueKey('employee-card-${EmployeeIds.karim}'));
    final menu = find.descendant(
      of: card,
      matching: find.byKey(const ValueKey('employee-card-menu')),
    );
    final dots = tester.widget<Icon>(
      find.descendant(of: menu, matching: find.byType(Icon)),
    );
    expect(dots.color, const Color(0xFF0F766E));
    expect(
      tester.widget<PopupMenuButton<Object?>>(menu).color,
      Colors.white,
    );

    // Rounded, with the rate block's green wash on hover.
    final button = tester.widget<PopupMenuButton<Object?>>(menu);
    expect(
      (button.shape! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(12),
    );
    final menuTheme = Theme.of(tester.element(menu));
    expect(menuTheme.hoverColor.a, lessThan(0.2));
    expect(menuTheme.hoverColor.withValues(alpha: 1), const Color(0xFF0F766E));

    await tester.tap(menu);
    await tester.pumpAndSettle();
    for (final label in ['Modifier', 'Retirer']) {
      final item = find.ancestor(
        of: find.text(label),
        matching: find.byType(Row),
      );
      expect(
        find.descendant(of: item.first, matching: find.byType(Icon)),
        findsOneWidget,
        reason: label,
      );
    }
  });

  testApp('the card whose drawer is open keeps the hover outline', (
    tester,
  ) async {
    await _open(tester);
    AppCard cardOf(String id) => tester.widget<AppCard>(
      find
          .descendant(
            of: find.byKey(ValueKey('employee-card-$id')),
            matching: find.byType(AppCard),
          )
          .first,
    );
    expect(cardOf(EmployeeIds.karim).selected, isFalse);

    await tester.tap(find.text(_karim));
    await tester.pumpAndSettle();
    expect(cardOf(EmployeeIds.karim).selected, isTrue);
    expect(cardOf(EmployeeIds.amelie).selected, isFalse);

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(cardOf(EmployeeIds.karim).selected, isFalse);
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

  testApp("a retired employee's card: red dashed outline, badge and rate; "
      'the retirement date instead of the hire date', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.byType(FilterPill)); // show the retired
    await tester.pumpAndSettle();

    final retiredChip = tester.widget<LabelChip>(
      find
          .byWidgetPredicate(
            (w) =>
                w is LabelChip &&
                w.key == const ValueKey('employee-card-status') &&
                w.label == 'Retiré',
          )
          .first,
    );
    const red = Color(0xFF8E1B1B);
    expect(retiredChip.foreground, red);
    // The pill that shows them is red too, while active.
    final pillBox = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(FilterPill),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(
      (pillBox.decoration! as BoxDecoration).color,
      const Color(0xFFFADEDE),
    );

    final cards = tester.widgetList<EmployeeCard>(find.byType(EmployeeCard));
    for (final card in cards) {
      final appCard = tester.widget<AppCard>(
        find
            .descendant(
              of: find.byWidget(card),
              matching: find.byType(AppCard),
            )
            .first,
      );
      final retired = card.employee.archivedAt != null;
      expect(
        appCard.dashedBorderColor,
        retired ? const Color(0xFFC62828) : isNull,
        reason: card.employee.id,
      );
      final scope = find.byWidget(card);
      final rate = tester.widget<HighlightTile>(
        find.descendant(of: scope, matching: find.byType(HighlightTile)),
      );
      expect(
        rate.color,
        retired ? const Color(0xFFC62828) : const Color(0xFF0F766E),
        reason: card.employee.id,
      );
      final retiredLine = find.descendant(
        of: scope,
        matching: find.byKey(const ValueKey('employee-card-retired')),
      );
      final hiredLine = find.descendant(
        of: scope,
        matching: find.byKey(const ValueKey('employee-card-hired')),
      );
      expect(retiredLine, retired ? findsOneWidget : findsNothing);
      expect(hiredLine, retired ? findsNothing : findsOneWidget);
      if (retired) {
        final line = tester.widget<InfoLine>(retiredLine);
        expect(line.text, 'Retiré le');
        expect(line.value, Formatters.date(card.employee.archivedAt!));
        expect(line.valueColor, const Color(0xFFC62828));
      }
    }
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

  testApp('the table: no Détail column, a hire-date column, a hand cursor '
      'on every row', (tester) async {
    final db = await _open(tester);
    await _toList(tester);
    final karim = (await EmployeeRepository(db).employee(EmployeeIds.karim))!;

    final table = tester.widget<DataTable>(find.byType(DataTable));
    final headers = [
      for (final c in table.columns) (c.label as Text).data,
    ];
    expect(headers, isNot(contains('Détail')));
    expect(headers.last, 'Embauché le');
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text(Formatters.date(karim.hireDate)),
      ),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.byIcon(LucideIcons.eye),
      ),
      findsNothing,
    );
    for (final row in table.rows) {
      expect(
        row.mouseCursor?.resolve(const <WidgetState>{}),
        SystemMouseCursors.click,
      );
    }
  });

  testApp('every table: #F5F5F5 header, hairline frame, square corners', (
    tester,
  ) async {
    await _open(tester);
    await _toList(tester);

    final table = tester.widget<DataTable>(find.byType(DataTable));
    expect(
      table.headingRowColor?.resolve(const <WidgetState>{}),
      const Color(0xFFF5F5F5),
    );
    expect(table.dividerThickness, 0.5);
    final frame = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(DataTableWrapper),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = frame.decoration! as BoxDecoration;
    expect(decoration.borderRadius, isNull);
    expect((decoration.border! as Border).top.width, 0.5);

    // No rule under the heading: covered right at the heading's height.
    final cover = find.byKey(const ValueKey('table-heading-rule-cover'));
    expect(cover, findsOneWidget);
    final tableTop = tester.getTopLeft(find.byType(DataTable)).dy;
    final headingHeight = Theme.of(
      tester.element(find.byType(DataTable)),
    ).dataTableTheme.headingRowHeight!;
    expect(tester.getTopLeft(cover).dy - tableTop, headingHeight);
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
