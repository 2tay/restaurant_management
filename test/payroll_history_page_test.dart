// Drives the redesigned Historique de paiement page: it opens on every
// employee, narrows to one through the filter, and settles that person's
// unpaid days for the shown range.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/app.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/mock_data/mock_data.dart';
import 'package:stock_inventory/models/models.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';

import 'support/mock_reset.dart';

Future<void> _openPayroll(
  WidgetTester tester, {
  Size size = const Size(1280, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const ProviderScope(child: StockInventoryApp()));
  await tester.pumpAndSettle();

  appRouter.go(Routes.toPayroll(StoreIds.sablon));
  await tester.pumpAndSettle();
}

Future<void> _pickKarim(WidgetTester tester) async {
  // The employee picker is a searchable dropdown: open it, filter to Karim,
  // then tap the single remaining menu entry (scoped to the menu so the table
  // cell of the same name below the fold is not matched instead).
  await tester.tap(find.byType(DropdownMenu<String>));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(DropdownMenu<String>), 'Karim');
  await tester.pumpAndSettle();
  await tester.tap(
    find.widgetWithText(MenuItemButton, 'Karim Haddouch').last,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(restoreMockData);

  testWidgets('opens on every employee, with no pay button until one is picked',
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

  testWidgets('picking an employee narrows the view and reveals "Payer"',
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

  testWidgets('the employee view survives the narrow and portrait breakpoints',
      (tester) async {
    for (final size in const [Size(1024, 600), Size(800, 1280)]) {
      await _openPayroll(tester, size: size);
      await _pickKarim(tester);

      expect(tester.takeException(), isNull, reason: '$size');
      expect(find.text('Jours payés'), findsOneWidget, reason: '$size');
      expect(find.byType(DateField), findsNWidgets(2), reason: '$size');
    }
  });

  testWidgets('"Payer" confirms, then flips the unpaid days to paid',
      (tester) async {
    await _openPayroll(tester);
    await _pickKarim(tester);

    expect(
      MockQueries.attendanceById(AttendanceIds.karim1)!.paymentStatus,
      PaymentStatus.unpaid,
    );

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

    expect(find.text('Paiement enregistré'), findsOneWidget);
    expect(
      MockQueries.attendanceById(AttendanceIds.karim1)!.paymentStatus,
      PaymentStatus.paid,
    );
  });
}
