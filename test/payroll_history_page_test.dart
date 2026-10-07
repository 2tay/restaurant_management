// Drives the redesigned Historique de paiement page: it opens on every
// employee, narrows to one through the filter, and settles that person's
// unpaid days for the shown range.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/models/models.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';

import 'support/app_harness.dart';

Future<AppDatabase> _openPayroll(
  WidgetTester tester, {
  Size size = const Size(1280, 800),
}) async {
  final db = await pumpApp(
    tester,
    size: size,
    asEmployeeId: EmployeeIds.marc,
  );

  appRouter.go(Routes.toPayroll(StoreIds.sablon));
  await tester.pumpAndSettle();
  return db;
}

/// Answers the identity dialog that guards "Payer" with the given PIN. Marc
/// (the signed-in owner) carries the seeded PIN `78.02.14-153.24`.
const _marcPin = '78.02.14-153.24';

Future<void> _enterPin(WidgetTester tester, String pin) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    ),
    pin,
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Valider'),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _confirmPay(WidgetTester tester) async {
  final payButton = find.widgetWithText(PrimaryButton, 'Payer');
  await tester.ensureVisible(payButton);
  await tester.pumpAndSettle();
  await tester.tap(payButton);
  await tester.pumpAndSettle();

  // Confirmation dialog names the employee.
  expect(find.textContaining('Payer Karim Haddouch'), findsOneWidget);
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Payer'),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pickKarim(WidgetTester tester) async {
  // The employee picker is the shared EmployeeSelector in its search-bar
  // form: type into the bar, then tap his keyed option row.
  // A pick that survived a re-pump shows in place of the bar: clear it first.
  final selected = find.byKey(const ValueKey('employee-selector-selected'));
  if (selected.evaluate().isNotEmpty) {
    await tester.tap(
      find.descendant(of: selected, matching: find.byTooltip('Effacer')),
    );
    await tester.pumpAndSettle();
  }
  final search = find.byKey(const ValueKey('employee-selector-search'));
  await tester.tap(search);
  await tester.pumpAndSettle();
  await tester.enterText(search, 'Karim');
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const ValueKey('employee-option-${EmployeeIds.karim}')),
  );
  await tester.pumpAndSettle();
}

void main() {
  testApp('opens on every employee, with no pay button until one is picked',
      (tester) async {
    await _openPayroll(tester);

    expect(tester.takeException(), isNull);
    // KPIs and the day table are shown straight away, aggregated over the store.
    expect(find.text('Jours payés'), findsOneWidget);
    expect(find.text('Jours non payés'), findsOneWidget);
    // A Début and a Fin pill, and no labels above them.
    expect(find.byType(DateFilter), findsNWidgets(2));
    expect(find.byType(DateField), findsNothing);
    expect(find.byType(FilterToolbar), findsOneWidget);
    expect(find.byType(PaymentStatusBadge), findsWidgets);
    // Paying is per employee — no button while showing everyone.
    expect(find.widgetWithText(PrimaryButton, 'Payer'), findsNothing);
  });

  testApp('a day row opens the payment detail drawer', (tester) async {
    await _openPayroll(tester, size: const Size(1440, 900));
    await _pickKarim(tester);

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
    // The break count replaces the arrival → departure span.
    expect(headers, contains('Pauses'));
    expect(headers, isNot(contains('Horaires')));
    final row = find
        .descendant(of: table, matching: find.byType(PaymentStatusBadge))
        .first;
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(DetailDrawer), findsOneWidget);
    // Bare, like the pointage drawer: the employee is the heading.
    expect(find.text('Détail du paiement'), findsNothing);
    expect(find.byType(PayrollDayDetail), findsOneWidget);
    // The amount breakdown the drawer exists to show.
    expect(find.text('Tarif horaire'), findsOneWidget);
    expect(find.textContaining('Montant ('), findsOneWidget);
    expect(find.text('Session N° 1'), findsOneWidget);

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(find.byType(DetailDrawer), findsNothing);
  });

  // Rule PA1 (SYNC_PERSONNEL_PLAN.md, step 7): a payment that also paid days
  // another tablet had paid first says so in the drawer, with the trop-versé.
  testApp('a « paiement en double » shows its trop-versé in the drawer', (
    tester,
  ) async {
    final db = await _openPayroll(tester, size: const Size(1440, 900));
    await (db.update(db.payrollPeriods)
          ..where((p) => p.id.equals(PayrollPeriodIds.karimSeed)))
        .write(const PayrollPeriodsCompanion(doublePaymentAmount: Value(42)));
    await tester.pumpAndSettle();
    await _pickKarim(tester);

    final paid = find.descendant(
      of: find.byType(DataTable),
      matching: find.text('Payé'),
    );
    await tester.ensureVisible(paid.first);
    await tester.tap(paid.first);
    await tester.pumpAndSettle();

    final banner = find.byKey(const ValueKey('payroll-double-payment'));
    await tester.scrollUntilVisible(
      banner,
      200,
      scrollable: find
          .descendant(
            of: find.byType(DetailDrawer),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Paiement en double'), findsOneWidget);
    expect(find.textContaining('Trop-versé'), findsOneWidget);
  });

  testApp('picking an employee narrows the view and reveals "Payer"',
      (tester) async {
    await _openPayroll(tester);
    await _pickKarim(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Jours payés'), findsOneWidget);
    expect(find.text('Heures supplémentaires'), findsNothing);
    // Karim has a paid day and an unpaid day in the seed → both badges render.
    expect(find.byType(PaymentStatusBadge), findsWidgets);
    expect(find.widgetWithText(PrimaryButton, 'Payer'), findsOneWidget);
  });

  testApp('the employee view survives the narrow and portrait breakpoints',
      (tester) async {
    for (final size in const [Size(1024, 600), Size(800, 1280)]) {
      await _openPayroll(tester, size: size);
      await _pickKarim(tester);

      expect(tester.takeException(), isNull, reason: '$size');
      expect(find.text('Jours payés'), findsOneWidget, reason: '$size');
      // Dates on the strip at 1024; behind the filter icon on a small
      // tablet, as on a phone.
      if (size.width >= 840) {
        expect(find.byType(DateFilter), findsNWidgets(2), reason: '$size');
      } else {
        expect(find.byType(DateFilter), findsNothing, reason: '$size');
        expect(find.byType(FilterSheetButton), findsOneWidget, reason: '$size');
      }
    }
  });

  testApp('"Payer" confirms, asks for the PIN, then flips the days to paid',
      (tester) async {
    final db = await _openPayroll(tester);
    await _pickKarim(tester);

    final attendance = AttendanceRepository(db);
    expect(
      (await attendance.attendance(AttendanceIds.karim1))!.paymentStatus,
      PaymentStatus.unpaid,
    );

    await _confirmPay(tester);

    // The identity dialog stands between the confirmation and the write.
    expect(find.text('Numéro PIN'), findsOneWidget);
    await _enterPin(tester, _marcPin);

    expect(find.text('Paiement enregistré'), findsOneWidget);
    expect(
      (await attendance.attendance(AttendanceIds.karim1))!.paymentStatus,
      PaymentStatus.paid,
    );
  });

  testApp('the drawer\'s « Payer ce jour » settles that one day only, then '
      'closes', (tester) async {
    final db = await _openPayroll(tester, size: const Size(1440, 900));
    final attendance = AttendanceRepository(db);
    // Fatima has two unpaid finished days in range: yesterday and 3 days ago.
    for (final id in [AttendanceIds.fatima1, AttendanceIds.fatima3]) {
      expect(
        (await attendance.attendance(id))!.paymentStatus,
        PaymentStatus.unpaid,
      );
    }

    // Most recent first: her first row is yesterday's.
    final row = find
        .descendant(
          of: find.byType(DataTable),
          matching: find.text('Fatima Ezzahra'),
        )
        .first;
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(PayrollDayDetail), findsOneWidget);

    final button = find.widgetWithText(PrimaryButton, 'Payer ce jour');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    // One day in the confirmation, not the page's range.
    expect(find.textContaining('Payer Fatima Ezzahra'), findsOneWidget);
    expect(find.textContaining('1 jour'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Payer'),
      ),
    );
    await tester.pumpAndSettle();
    await _enterPin(tester, _marcPin);

    expect(find.text('Paiement enregistré'), findsOneWidget);
    expect(find.byType(DetailDrawer), findsNothing);
    expect(
      (await attendance.attendance(AttendanceIds.fatima1))!.paymentStatus,
      PaymentStatus.paid,
    );
    expect(
      (await attendance.attendance(AttendanceIds.fatima3))!.paymentStatus,
      PaymentStatus.unpaid,
    );
  });

  // Audit L9: what was confirmed is what gets paid — or nothing.
  testApp('a rate changed during the PIN: nothing is paid, and it says so', (
    tester,
  ) async {
    final db = await _openPayroll(tester);
    await _pickKarim(tester);
    await _confirmPay(tester);
    expect(find.text('Numéro PIN'), findsOneWidget);

    // Somebody edits Karim's rate while the payer types the PIN.
    final employees = EmployeeRepository(db);
    final karim = (await employees.employee(EmployeeIds.karim))!;
    await employees.update(karim.id, pay: karim.pay + 1);
    await _enterPin(tester, _marcPin);

    expect(find.textContaining("ont changé depuis l'aperçu"), findsOneWidget);
    expect(find.text('Paiement enregistré'), findsNothing);
    expect(
      (await AttendanceRepository(db).attendance(AttendanceIds.karim1))!
          .paymentStatus,
      PaymentStatus.unpaid,
    );
  });

  testApp('a wrong PIN leaves the days unpaid', (tester) async {
    final db = await _openPayroll(tester);
    await _pickKarim(tester);

    await _confirmPay(tester);
    await _enterPin(tester, '00.00.00-000.00');

    // Dialog stays open, days untouched.
    expect(find.text('Numéro incorrect. Réessayez.'), findsOneWidget);
    expect(
      (await AttendanceRepository(db).attendance(AttendanceIds.karim1))!
          .paymentStatus,
      PaymentStatus.unpaid,
    );
  });

  testApp('the paginator stays hidden while the rows fit one page of 10', (tester) async {
    await _openPayroll(tester);
    expect(find.byType(Paginator), findsOneWidget);
    final pager = tester.widget<Paginator>(find.byType(Paginator));
    expect(pager.pageSize, 10);
    expect(pager.totalCount, inInclusiveRange(1, 10));
    // Shown only past 10 (see the Paginator component tests).
    expect(find.textContaining(RegExp(r'^1–\d+ sur \d+$')), findsNothing);
    expect(find.byKey(const ValueKey('paginator-page-size')), findsNothing);
  });

  testApp('a phone: one day card per line, the filters behind an icon', (
    tester,
  ) async {
    await _openPayroll(tester, size: const Size(390, 844));
    expect(tester.takeException(), isNull);
    expect(find.byType(DataTable), findsNothing);
    expect(find.byType(DateFilter), findsNothing);
    expect(find.byType(FilterSheetButton), findsOneWidget);

    // The badge is right-aligned on every card: one right edge, one column.
    final rights = {
      for (final e in find.byType(PaymentStatusBadge).evaluate())
        tester.getTopRight(find.byWidget(e.widget)).dx,
    };
    expect(rights, hasLength(1));

    // The attendance card's header: the date with the status beside it, then
    // the employee with their PIN rather than the date.
    final header = find.byType(CardDateHeader);
    expect(header, findsWidgets);
    expect(
      find.descendant(
        of: header.first,
        matching: find.byType(PaymentStatusBadge),
      ),
      findsOneWidget,
    );
    expect(find.byType(EmployeeCardIdentity), findsWidgets);
    expect(find.byKey(const ValueKey('employee-card-pin')), findsWidgets);
  });
}
