// Drives the redesigned Historique de paiement page: it opens on every
// employee, narrows to one through the filter, and settles that person's
// unpaid days for the shown range.

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

/// Answers the identity dialog that guards "Payer" with the given CIN. Marc
/// (the signed-in owner) carries the seeded CIN `78.02.14-153.24`.
const _marcCin = '78.02.14-153.24';

Future<void> _enterCin(WidgetTester tester, String cin) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    ),
    cin,
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
  // The employee picker is the shared EmployeeSelector combobox: open it,
  // filter to Karim, then tap his keyed option row.
  await tester.tap(find.byType(EmployeeSelector));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, 'Karim');
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
    expect(find.byType(DateField), findsNWidgets(2));
    expect(find.byType(PaymentStatusBadge), findsWidgets);
    // Paying is per employee — no button while showing everyone.
    expect(find.widgetWithText(PrimaryButton, 'Payer'), findsNothing);
  });

  testApp('a day row opens the payment detail drawer', (tester) async {
    await _openPayroll(tester, size: const Size(1440, 900));
    await _pickKarim(tester);

    final detailButton =
        find.widgetWithIcon(IconButton, LucideIcons.eye).first;
    await tester.ensureVisible(detailButton);
    await tester.tap(detailButton);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(DetailDrawer), findsOneWidget);
    expect(find.text('Détail du paiement'), findsOneWidget);
    // The amount breakdown the drawer exists to show.
    expect(find.text('Taux horaire'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(find.byType(DetailDrawer), findsNothing);
  });

  testApp('picking an employee narrows the view and reveals "Payer"',
      (tester) async {
    await _openPayroll(tester);
    await _pickKarim(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Jours payés'), findsOneWidget);
    expect(find.text('Heures supplémentaires'), findsOneWidget);
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
      expect(find.byType(DateField), findsNWidgets(2), reason: '$size');
    }
  });

  testApp('"Payer" confirms, asks for the CIN, then flips the days to paid',
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
    expect(find.text('Numéro CIN'), findsOneWidget);
    await _enterCin(tester, _marcCin);

    expect(find.text('Paiement enregistré'), findsOneWidget);
    expect(
      (await attendance.attendance(AttendanceIds.karim1))!.paymentStatus,
      PaymentStatus.paid,
    );
  });

  testApp('a wrong CIN leaves the days unpaid', (tester) async {
    final db = await _openPayroll(tester);
    await _pickKarim(tester);

    await _confirmPay(tester);
    await _enterCin(tester, '00.00.00-000.00');

    // Dialog stays open, days untouched.
    expect(find.textContaining('tentative'), findsOneWidget);
    expect(
      (await AttendanceRepository(db).attendance(AttendanceIds.karim1))!
          .paymentStatus,
      PaymentStatus.unpaid,
    );
  });
}
