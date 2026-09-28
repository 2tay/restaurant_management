// Receiving a commande at the shared kitchen tablet.
//
// The rule this exists to defend:
//
//   **A delivery is recorded as received by the employee who confirmed it
//   with their CIN — not by whoever the tablet is signed in as.**
//
// The tablet stays signed in as the manager all day. Without this, every
// receipt, every movement it files and every price change it writes would
// name the manager, whoever actually stood at the door.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';

import 'support/app_harness.dart';

const Size _tablet = Size(1280, 800);
const String _store = StoreIds.sablon;
const String _order = OrderIds.sentGrossiste;
const String _karimCin = '87.03.11-245.68';

void main() {
  Future<void> openAndConfirm(WidgetTester tester) async {
    appRouter.go(Routes.toDashboard(_store));
    await tester.pumpAndSettle();
    appRouter.go(Routes.toReceiveOrder(_store, _order));
    await tester.pumpAndSettle();

    final confirm = find.text('Confirmer la réception');
    await tester.ensureVisible(confirm.last);
    await tester.pumpAndSettle();
    await tester.tap(confirm.last);
    await tester.pumpAndSettle();
  }

  Future<void> enterCin(WidgetTester tester, String cin) async {
    final dialog = find.byType(IdentityPromptDialog);
    await tester.enterText(
      find.descendant(of: dialog, matching: find.byType(TextField)),
      cin,
    );
    await tester.pump();
    await tester.tap(
      find.descendant(of: dialog, matching: find.text('Valider')),
    );
    // The check and the receipt are database transactions: let them finish
    // in real time before settling the frames they change.
    for (var i = 0; i < 2; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
    }
  }

  testApp('the receipt and its movements are recorded under the employee', (
    tester,
  ) async {
    final db = await pumpApp(tester, size: _tablet);
    await openAndConfirm(tester);

    expect(find.text('Qui enregistre ?'), findsOneWidget);
    await tester.tap(find.text('Karim Haddouch'));
    await tester.pumpAndSettle();

    await enterCin(tester, '00.00.00-000.00');
    expect(find.textContaining('Numéro incorrect'), findsOneWidget);
    expect(await OrderRepository(db).receiptsForOrder(_order), isEmpty);

    await enterCin(tester, _karimCin);

    final receipts = await OrderRepository(db).receiptsForOrder(_order);
    expect(receipts, hasLength(1));
    expect(receipts.single.receivedByName, 'Karim Haddouch');
    expect(receipts.single.receivedByEmployeeId, EmployeeIds.karim);

    final filed = [
      for (final movement in await MovementRepository(
        db,
      ).movementsForStore(_store))
        if (movement.receiptId == receipts.single.id) movement,
    ];
    expect(filed, isNotEmpty);
    for (final movement in filed) {
      expect(movement.employeeId, EmployeeIds.karim);
    }
  });

  testApp('closing the sheet receives nothing', (tester) async {
    final db = await pumpApp(tester, size: _tablet);
    await openAndConfirm(tester);

    await tester.tap(find.byTooltip('Fermer').first);
    await tester.pumpAndSettle();

    expect(await OrderRepository(db).receiptsForOrder(_order), isEmpty);
    expect(find.text('Confirmer la réception'), findsWidgets);
  });
}
