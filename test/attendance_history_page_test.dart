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

Future<void> _open(
  WidgetTester tester, {
  Size size = const Size(1400, 900),
}) async {
  await pumpApp(tester, size: size);
  appRouter.go(Routes.toAttendanceHistory(StoreIds.sablon));
  await tester.pumpAndSettle();
}

void main() {
  testApp('opens with the compact table and no export button', (tester) async {
    await _open(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Durée travail'), findsWidgets);
    expect(find.text('Alertes'), findsWidgets);
    // Phase 9: no Horaires column — the sessions and pauses live in the
    // drawer's timeline.
    expect(find.text('Horaires'), findsNothing);
    // The brief forbids an export affordance here.
    expect(find.text('Exporter'), findsNothing);
  });

  testApp('clicking a row (no Détail column) opens the detail drawer', (
    tester,
  ) async {
    await _open(tester);

    // No Détail column: the row itself is the way in.
    final table = find.byType(DataTable);
    expect(
      find.descendant(of: table, matching: find.byIcon(LucideIcons.eye)),
      findsNothing,
    );
    final headers = [
      for (final c in tester.widget<DataTable>(table).columns)
        (c.label as Text).data,
    ];
    expect(headers, isNot(contains('Détail')));
    final row = find
        .descendant(of: table, matching: find.byType(AttendanceStatusBadge))
        .first;
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.byType(DetailDrawer), findsOneWidget);
    // A bare panel: no title, no rule under it, no Chronologie heading —
    // the day detail (identity, date, sessions, summary) is the content.
    final drawer = find.byType(DetailDrawer);
    expect(find.text('Détail du pointage'), findsNothing);
    expect(find.text('Chronologie'), findsNothing);
    expect(
      find.descendant(of: drawer, matching: find.byType(Divider)),
      findsNothing,
    );
    expect(find.byType(AttendanceDayDetail), findsOneWidget);
    expect(find.byType(AttendanceSessions), findsOneWidget);
    expect(
      find.descendant(
        of: drawer,
        matching: find.byKey(const ValueKey('attendance-day-date')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: drawer, matching: find.textContaining('Résumé de la journée')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(find.byType(DetailDrawer), findsNothing);
  });

  testApp('the filter strip: search bar left, début, fin and statut at the '
      'right edge, no field labels', (tester) async {
    // Wide: the test font draws every glyph a full em, so the pills are far
    // wider here than in Inter — at 1400 they would (rightly) wrap.
    await _open(tester, size: const Size(2000, 900));

    final strip = find.byType(FilterToolbar);
    expect(strip, findsOneWidget);
    final search = find.byKey(const ValueKey('employee-selector-search'));
    final period = find.byKey(const ValueKey('date-filter-from'));
    final end = find.byKey(const ValueKey('date-filter-to'));
    final status = find.descendant(
      of: strip,
      matching: find.byWidgetPredicate((w) => w is FilterMenu),
    );
    expect(find.byType(DateFilter), findsNWidgets(2));
    expect(status, findsOneWidget);
    // Two separate pills, each naming its end of the period.
    expect(
      find.descendant(of: period, matching: find.textContaining('Début : ')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: end, matching: find.textContaining('Fin : ')),
      findsOneWidget,
    );
    expect(tester.getRect(period).right, lessThan(tester.getRect(end).left));
    // One line, search first, the status pill flush with the strip's end.
    expect(tester.getCenter(search).dy, closeTo(tester.getCenter(period).dy, 6));
    expect(tester.getRect(search).right, lessThan(tester.getRect(period).left));
    expect(tester.getRect(status).right, closeTo(tester.getRect(strip).right, 0.5));
    // The old stacked labels are gone.
    expect(find.descendant(of: strip, matching: find.text('Du')), findsNothing);
    expect(find.descendant(of: strip, matching: find.text('Au')), findsNothing);
    // The status menu is white and drops under its pill.
    await tester.tap(status);
    await tester.pumpAndSettle();
    final menu = tester.widget<PopupMenuButton<int>>(
      find.descendant(of: strip, matching: find.byType(PopupMenuButton<int>)),
    );
    expect(menu.color, Colors.white);
    expect(menu.position, PopupMenuPosition.under);
    final firstEntry = find.byType(PopupMenuItem<int>).first;
    expect(
      tester.getRect(firstEntry).top,
      greaterThanOrEqualTo(tester.getRect(status).bottom),
    );
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    // Same look as the Personnel search: white, borderless at rest.
    final field = tester.widget<TextField>(search);
    expect(field.decoration?.fillColor, Colors.white);
    expect(field.decoration?.enabledBorder?.borderSide, BorderSide.none);
  });

  testApp('the employee selector filters the table', (tester) async {
    await _open(tester);

    final karim = mockEmployees.firstWhere((e) => e.id == EmployeeIds.karim);
    final search = find.byKey(const ValueKey('employee-selector-search'));
    await tester.tap(search);
    await tester.pumpAndSettle();
    await tester.enterText(search, karim.firstName);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('employee-option-${EmployeeIds.karim}')),
    );
    await tester.pumpAndSettle();

    // Every employee cell in the table is Karim now. Scoped to the table:
    // Marc, the signed-in user, still shows in the sidebar menu.
    final marc = mockEmployees.firstWhere((e) => e.id == EmployeeIds.marc);
    final table = find.byType(DataTableWrapper);
    expect(
      find.descendant(
        of: table,
        matching: find.text('${marc.firstName} ${marc.lastName}'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: table,
        matching: find.text('${karim.firstName} ${karim.lastName}'),
      ),
      findsWidgets,
    );
  });

  /// Picks [size] in the paginator's rows-per-page menu.
  Future<void> pickPageSize(WidgetTester tester, int size) async {
    final menu = find.byKey(const ValueKey('paginator-page-size'));
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PopupMenuItem<int>, '$size'));
    await tester.pumpAndSettle();
  }

  testApp('the table is paged: 10 rows by default, 25 or 50 on demand', (tester) async {
    await _open(tester);
    expect(find.byType(Paginator), findsOneWidget);
    Paginator pager() => tester.widget<Paginator>(find.byType(Paginator));
    expect(pager().pageSize, 10);
    expect(find.textContaining(RegExp(r'^1–\d+ sur \d+$')), findsOneWidget);
    await pickPageSize(tester, 25);
    expect(tester.takeException(), isNull);
    expect(pager().pageSize, 25);
    expect(pager().page, 0);
  });
}
