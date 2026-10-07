// Historique de pointage after the redesign: the compact table, the employee
// selector filter, and the right-side detail drawer with its timeline.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/features/employees/presentation/widgets/correct_exit_dialog.dart';
import 'package:stock_inventory/models/models.dart';
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

/// A day Noah never clocked out of, four days before the seed's "now"
/// (2026-08-29 12:00) — from before the journée de service, nothing on the
/// board can end it any more.
const _forgottenId = 'att-forgotten';
final _forgottenIn = DateTime(2026, 8, 25, 18);

/// [breakAt] leaves a break running from that time — the exit cannot come
/// before it.
Future<void> _addForgottenDay(AppDatabase db, {DateTime? breakAt}) async {
  await db.into(db.attendances).insert(
    AttendancesCompanion.insert(
      id: _forgottenId,
      storeId: StoreIds.sablon,
      employeeId: EmployeeIds.noah,
      date: DateTime(2026, 8, 25),
      status: breakAt == null
          ? AttendanceStatus.working
          : AttendanceStatus.onBreak,
    ),
  );
  await db.into(db.attendanceSessions).insert(
    AttendanceSessionsCompanion.insert(
      id: '$_forgottenId-session-0',
      storeId: StoreIds.sablon,
      attendanceId: _forgottenId,
      position: 0,
      clockInAt: _forgottenIn,
    ),
  );
  if (breakAt != null) {
    await db.into(db.attendancePauses).insert(
      AttendancePausesCompanion.insert(
        id: '$_forgottenId-pause-0',
        storeId: StoreIds.sablon,
        sessionId: '$_forgottenId-session-0',
        position: 0,
        startAt: breakAt,
      ),
    );
  }
}

/// Filtered to Noah, so the day is on the first page. Through Personnel
/// first: the router outlives a test, and a page it reuses would keep the
/// previous test's (unfiltered) state — the filter is read when it is built.
Future<void> _openFilteredToNoah(WidgetTester tester) async {
  appRouter.go(Routes.toEmployees(StoreIds.sablon));
  await tester.pumpAndSettle();
  appRouter.go(
    Routes.toAttendanceHistory(StoreIds.sablon, employeeId: EmployeeIds.noah),
  );
  await tester.pumpAndSettle();
}

Future<void> _openForgottenDrawer(WidgetTester tester) async {
  final chip = find.descendant(
    of: find.byType(DataTable),
    matching: find.text('Oubli de pointage'),
  );
  await tester.ensureVisible(chip.first);
  await tester.tap(chip.first);
  await tester.pumpAndSettle();
}

Future<void> _pickTime(WidgetTester tester, String hour, String minute) async {
  await tester.tap(find.byKey(const ValueKey('correct-exit-time')));
  await tester.pumpAndSettle();
  // Type the time rather than drag the dial.
  await tester.tap(find.byIcon(Icons.keyboard_outlined));
  await tester.pumpAndSettle();
  final fields = find.descendant(
    of: find.byType(TimePickerDialog),
    matching: find.byType(TextField),
  );
  await tester.enterText(fields.at(0), hour);
  await tester.enterText(fields.at(1), minute);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

bool _confirmEnabled(WidgetTester tester) =>
    tester
        .widget<FilledButton>(find.byKey(const ValueKey('correct-exit-confirm')))
        .onPressed !=
    null;

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

  testApp('a phone: one card per line, worked hours and a pause count, the '
      'filters behind an icon', (tester) async {
    await _open(tester, size: const Size(390, 844));
    expect(tester.takeException(), isNull);
    expect(find.byType(DataTable), findsNothing);

    // Filters: search on the page, the rest in the sheet.
    expect(find.byKey(const ValueKey('date-filter-from')), findsNothing);
    await tester.tap(find.byType(FilterSheetButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('date-filter-from')), findsOneWidget);
    await tester.tap(find.text('Voir les résultats'));
    await tester.pumpAndSettle();

    // The card: no Horaires span, the time worked, and the pauses with their
    // count in a badge.
    expect(find.text('Horaires'), findsNothing);
    expect(find.text('Heures travaillées'), findsWidgets);
    final pauses = find.byKey(const ValueKey('attendance-card-pauses'));
    expect(pauses, findsWidgets);
    expect(
      find.descendant(
        of: pauses.first,
        matching: find.byKey(const ValueKey('card-figure-count')),
      ),
      findsOneWidget,
    );

    // The header: the date with the status beside it, and no eye button —
    // the whole card opens the detail.
    expect(find.byType(CardDateHeader), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(CardDateHeader).first,
        matching: find.byType(AttendanceStatusBadge),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(LucideIcons.eye), findsNothing);
    expect(find.byKey(const ValueKey('employee-card-pin')), findsWidgets);

    // One per line: every card starts at the same left edge.
    final lefts = {
      for (final e in pauses.evaluate())
        tester.getTopLeft(find.byWidget(e.widget)).dx,
    };
    expect(lefts, hasLength(1));
  });

  // L3: a day left open that the board can no longer end — « Corriger la
  // sortie » in its drawer, signed by the PIN of whoever is signed in.

  testApp('a finished day offers no correction', (tester) async {
    await _open(tester);
    final row = find
        .descendant(
          of: find.byType(DataTable),
          matching: find.byType(AttendanceStatusBadge),
        )
        .first;
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(find.byType(DetailDrawer), findsOneWidget);
    expect(find.byKey(const ValueKey('attendance-correct-exit')), findsNothing);
  });

  testApp('a forgotten exit is corrected past midnight, signed and traced', (
    tester,
  ) async {
    final db = await pumpApp(tester, size: const Size(1400, 900));
    await _addForgottenDay(db);
    await _openFilteredToNoah(tester);

    await _openForgottenDrawer(tester);
    await tester.tap(find.byKey(const ValueKey('attendance-correct-exit')));
    await tester.pumpAndSettle();

    expect(find.byType(CorrectExitDialog), findsOneWidget);
    expect(find.text("Choisir l'heure"), findsOneWidget);
    expect(_confirmEnabled(tester), isFalse, reason: 'no time picked yet');

    // 00:30 after an 18:00 clock-in is the next day.
    await _pickTime(tester, '00', '30');
    expect(find.text('Sortie à 00:30'), findsOneWidget);
    expect(find.textContaining('Le lendemain'), findsOneWidget);
    expect(_confirmEnabled(tester), isTrue);

    await tester.tap(find.byKey(const ValueKey('correct-exit-confirm')));
    await tester.pumpAndSettle();
    expect(find.byType(IdentityPromptDialog), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(IdentityPromptDialog),
        matching: find.byType(TextField),
      ),
      '78.02.14-153.24', // Marc, the signed-in owner
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(IdentityPromptDialog),
        matching: find.widgetWithText(FilledButton, 'Valider'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DetailDrawer), findsNothing);
    expect(find.textContaining('corrigée'), findsOneWidget);

    final fixed = (await AttendanceRepository(db).attendance(_forgottenId))!;
    expect(fixed.status, AttendanceStatus.done);
    expect(fixed.sessions.single.clockOutAt, DateTime(2026, 8, 26, 0, 30));
    expect(fixed.sessions.single.exitSetByEmployeeId, EmployeeIds.marc);
  });

  // Rule P1 (SYNC_PERSONNEL_PLAN.md, step 6): a day two tablets clocked
  // twice offers to remove the arrival in excess, signed by the PIN.
  testApp('« Supprimer ce pointage en double » removes one arrival', (
    tester,
  ) async {
    final db = await pumpApp(tester, size: const Size(1400, 900));
    const id = 'att-double';
    await db.into(db.attendances).insert(
      AttendancesCompanion.insert(
        id: id,
        storeId: StoreIds.sablon,
        employeeId: EmployeeIds.noah,
        date: DateTime(2026, 8, 25),
        status: AttendanceStatus.done,
      ),
    );
    for (final (position, minute) in [(0, 0), (1000, 5)]) {
      await db.into(db.attendanceSessions).insert(
        AttendanceSessionsCompanion.insert(
          id: '$id-$position',
          storeId: StoreIds.sablon,
          attendanceId: id,
          position: position,
          clockInAt: DateTime(2026, 8, 25, 9, minute),
          clockOutAt: Value(DateTime(2026, 8, 25, 17)),
        ),
      );
    }
    await _openFilteredToNoah(tester);

    final chip = find.descendant(
      of: find.byType(DataTable),
      matching: find.text('Double pointage'),
    );
    await tester.ensureVisible(chip.first);
    await tester.tap(chip.first);
    await tester.pumpAndSettle();
    final second = find.byKey(const ValueKey('attendance-delete-duplicate-1'));
    await tester.scrollUntilVisible(
      second,
      200,
      scrollable: find
          .descendant(
            of: find.byType(DetailDrawer),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Pointage en double'), findsOneWidget);
    await tester.tap(second);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(IdentityPromptDialog),
        matching: find.byType(TextField),
      ),
      '78.02.14-153.24', // Marc, the signed-in owner
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(IdentityPromptDialog),
        matching: find.widgetWithText(FilledButton, 'Valider'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DetailDrawer), findsNothing);
    expect(find.textContaining('supprimé'), findsOneWidget);
    final kept = (await AttendanceRepository(db).attendance(id))!;
    expect(kept.sessions, hasLength(1));
    expect(kept.sessions.single.id, '$id-0');
  });

  testApp('an exit before the running break is refused; Annuler writes '
      'nothing', (tester) async {
    final db = await pumpApp(tester, size: const Size(1400, 900));
    await _addForgottenDay(db, breakAt: DateTime(2026, 8, 25, 22));
    await _openFilteredToNoah(tester);

    await _openForgottenDrawer(tester);
    await tester.tap(find.byKey(const ValueKey('attendance-correct-exit')));
    await tester.pumpAndSettle();

    await _pickTime(tester, '21', '00');
    expect(find.text('Avant le début de sa pause (22:00)'), findsOneWidget);
    expect(_confirmEnabled(tester), isFalse);

    await _pickTime(tester, '23', '00');
    expect(find.textContaining('Avant le début'), findsNothing);
    expect(_confirmEnabled(tester), isTrue);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(
      (await AttendanceRepository(db).attendance(_forgottenId))!.status,
      AttendanceStatus.onBreak,
    );
  });

  testApp('a shift of the journée still open (past midnight) is no oubli, '
      'and offers no correction', (tester) async {
    final db = await pumpApp(tester, size: const Size(1400, 900));
    // The journée of the 25th opened at 18:00 and is still open — the same
    // shape as an evening service still running at 00:30.
    await BusinessDayRepository(
      db,
      clock: () => _forgottenIn,
    ).open(StoreIds.sablon, openedByEmployeeId: EmployeeIds.marc);
    await _addForgottenDay(db);
    await _openFilteredToNoah(tester);

    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('Oubli de pointage'),
      ),
      findsNothing,
    );
    final row = find
        .descendant(
          of: find.byType(DataTable),
          matching: find.byType(AttendanceStatusBadge),
        )
        .first;
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(DetailDrawer), findsOneWidget);
    expect(find.byKey(const ValueKey('attendance-correct-exit')), findsNothing);
  });
}
