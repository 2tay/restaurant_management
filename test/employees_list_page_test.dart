// Personnel (Phase 8): cards or a table behind one toggle, and a click opens
// the employee's detail in a drawer over the roster instead of a new page.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// A card's ⋮ button.
Finder _cardMenu(String employeeId) => find.descendant(
  of: find.byKey(ValueKey('employee-card-$employeeId')),
  matching: find.byKey(const ValueKey('employee-card-menu')),
);

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
    // Not a button: no tap handler, so no hover effect either.
    expect(
      tester.widget<AppCard>(
        find.descendant(of: card, matching: find.byType(AppCard)).first,
      ).onTap,
      isNull,
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

  testApp('the ⋮ menu: exactly the 4 actions, icon left, Retirer in red', (
    tester,
  ) async {
    await _open(tester);
    final menu = _cardMenu(EmployeeIds.karim);
    final dots = tester.widget<Icon>(
      find.descendant(of: menu, matching: find.byType(Icon)),
    );
    expect(dots.color, const Color(0xFF0F766E));

    await tester.tap(menu);
    await tester.pumpAndSettle();

    final items = tester
        .widgetList<MenuItemButton>(find.byType(MenuItemButton))
        .toList();
    expect(
      items.map((i) => (i.key! as ValueKey<String>).value),
      [
        'employee-menu-attendance',
        'employee-menu-payroll',
        'employee-menu-edit',
        'employee-menu-archive',
      ],
    );
    expect(find.text('Voir les détails'), findsNothing);
    for (final item in items) {
      expect(item.leadingIcon, isA<Icon>());
    }
    const red = Color(0xFFC62828);
    final retire = items.last;
    expect((retire.leadingIcon! as Icon).color, red);
    expect(retire.style!.foregroundColor!.resolve(const {}), red);
    // Hover: the rate block's green wash.
    final hover = items.first.style!.overlayColor!.resolve(
      const {WidgetState.hovered},
    )!;
    expect(hover.withValues(alpha: 1), const Color(0xFF0F766E));
    expect(hover.a, lessThan(0.2));
  });

  testApp('the ⋮ menu: white, 12dp corners, hairline border, 190–220dp', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(_cardMenu(EmployeeIds.karim));
    await tester.pumpAndSettle();

    final anchor = tester.widget<MenuAnchor>(
      find.ancestor(
        of: _cardMenu(EmployeeIds.karim),
        matching: find.byType(MenuAnchor),
      ),
    );
    final style = anchor.style!;
    const none = <WidgetState>{};
    expect(style.backgroundColor!.resolve(none), Colors.white);
    final shape = style.shape!.resolve(none)! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(12));
    expect(shape.side.width, 0.5);
    expect(style.elevation!.resolve(none), lessThanOrEqualTo(4));

    final width = tester.getSize(find.byType(MenuItemButton).first).width;
    expect(width, inInclusiveRange(190, 220));
  });

  testApp('the ⋮ menu opens next to its button and stays in the window', (
    tester,
  ) async {
    await _open(tester);
    final button = tester.getRect(_cardMenu(EmployeeIds.karim));
    await tester.tap(_cardMenu(EmployeeIds.karim));
    await tester.pumpAndSettle();

    final first = tester.getRect(find.byType(MenuItemButton).first);
    final last = tester.getRect(find.byType(MenuItemButton).last);
    // Right under the button — or right above it, when there is no room
    // below (the framework keeps the menu in the window).
    final below = (first.top - button.bottom).abs() < 40;
    final above = (button.top - last.bottom).abs() < 40;
    expect(below || above, isTrue);
    final window = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(first.left, greaterThanOrEqualTo(0));
    expect(last.right, lessThanOrEqualTo(window.width));
    expect(last.bottom, lessThanOrEqualTo(window.height));
  });

  testApp('Échap closes the ⋮ menu', (tester) async {
    await _open(tester);
    await tester.tap(_cardMenu(EmployeeIds.karim));
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsWidgets);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
  });

  testApp('a click outside closes the ⋮ menu', (tester) async {
    await _open(tester);
    await tester.tap(_cardMenu(EmployeeIds.karim));
    await tester.pumpAndSettle();

    await tester.tapAt(tester.getTopLeft(find.byType(SearchField)));
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
  });

  testApp("another employee's ⋮ closes this menu and opens theirs at once", (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(_cardMenu(EmployeeIds.karim));
    await tester.pumpAndSettle();
    final karimMenu = tester.getRect(find.byType(MenuItemButton).first);

    // One click on Amélie's ⋮ — not one to close and another to open.
    await tester.tap(_cardMenu(EmployeeIds.amelie));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('employee-menu-edit')), findsOneWidget);
    final ameliesMenu = tester.getRect(find.byType(MenuItemButton).first);
    expect(ameliesMenu, isNot(karimMenu));
    final amelieButton = tester.getRect(_cardMenu(EmployeeIds.amelie));
    final lastItem = tester.getRect(find.byType(MenuItemButton).last);
    expect(
      (ameliesMenu.top - amelieButton.bottom).abs() < 40 ||
          (amelieButton.top - lastItem.bottom).abs() < 40,
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

  testApp('the table: no Détail or PIN column, PIN under the name, a '
      'weekday hire date, rows are not '
      'links', (tester) async {
    final db = await _open(tester);
    await _toList(tester);
    final karim = (await EmployeeRepository(db).employee(EmployeeIds.karim))!;

    final table = tester.widget<DataTable>(find.byType(DataTable));
    final headers = [
      for (final c in table.columns) (c.label as Text).data,
    ];
    expect(headers, isNot(contains('Détail')));
    expect(headers, isNot(contains('PIN')));
    expect(headers[headers.length - 2], 'Embauché le');
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text(Formatters.dateShortWeekday(karim.hireDate)),
      ),
      findsWidgets,
    );
    // The PIN sits under the name, bare — no "PIN" prefix.
    final cell = find.ancestor(
      of: find.text(_karim),
      matching: find.byType(EmployeeCell),
    );
    expect(
      find.descendant(of: cell, matching: find.text(karim.pin)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.textContaining('PIN '),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.byIcon(LucideIcons.eye),
      ),
      findsNothing,
    );
    // Nothing opens on a row click, so no hand cursor.
    for (final row in table.rows) {
      expect(
        row.mouseCursor?.resolve(const <WidgetState>{}),
        SystemMouseCursors.basic,
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


  testApp('a plain click on a card opens nothing', (tester) async {
    await _open(tester);
    await tester.tap(find.text(_karim));
    await tester.pumpAndSettle();
    expect(find.byType(DetailDrawer), findsNothing);
    expect(find.byType(WizardDialog), findsNothing);
    expect(
      appRouter.routerDelegate.currentConfiguration.uri.toString(),
      Routes.toEmployees(StoreIds.sablon),
    );
  });

  testApp('card menu → Historique pointage: the history, filtered to them', (
    tester,
  ) async {
    await _open(tester);
    final card = find.byKey(const ValueKey('employee-card-${EmployeeIds.karim}'));
    await tester.tap(
      find.descendant(
        of: card,
        matching: find.byKey(const ValueKey('employee-card-menu')),
      ),
    );
    await tester.pumpAndSettle();
    // .last: the sidebar has an entry with the same label; the menu is on top.
    await tester.tap(find.text('Historique pointage').last);
    await tester.pumpAndSettle();

    expect(
      appRouter.routerDelegate.currentConfiguration.uri.toString(),
      Routes.toAttendanceHistory(
        StoreIds.sablon,
        employeeId: EmployeeIds.karim,
      ),
    );
    expect(
      find.descendant(
        of: find.byType(EmployeeSelector),
        matching: find.text(_karim),
      ),
      findsOneWidget,
    );
  });

  testApp('card menu → Historique paiement: the payroll, filtered to them', (
    tester,
  ) async {
    await _open(tester);
    final card = find.byKey(const ValueKey('employee-card-${EmployeeIds.karim}'));
    await tester.tap(
      find.descendant(
        of: card,
        matching: find.byKey(const ValueKey('employee-card-menu')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Historique paiement').last);
    await tester.pumpAndSettle();

    expect(
      appRouter.routerDelegate.currentConfiguration.uri.toString(),
      Routes.toPayroll(StoreIds.sablon, employeeId: EmployeeIds.karim),
    );
    expect(
      find.descendant(
        of: find.byType(EmployeeSelector),
        matching: find.text(_karim),
      ),
      findsOneWidget,
    );
    // Filtered to one person → the pay button is there.
    expect(find.widgetWithText(PrimaryButton, 'Payer'), findsOneWidget);
  });

  testApp('the table fills its frame; an Actions column with the two '
      'histories and the ⋮ menu', (tester) async {
    await _open(tester);
    await _toList(tester);

    final frame = tester.getSize(find.byType(DataTableWrapper)).width;
    final table = tester.getSize(find.byType(DataTable)).width;
    expect(table, greaterThanOrEqualTo(frame - 2)); // frame hairlines

    final dataTable = tester.widget<DataTable>(find.byType(DataTable));
    expect((dataTable.columns.last.label as Text).data, 'Actions');
    expect(
      find.byKey(const ValueKey('employee-row-attendance-${EmployeeIds.karim}')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.byKey(const ValueKey('employee-card-menu')),
      ),
      findsWidgets,
    );

    // The Actions column is the last one — scroll the table to it first.
    final payroll = find.byKey(
      const ValueKey('employee-row-payroll-${EmployeeIds.karim}'),
    );
    await tester.ensureVisible(payroll);
    await tester.pumpAndSettle();
    await tester.tap(payroll);
    await tester.pumpAndSettle();
    expect(
      appRouter.routerDelegate.currentConfiguration.uri.toString(),
      Routes.toPayroll(StoreIds.sablon, employeeId: EmployeeIds.karim),
    );
  });

  testApp('the table row menu holds Modifier / Retirer, not the histories', (
    tester,
  ) async {
    await _open(tester);
    await _toList(tester);
    final row = find.byKey(
      const ValueKey('employee-row-attendance-${EmployeeIds.karim}'),
    );
    final menu = find.descendant(
      of: find.ancestor(of: row, matching: find.byType(Row)).first,
      matching: find.byKey(const ValueKey('employee-card-menu')),
    );
    await tester.ensureVisible(menu);
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Retirer'), findsOneWidget);
    // Only the sidebar's own entry — none in this menu.
    expect(find.text('Historique pointage'), findsOneWidget);
  });

  testApp('both views fit a phone', (tester) async {
    await _open(tester);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(_karim), findsOneWidget);

    await _toList(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(DataTable), findsOneWidget);
  });

}
