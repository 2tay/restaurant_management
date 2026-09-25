// The pointage kiosk board after the redesign: centered cards without the PIN,
// the employee selector that pins the board to one card, and POINTER as a
// colourless outline action.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';

import 'support/app_harness.dart';

Future<AppDatabase> _openBoard(
  WidgetTester tester, {
  Size size = const Size(1280, 800),
}) async {
  final db = await pumpApp(tester, size: size);
  appRouter.go(Routes.toTimeclock(StoreIds.sablon));
  await tester.pumpAndSettle();
  return db;
}

/// Today at [hour]:[minute] — the harness database has no punch for today,
/// so a test that needs one makes it.
DateTime _today(int hour, [int minute = 0]) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, hour, minute);
}

Future<void> _openDetail(WidgetTester tester, String employeeId) async {
  final detail = find.byKey(ValueKey('timeclock-detail-$employeeId'));
  await tester.ensureVisible(detail);
  await tester.tap(detail);
  await tester.pumpAndSettle();
}

String _name(String id) {
  final e = mockEmployees.firstWhere((e) => e.id == id);
  return '${e.firstName} ${e.lastName}';
}

void main() {
  testApp('cards show the name but never the PIN', (tester) async {
    await _openBoard(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(EmployeeAvatar), findsWidgets);
    final marc = mockEmployees.firstWhere((e) => e.id == EmployeeIds.marc);
    expect(find.text(_name(EmployeeIds.marc)), findsWidgets);
    expect(find.textContaining(marc.pin), findsNothing);
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

    // Scoped to the cards: Marc's name still shows in the sidebar user menu.
    Finder marcCard() => find.descendant(
      of: find.byType(AppCard),
      matching: find.text(_name(EmployeeIds.marc)),
    );
    expect(marcCard(), findsNothing);

    await tester.tap(find.byTooltip('Effacer'));
    await tester.pumpAndSettle();
    expect(marcCard(), findsWidgets);
  });

  testApp('header: title and paragraph left; date, time and full screen on '
      'one line at the right', (tester) async {
    // Wide: the test font draws every glyph a full em — at 1280 the title and
    // the clock would not share a line here, though they do in Inter.
    await _openBoard(tester, size: const Size(2000, 900));

    final clock = find.byKey(const ValueKey('live-date-time'));
    expect(clock, findsOneWidget);
    expect(
      find.descendant(of: clock, matching: find.textContaining('Date : ')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: clock, matching: find.textContaining('Heure : ')),
      findsOneWidget,
    );
    final fullScreen = find.byTooltip('Plein écran');
    expect(fullScreen, findsOneWidget);

    final title = find.text('Tableau de pointage').last;
    final clockRect = tester.getRect(clock);
    // Same band as the title, at the right; full screen right after it.
    expect(clockRect.left, greaterThan(tester.getRect(title).right));
    expect(
      tester.getCenter(fullScreen).dy,
      closeTo(clockRect.center.dy, 12),
    );
    expect(tester.getRect(fullScreen).left, greaterThan(clockRect.right));
  });

  testApp('cards: status and buttons only, "Voir détails" at the top right',
      (tester) async {
    await _openBoard(tester);

    final cards = find.byType(AppCard);
    // No timestamp log on the cards any more.
    for (final word in ['Arrivée', 'Reprise', 'Départ']) {
      expect(
        find.descendant(of: cards, matching: find.text(word)),
        findsNothing,
        reason: word,
      );
    }
    expect(find.byType(AttendanceStatusBadge), findsWidgets);

    final amelieCard = find.ancestor(
      of: find.text(_name(EmployeeIds.amelie)),
      matching: find.byType(AppCard),
    );
    final detail = find.byKey(
      const ValueKey('timeclock-detail-${EmployeeIds.amelie}'),
    );
    expect(detail, findsOneWidget);
    expect(find.descendant(of: detail, matching: find.text('Voir détails')),
        findsOneWidget);
    final card = tester.getRect(amelieCard);
    final link = tester.getRect(detail);
    expect(link.right, closeTo(card.right, 24));
    expect(link.top, closeTo(card.top, 24));
  });

  testApp('Voir détails opens the drawer: date and time as its heading (icons, '
      'no labels, dashed rule), one session without a "Session" heading, the '
      'time worked last', (
    tester,
  ) async {
    final db = await _openBoard(tester, size: const Size(1280, 1400));
    final repo = AttendanceRepository(db);
    final day = await repo.clockIn(
      EmployeeIds.amelie,
      StoreIds.sablon,
      now: _today(8),
    );
    await repo.startPause(day!.id, now: _today(9, 30));
    await repo.endPause(day.id, now: _today(9, 35));
    await tester.pumpAndSettle();
    final amelie = mockEmployees.firstWhere(
      (e) => e.id == EmployeeIds.amelie,
    );

    await _openDetail(tester, EmployeeIds.amelie);

    final drawer = find.byType(DetailDrawer);
    expect(drawer, findsOneWidget);
    expect(tester.takeException(), isNull);
    Finder inDrawer(Finder f) => find.descendant(of: drawer, matching: f);

    // No "Détail du pointage": the date and time are the heading, icons and
    // values only, over a dashed rule.
    expect(inDrawer(find.text('Détail du pointage')), findsNothing);
    final clock = inDrawer(find.byType(LiveDateTime));
    expect(clock, findsOneWidget);
    expect(
      find.descendant(of: clock, matching: find.textContaining('Date : ')),
      findsNothing,
    );
    expect(
      find.descendant(of: clock, matching: find.textContaining('Heure : ')),
      findsNothing,
    );
    expect(
      inDrawer(find.byKey(const ValueKey('detail-drawer-dashed-rule'))),
      findsOneWidget,
    );
    // No personal-information section any more.
    expect(inDrawer(find.text('Informations personnelles')), findsNothing);
    expect(inDrawer(find.text(amelie.email)), findsNothing);
    expect(inDrawer(find.text(_name(EmployeeIds.amelie))), findsOneWidget);
    // The kiosk never shows the PIN.
    expect(inDrawer(find.textContaining(amelie.pin)), findsNothing);
    // One session — Arrivée, Pause, Reprise; no heading, no alert.
    expect(inDrawer(find.text('Horaires')), findsOneWidget);
    expect(inDrawer(find.text('Arrivée')), findsOneWidget);
    expect(inDrawer(find.text('08:00')), findsOneWidget);
    expect(inDrawer(find.text('Pause')), findsOneWidget);
    expect(inDrawer(find.text('Reprise')), findsOneWidget);
    expect(inDrawer(find.textContaining('Session N°')), findsNothing);
    expect(inDrawer(find.textContaining('dépassée')), findsNothing);
    // No session finished yet → no time worked to show.
    expect(
      inDrawer(find.byKey(const ValueKey('timeclock-detail-worked'))),
      findsNothing,
    );
  });

  testApp('two sessions in the day: a Session N° heading each, the pause '
      'alert under the one that ran over', (tester) async {
    final db = await _openBoard(tester, size: const Size(1280, 1600));
    final repo = AttendanceRepository(db);
    final day = await repo.clockIn(
      EmployeeIds.amelie,
      StoreIds.sablon,
      now: _today(8),
    );
    // A two-hour break: over any store's allowance.
    await repo.startPause(day!.id, now: _today(9));
    await repo.endPause(day.id, now: _today(11));
    await repo.clockOut(day.id, now: _today(12));
    await repo.clockIn(EmployeeIds.amelie, StoreIds.sablon, now: _today(18));
    await tester.pumpAndSettle();

    await _openDetail(tester, EmployeeIds.amelie);
    final drawer = find.byType(DetailDrawer);
    Finder inDrawer(Finder f) => find.descendant(of: drawer, matching: f);

    final first = inDrawer(find.text('Session N° 1'));
    final second = inDrawer(find.text('Session N° 2'));
    expect(first, findsOneWidget);
    expect(second, findsOneWidget);
    final alert = inDrawer(find.textContaining('Pause de 09:00 dépassée'));
    expect(alert, findsOneWidget);
    expect(
      tester.getTopLeft(alert).dy,
      lessThan(tester.getTopLeft(second).dy),
    );
    expect(
      tester.getTopLeft(inDrawer(find.text('18:00'))).dy,
      greaterThan(tester.getTopLeft(second).dy),
    );
    // The time worked closes the Horaires section, under the last session:
    // 08:00–12:00 less the two-hour break.
    final worked = inDrawer(
      find.byKey(const ValueKey('timeclock-detail-worked')),
    );
    expect(worked, findsOneWidget);
    expect(
      find.descendant(of: worked, matching: find.text('Durée travail')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: worked, matching: find.text('2 h 00')),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(worked).dy,
      greaterThan(tester.getTopLeft(inDrawer(find.text('18:00'))).dy),
    );
  });

  testApp('a card with no punch yet: the drawer says so', (tester) async {
    await _openBoard(tester);
    await _openDetail(tester, EmployeeIds.noah);
    expect(find.text("Pas encore pointé aujourd'hui."), findsOneWidget);
  });
}
