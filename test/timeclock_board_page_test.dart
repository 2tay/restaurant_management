// The pointage kiosk board after the redesign: centered cards without the PIN,
// the employee selector that pins the board to one card, and POINTER as a
// colourless outline action.

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/core/theme/app_colors.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/core/utils/formatters.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/features/employees/presentation/widgets/close_business_day_dialog.dart';
import 'package:stock_inventory/models/models.dart';
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

/// A board test, the day after the seed.
///
/// `testApp` starts the clock at the moment the seed was written, and the seed
/// gives that day punches of its own (Amélie is still clocked in). The day
/// after has none, which is what every test here starts from.
void _testBoard(
  String description,
  Future<void> Function(WidgetTester tester) body,
) => testApp(description, (tester) {
  final seedClock = clock;
  return withClock(
    Clock(() => seedClock.now().add(const Duration(days: 1))),
    () => body(tester),
  );
});

/// Today at [hour]:[minute] — the harness database has no punch for today,
/// so a test that needs one makes it.
DateTime _today(int hour, [int minute = 0]) {
  final now = clock.now();
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
  _testBoard('cards show the name but never the PIN', (tester) async {
    await _openBoard(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(EmployeeAvatar), findsWidgets);
    final marc = mockEmployees.firstWhere((e) => e.id == EmployeeIds.marc);
    expect(find.text(_name(EmployeeIds.marc)), findsWidgets);
    expect(find.textContaining(marc.pin), findsNothing);
  });

  _testBoard('POINTER is an outline action, not a filled colour', (
    tester,
  ) async {
    await _openBoard(tester);
    // Several seeded employees have not clocked in today.
    expect(find.widgetWithText(OutlinedButton, 'POINTER'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'POINTER'), findsNothing);
  });

  _testBoard('the selector pins the board to one card, then clears back', (
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

    Finder amelieCard() => find.descendant(
      of: find.byType(AppCard),
      matching: find.text(_name(EmployeeIds.amelie)),
    );
    expect(amelieCard(), findsNothing);

    await tester.tap(find.byTooltip('Effacer'));
    await tester.pumpAndSettle();
    expect(amelieCard(), findsWidgets);
  });

  _testBoard('the owner has no card on the board', (tester) async {
    await _openBoard(tester);

    // Scoped to the cards: Marc's name still shows in the sidebar user menu.
    expect(
      find.descendant(
        of: find.byType(AppCard),
        matching: find.text(_name(EmployeeIds.marc)),
      ),
      findsNothing,
    );
  });

  _testBoard('header: title and paragraph left; date, time and full screen on '
      'one line at the right', (tester) async {
    // Wide: the test font draws every glyph a full em — at 1280 the title and
    // the clock would not share a line here, though they do in Inter.
    await _openBoard(tester, size: const Size(2000, 900));

    final clock = find.byKey(const ValueKey('live-date-time'));
    expect(clock, findsOneWidget);
    // No « Date : » / « Heure : » labels — icon, value, then a pipe.
    expect(
      find.descendant(of: clock, matching: find.textContaining('Date : ')),
      findsNothing,
    );
    expect(
      find.descendant(of: clock, matching: find.textContaining('Heure : ')),
      findsNothing,
    );
    // date | time | full screen.
    final pipes = find.byType(PipeSeparator);
    expect(pipes, findsNWidgets(2));
    expect(find.descendant(of: clock, matching: pipes), findsOneWidget);
    final fullScreen = find.byTooltip('Plein écran');
    expect(fullScreen, findsOneWidget);

    final title = find.text('Tableau de pointage').last;
    final clockRect = tester.getRect(clock);
    // Same band as the title, at the right; full screen right after it.
    expect(clockRect.left, greaterThan(tester.getRect(title).right));
    expect(tester.getCenter(fullScreen).dy, closeTo(clockRect.center.dy, 12));
    expect(tester.getRect(fullScreen).left, greaterThan(clockRect.right));
    final outerPipe = tester.getRect(pipes.last);
    expect(outerPipe.left, greaterThan(clockRect.right));
    expect(tester.getRect(fullScreen).left, greaterThan(outerPipe.right));
  });

  _testBoard(
    'cards: status and buttons only, "Voir détails" at the top right',
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
      expect(
        find.descendant(of: detail, matching: find.text('Voir détails')),
        findsOneWidget,
      );
      final card = tester.getRect(amelieCard);
      final link = tester.getRect(detail);
      expect(link.right, closeTo(card.right, 24));
      expect(link.top, closeTo(card.top, 24));
    },
  );

  _testBoard('Voir détails opens a bare drawer: identity without PIN, the date '
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
    final amelie = mockEmployees.firstWhere((e) => e.id == EmployeeIds.amelie);

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
    // One session — still titled, like a split day.
    expect(inDrawer(find.text('Arrivée')), findsOneWidget);
    expect(inDrawer(find.text('08:00')), findsOneWidget);
    expect(inDrawer(find.text('Reprise')), findsOneWidget);
    expect(inDrawer(find.text('Session N° 1')), findsOneWidget);
    expect(inDrawer(find.textContaining('Session N° 2')), findsNothing);
    // Summary under the sessions; nothing to alert.
    final summary = inDrawer(find.textContaining('Résumé de la journée'));
    expect(summary, findsOneWidget);
    expect(
      tester.getTopLeft(summary).dy,
      greaterThan(tester.getTopLeft(inDrawer(find.text('Reprise'))).dy),
    );
    expect(inDrawer(find.text('Pauses (1)')), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            inDrawer(find.byKey(const ValueKey('attendance-day-pauses'))),
          )
          .data,
      '5 min',
    );
    expect(inDrawer(find.text('Alertes')), findsNothing);
  });

  _testBoard('two sessions: a Session N° each, the overrun in the Alertes '
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
      tester
          .widget<Text>(
            inDrawer(find.byKey(const ValueKey('attendance-day-worked'))),
          )
          .data,
      '2 h 00',
    );
    final alerts = inDrawer(find.text('Alertes'));
    expect(alerts, findsOneWidget);
    final overrun = inDrawer(find.textContaining('Pause dépassée de'));
    expect(overrun, findsOneWidget);
    expect(
      tester.getTopLeft(alerts).dy,
      greaterThan(
        tester
            .getTopLeft(inDrawer(find.textContaining('Résumé de la journée')))
            .dy,
      ),
    );
    expect(
      tester.getTopLeft(overrun).dy,
      greaterThan(tester.getTopLeft(alerts).dy),
    );
  });

  _testBoard('no punch yet: avatar, name and a dated invitation, POINTER — '
      'centred; POINTER asks for the PIN', (tester) async {
    await _openBoard(tester);
    await _openDetail(tester, EmployeeIds.noah);
    final drawer = find.byType(DetailDrawer);
    Finder inDrawer(Finder f) => find.descendant(of: drawer, matching: f);
    expect(tester.takeException(), isNull);

    final prompt = inDrawer(find.byKey(const ValueKey('timeclock-start-day')));
    expect(prompt, findsOneWidget);
    expect(inDrawer(find.byType(EmployeeAvatar)), findsOneWidget);
    expect(inDrawer(find.text(_name(EmployeeIds.noah))), findsOneWidget);
    final noah = mockEmployees.firstWhere((e) => e.id == EmployeeIds.noah);
    expect(inDrawer(find.textContaining(noah.pin)), findsNothing);
    final today = Formatters.date(clock.now());
    expect(
      inDrawer(find.textContaining('pas encore commencé votre journée')),
      findsOneWidget,
    );
    expect(inDrawer(find.textContaining(today)), findsOneWidget);
    expect(inDrawer(find.textContaining('Résumé de la journée')), findsNothing);
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

  _testBoard('cards: one per line on a phone, then three or four', (
    tester,
  ) async {
    Future<int> perLine(Size size) async {
      await _openBoard(tester, size: size);
      expect(tester.takeException(), isNull, reason: '$size');
      // Each card's own "Voir détails" — the sidebar carries an avatar too.
      final details = find.byWidgetPredicate(
        (w) => '${w.key}'.contains('timeclock-detail-'),
      );
      final tops = [
        for (final e in details.evaluate())
          tester.getTopLeft(find.byWidget(e.widget)).dy,
      ];
      return tops.where((y) => y == tops.first).length;
    }

    expect(await perLine(const Size(390, 844)), 1);
    expect(await perLine(const Size(1280, 800)), 3);
    expect(await perLine(const Size(1440, 900)), 4);
  });

  // The journée de service (audit L1 / L2). The day after the seed has no
  // journée: each test opens one with its first Pointer.

  _testBoard('the first Pointer opens the journée, and the notice says when', (
    tester,
  ) async {
    final db = await _openBoard(tester);
    expect(
      find.byKey(const ValueKey('timeclock-business-day-open')),
      findsNothing,
    );

    await AttendanceRepository(
      db,
    ).clockIn(EmployeeIds.amelie, StoreIds.sablon, now: _today(8));
    await tester.pumpAndSettle();

    final notice = find.byKey(const ValueKey('timeclock-business-day-open'));
    expect(notice, findsOneWidget);
    expect(
      find.descendant(of: notice, matching: find.textContaining('ouverte à 08:00')),
      findsOneWidget,
    );
  });

  _testBoard('past midnight the board stays on the journée still open', (
    tester,
  ) async {
    final db = await _openBoard(tester);
    final opened = _today(11);
    await AttendanceRepository(
      db,
    ).clockIn(EmployeeIds.amelie, StoreIds.sablon, now: opened);
    await tester.pumpAndSettle();
    expect(find.text('FIN DE JOURNÉE'), findsOneWidget);

    // 12:00 → 01:00 the next day: the calendar ticks over, the journée does
    // not, and Amélie can still end her shift from her card.
    await tester.pump(const Duration(hours: 13));
    await tester.pumpAndSettle();

    expect(find.text('FIN DE JOURNÉE'), findsOneWidget);
    final notice = find.byKey(const ValueKey('timeclock-business-day-open'));
    expect(
      find.descendant(
        of: notice,
        matching: find.textContaining(Formatters.date(opened)),
      ),
      findsOneWidget,
    );
  });

  _testBoard('a closed journée disables Pointer until the next day', (
    tester,
  ) async {
    final db = await _openBoard(tester);
    final attendance = AttendanceRepository(db);
    final row = await attendance.clockIn(
      EmployeeIds.amelie,
      StoreIds.sablon,
      now: _today(8),
    );
    await attendance.clockOut(row!.id, now: _today(11));
    final days = BusinessDayRepository(db);
    final journee = await days.current(StoreIds.sablon);
    await days.close(journee!.id, closedByEmployeeId: EmployeeIds.marc);
    await tester.pumpAndSettle();

    final notice = find.byKey(const ValueKey('timeclock-business-day-closed'));
    expect(notice, findsOneWidget);
    // The tint of the hourly rate on a Personnel card, not the amber warning.
    expect(
      tester.widget<NoticeBanner>(notice).colors,
      same(AppColors.brandTint),
    );
    expect(find.text('Le pointage reprendra demain.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'POINTER'), findsNothing);
    final closed = find.byKey(const ValueKey('timeclock-day-closed'));
    expect(closed, findsWidgets);
    expect(
      tester
          .widget<OutlinedButton>(
            find.descendant(of: closed.first, matching: find.byType(OutlinedButton)),
          )
          .onPressed,
      isNull,
    );

    // 01:00 the next day: the closed notice is gone, but it is night — no
    // journée opens by itself before 05:00.
    await tester.pump(const Duration(hours: 13));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('timeclock-business-day-closed')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('timeclock-business-day-none')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('timeclock-day-not-open')), findsWidgets);
    expect(find.widgetWithText(OutlinedButton, 'POINTER'), findsNothing);

    // 05:00: Pointer is back by itself, the night notice gone.
    await tester.pump(const Duration(hours: 4));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('timeclock-business-day-none')),
      findsNothing,
    );
    expect(find.widgetWithText(OutlinedButton, 'POINTER'), findsWidgets);
  });

  // Fermer la journée (step 3): the exits for whoever is still in, the
  // signed-in user's PIN, then the close — all or nothing.

  Future<void> enterPin(WidgetTester tester) async {
    // Marc, the signed-in owner, carries the seeded PIN.
    await tester.enterText(
      find.descendant(
        of: find.byType(IdentityPromptDialog),
        matching: find.byType(TextField),
      ),
      '78.02.14-153.24',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(IdentityPromptDialog),
        matching: find.widgetWithText(FilledButton, 'Valider'),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapCloseDay(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('timeclock-close-day'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  _testBoard('Fermer la journée with nobody in: confirm, PIN, then closed', (
    tester,
  ) async {
    final db = await _openBoard(tester);
    final attendance = AttendanceRepository(db);
    final row = await attendance.clockIn(
      EmployeeIds.amelie,
      StoreIds.sablon,
      now: _today(8),
    );
    await attendance.clockOut(row!.id, now: _today(10));
    await tester.pumpAndSettle();

    await tapCloseDay(tester);
    expect(find.byType(CloseBusinessDayDialog), findsOneWidget);
    expect(find.text('Tout le monde a terminé son service.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('close-day-confirm')));
    await tester.pumpAndSettle();
    expect(find.byType(IdentityPromptDialog), findsOneWidget);
    await enterPin(tester);

    expect(
      find.byKey(const ValueKey('timeclock-business-day-closed')),
      findsOneWidget,
    );
    // A one-shot read: a drift stream never delivers under the widget test's
    // fake clock without a pump.
    final journee = await db.select(db.businessDays).getSingle();
    expect(journee.closedAt, isNotNull);
    expect(journee.closedByEmployeeId, EmployeeIds.marc);
  });

  _testBoard('an employee still in gets the exit time entered, then the day '
      'closes with their shift ended there', (tester) async {
    final db = await _openBoard(tester);
    final attendance = AttendanceRepository(db);
    final row = await attendance.clockIn(
      EmployeeIds.amelie,
      StoreIds.sablon,
      now: _today(8),
    );
    await tester.pumpAndSettle();

    await tapCloseDay(tester);
    final shift = find.byKey(ValueKey('close-day-shift-${row!.id}'));
    expect(shift, findsOneWidget);
    expect(
      find.descendant(of: shift, matching: find.text(_name(EmployeeIds.amelie))),
      findsOneWidget,
    );
    // Now (12:00) by default.
    expect(
      find.descendant(of: shift, matching: find.text('Sortie à 12:00')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('close-day-confirm')));
    await tester.pumpAndSettle();
    await enterPin(tester);

    final ended = await attendance.attendance(row.id);
    expect(ended!.status, AttendanceStatus.done);
    expect(ended.sessions.single.clockOutAt, _today(12));
    expect(ended.sessions.single.exitSetByEmployeeId, EmployeeIds.marc);
    expect(
      find.byKey(const ValueKey('timeclock-business-day-closed')),
      findsOneWidget,
    );

    // Her drawer names whoever entered the exit.
    await _openDetail(tester, EmployeeIds.amelie);
    expect(
      find.descendant(
        of: find.byType(DetailDrawer),
        matching: find.text('Départ · saisi par ${_name(EmployeeIds.marc)}'),
      ),
      findsOneWidget,
    );
  });

  _testBoard('past midnight, a shift of the journée still open is not an '
      'oubli de pointage', (tester) async {
    final db = await _openBoard(tester, size: const Size(1280, 1400));
    await AttendanceRepository(
      db,
    ).clockIn(EmployeeIds.amelie, StoreIds.sablon, now: _today(8));
    await tester.pumpAndSettle();

    // 01:00 the next day, the journée still open: Amélie is still in service.
    await tester.pump(const Duration(hours: 13));
    await tester.pumpAndSettle();
    await _openDetail(tester, EmployeeIds.amelie);

    final drawer = find.byType(DetailDrawer);
    expect(drawer, findsOneWidget);
    expect(
      find.descendant(of: drawer, matching: find.text('Oubli de pointage')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: drawer,
        matching: find.byKey(const ValueKey('attendance-day-alerts')),
      ),
      findsNothing,
    );
  });

  _testBoard('an exit before the arrival is flagged and blocks the close', (
    tester,
  ) async {
    final db = await _openBoard(tester);
    final row = await AttendanceRepository(
      db,
    ).clockIn(EmployeeIds.amelie, StoreIds.sablon, now: _today(11, 30));
    await tester.pumpAndSettle();

    await tapCloseDay(tester);
    await tester.tap(find.byKey(const ValueKey('close-day-exit')));
    await tester.pumpAndSettle();

    // Type the time rather than drag the dial.
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(TimePickerDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), '11');
    await tester.enterText(fields.at(1), '00');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final shift = find.byKey(ValueKey('close-day-shift-${row!.id}'));
    expect(
      find.descendant(of: shift, matching: find.text('Sortie à 11:00')),
      findsOneWidget,
    );
    expect(find.text('Avant son arrivée (11:30)'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('close-day-confirm')))
          .onPressed,
      isNull,
    );
  });

  _testBoard('a journée left open 18 h turns the notice into a warning', (
    tester,
  ) async {
    final db = await _openBoard(tester);
    // Opened at 08:00; the board starts at 12:00.
    await AttendanceRepository(
      db,
    ).clockIn(EmployeeIds.amelie, StoreIds.sablon, now: _today(8));
    await tester.pumpAndSettle();
    final warning = find.textContaining('Ouverte depuis plus de 18 h');
    expect(warning, findsNothing);

    // 01:00 the next day — 17 h open, still fine.
    await tester.pump(const Duration(hours: 13));
    await tester.pumpAndSettle();
    expect(warning, findsNothing);

    // 02:01 — past 18 h: the notice flags itself, with nothing tapped.
    await tester.pump(const Duration(hours: 1, minutes: 1));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('timeclock-business-day-open')),
        matching: warning,
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('timeclock-close-day')), findsOneWidget);
  });

  _testBoard('at night a manager can still open the journée on purpose', (
    tester,
  ) async {
    await _openBoard(tester);
    // 12:00 → 02:00 the next day, no journée open.
    await tester.pump(const Duration(hours: 14));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, 'POINTER'), findsNothing);

    final open = find.byKey(const ValueKey('timeclock-open-day'));
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pumpAndSettle();
    await enterPin(tester);

    final notice = find.byKey(const ValueKey('timeclock-business-day-open'));
    expect(notice, findsOneWidget);
    expect(
      find.descendant(of: notice, matching: find.textContaining('ouverte à 02:00')),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'POINTER'), findsWidgets);
  });

  _testBoard("the night lock follows the store's auto-open time", (
    tester,
  ) async {
    final db = await _openBoard(tester);
    await StoreRepository(
      db,
    ).updateStoreSettings(StoreIds.sablon, businessDayAutoOpenMinutes: 7 * 60);

    // 12:00 -> 06:00 the next day: still before 07:00, locked.
    await tester.pump(const Duration(hours: 18));
    await tester.pumpAndSettle();
    final notice = find.byKey(const ValueKey('timeclock-business-day-none'));
    expect(
      find.descendant(of: notice, matching: find.textContaining('07:00')),
      findsWidgets,
    );
    expect(find.widgetWithText(OutlinedButton, 'POINTER'), findsNothing);

    // 07:00: unlocked by itself.
    await tester.pump(const Duration(hours: 1));
    await tester.pumpAndSettle();
    expect(notice, findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'POINTER'), findsWidgets);
  });
}
