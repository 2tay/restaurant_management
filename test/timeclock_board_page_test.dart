// The pointage kiosk board after the redesign: centered cards without the PIN,
// the employee selector that pins the board to one card, and POINTER as a
// colourless outline action.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/core/utils/formatters.dart';
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

  testApp('Voir détails opens a bare drawer: identity without PIN, the date '
      'with the live time, one session without heading, the day summary, no '
      'Alertes when there is none', (tester) async {
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

    // Bare: no title, no rule, no Horaires / Chronologie heading.
    expect(inDrawer(find.text('Détail du pointage')), findsNothing);
    expect(inDrawer(find.byType(Divider)), findsNothing);
    expect(inDrawer(find.text('Horaires')), findsNothing);
    expect(inDrawer(find.byType(LiveDateTime)), findsNothing);
    // Identity: the name, never the PIN (the kiosk).
    expect(inDrawer(find.text(_name(EmployeeIds.amelie))), findsOneWidget);
    expect(inDrawer(find.textContaining(amelie.pin)), findsNothing);
    // The date, the live time right beside it.
    final date = inDrawer(find.byKey(const ValueKey('attendance-day-date')));
    expect(date, findsOneWidget);
    expect(
      find.descendant(of: date, matching: find.byType(LiveTime)),
      findsOneWidget,
    );
    // One session — no heading.
    expect(inDrawer(find.text('Arrivée')), findsOneWidget);
    expect(inDrawer(find.text('08:00')), findsOneWidget);
    expect(inDrawer(find.text('Reprise')), findsOneWidget);
    expect(inDrawer(find.textContaining('Session N°')), findsNothing);
    // Summary under the sessions; nothing to alert.
    final summary = inDrawer(find.text('Résumé de la journée'));
    expect(summary, findsOneWidget);
    expect(
      tester.getTopLeft(summary).dy,
      greaterThan(tester.getTopLeft(inDrawer(find.text('Reprise'))).dy),
    );
    expect(inDrawer(find.textContaining('Pauses (1) : 5 min')), findsOneWidget);
    expect(inDrawer(find.text('Alertes')), findsNothing);
  });

  testApp('two sessions: a Session N° each, the overrun in the Alertes '
      'section at the end', (tester) async {
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
    expect(
      tester.getTopLeft(inDrawer(find.text('18:00'))).dy,
      greaterThan(tester.getTopLeft(second).dy),
    );
    // 08:00–12:00 less the two-hour break.
    expect(
      inDrawer(find.textContaining('Durée totale travaillée : 2 h 00')),
      findsOneWidget,
    );
    final alerts = inDrawer(find.text('Alertes'));
    expect(alerts, findsOneWidget);
    final overrun = inDrawer(find.textContaining('Pause dépassée de'));
    expect(overrun, findsOneWidget);
    expect(
      tester.getTopLeft(alerts).dy,
      greaterThan(
        tester.getTopLeft(inDrawer(find.text('Résumé de la journée'))).dy,
      ),
    );
    expect(
      tester.getTopLeft(overrun).dy,
      greaterThan(tester.getTopLeft(alerts).dy),
    );
  });

  testApp('no punch yet: avatar, name and a dated invitation, POINTER — '
      'centred; POINTER asks for the PIN', (tester) async {
    await _openBoard(tester);
    await _openDetail(tester, EmployeeIds.noah);
    final drawer = find.byType(DetailDrawer);
    Finder inDrawer(Finder f) => find.descendant(of: drawer, matching: f);
    expect(tester.takeException(), isNull);

    final prompt = inDrawer(
      find.byKey(const ValueKey('timeclock-start-day')),
    );
    expect(prompt, findsOneWidget);
    expect(inDrawer(find.byType(EmployeeAvatar)), findsOneWidget);
    expect(inDrawer(find.text(_name(EmployeeIds.noah))), findsOneWidget);
    final noah = mockEmployees.firstWhere((e) => e.id == EmployeeIds.noah);
    expect(inDrawer(find.textContaining(noah.pin)), findsNothing);
    final today = Formatters.date(DateTime.now());
    expect(
      inDrawer(find.textContaining('pas encore commencé votre journée')),
      findsOneWidget,
    );
    expect(inDrawer(find.textContaining(today)), findsOneWidget);
    expect(inDrawer(find.text('Résumé de la journée')), findsNothing);
    // Centred in the panel, both ways.
    final panel = tester.getRect(inDrawer(find.byType(ListView)));
    final avatar = tester.getCenter(inDrawer(find.byType(EmployeeAvatar)));
    expect(avatar.dx, closeTo(panel.center.dx, 2));
    final block = tester.getRect(
      find.descendant(of: prompt, matching: find.byType(Column)).first,
    );
    expect(block.center.dy, closeTo(panel.center.dy, 48));

    final pointer = inDrawer(find.widgetWithText(OutlinedButton, 'POINTER'));
    expect(pointer, findsOneWidget);
    await tester.tap(pointer);
    await tester.pumpAndSettle();
    expect(find.byType(IdentityPromptDialog), findsOneWidget);
  });
}
