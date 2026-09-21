// Picking products by their card, several at once.
//
// The rules this exists to defend:
//
//   **Every card picked becomes one line on the form, and a product already
//   on the form cannot be picked a second time.**
//
// A doubled line would record the same delivery twice — a quantity nobody
// received, entered by a form that looked right.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/features/stock_movement/presentation/widgets/picker/movement_cart.dart';
import 'package:stock_inventory/features/stock_movement/presentation/widgets/picker/product_picker_sheet.dart';
import 'package:stock_inventory/features/stock_movement/presentation/widgets/picker/supplier_choice.dart';

import 'package:stock_inventory/shared/widgets/widgets.dart';

import 'support/app_harness.dart';

const Size _tablet = Size(1280, 800);
const Size _phone = Size(360, 740);
const String _store = StoreIds.sablon;

// Written out rather than read back from AppLocalizations, so the test fails
// when the screen changes rather than following it.
const String _choose = 'Choisir des produits';
const String _addMore = 'Ajouter un produit';

void main() {
  Future<void> open(WidgetTester tester, String route) async {
    appRouter.go(Routes.toDashboard(_store));
    await tester.pumpAndSettle();
    appRouter.go(route);
    await tester.pumpAndSettle();
  }

  PickerProductCard card(WidgetTester tester, int index) => tester
      .widget<PickerProductCard>(find.byType(PickerProductCard).at(index));

  for (final (name, route) in [
    ('delivery', Routes.toStockIn(_store)),
    ('stock-out', Routes.toStockOut(_store)),
    ('count', Routes.toAdjustment(_store)),
  ]) {
    for (final (sizeName, size) in [('tablet', _tablet), ('phone', _phone)]) {
      testApp(
        '$name on a $sizeName: two cards picked make two lines, never four',
        (tester) async {
          await pumpApp(tester, size: size);
          await open(tester, route);

          expect(find.byType(MovementLineCard), findsNothing);
          await tester.ensureVisible(find.text(_choose));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text(_choose));
          await tester.pumpAndSettle();
          await tester.tap(find.text(_choose));
          await tester.pumpAndSettle();

          await tester.tap(find.byType(PickerProductCard).at(0));
          await tester.tap(find.byType(PickerProductCard).at(1));
          await tester.pump();
          await tester.tap(find.text('Ajouter 2 produits'));
          await tester.pumpAndSettle();

          expect(find.byType(MovementLineCard), findsNWidgets(2));

          // Reopened, the two already on the form are shown picked and locked.
          await tester.ensureVisible(find.text(_addMore));
          await tester.pumpAndSettle();
          await tester.tap(find.text(_addMore));
          await tester.pumpAndSettle();
          expect(card(tester, 0).locked, isTrue);
          expect(card(tester, 1).locked, isTrue);
          expect(card(tester, 2).locked, isFalse);

          // Tapping a locked card does nothing, so confirm stays disabled.
          await tester.tap(find.byType(PickerProductCard).at(0));
          await tester.pump();
          expect(find.text('Sélectionnez des produits'), findsOneWidget);

          await tester.tap(find.byType(PickerProductCard).at(2));
          await tester.pump();
          await tester.tap(find.text('Ajouter 1 produit'));
          await tester.pumpAndSettle();

          expect(find.byType(MovementLineCard), findsNWidgets(3));
        },
      );
    }
  }

  /// Opens [route] and puts the first two products of the picker on it.
  Future<void> pickTwo(WidgetTester tester, String route) async {
    await open(tester, route);
    await tester.ensureVisible(find.text(_choose));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_choose));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PickerProductCard).at(0));
    await tester.tap(find.byType(PickerProductCard).at(1));
    await tester.pump();
    await tester.tap(find.text('Ajouter 2 produits'));
    await tester.pumpAndSettle();
  }

  testApp('a delivery row opens its supplier choice from the chip', (
    tester,
  ) async {
    await pumpApp(tester, size: _tablet);
    await pickTwo(tester, Routes.toStockIn(_store));

    final chips = find.byType(SupplierChip);
    expect(chips, findsWidgets);
    await tester.tap(chips.first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Fournisseur — '), findsOneWidget);
    // Two rows on the form, so the sheet offers to apply the choice to both.
    expect(
      find.text("Utiliser ce fournisseur pour tous les produits qu'il propose"),
      findsOneWidget,
    );
  });

  testApp('"Juste" marks a count as right, and a form of only those '
      'has nothing to save', (tester) async {
    await pumpApp(tester, size: _tablet);
    await pickTwo(tester, Routes.toAdjustment(_store));

    await tester.tap(find.text('Juste').at(0));
    await tester.tap(find.text('Juste').at(1));
    await tester.pumpAndSettle();

    final rows = tester.widgetList<MovementLineCard>(
      find.byType(MovementLineCard),
    );
    expect(rows.map((row) => row.state), everyElement(LineState.done));
    expect(find.text('2 justes', findRichText: true), findsNothing);
    expect(find.textContaining('2 justes', findRichText: true), findsOneWidget);
  });

  testApp('removing a line takes it off the form', (tester) async {
    await pumpApp(tester, size: _tablet);
    await open(tester, Routes.toStockOut(_store));

    await tester.ensureVisible(find.text(_choose));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_choose));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PickerProductCard).at(0));
    await tester.tap(find.byType(PickerProductCard).at(1));
    await tester.pump();
    await tester.tap(find.text('Ajouter 2 produits'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byTooltip('Retirer').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Retirer').first);
    await tester.pumpAndSettle();

    expect(find.byType(MovementLineCard), findsOneWidget);
  });

  // The tablet stays signed in as the manager all day. Whoever moved the
  // stock names themselves at the save — their card, then their CIN, the same
  // check as the pointage board — and the movement is recorded as theirs.
  group('who is at the tablet', () {
    const karimCin = '87.03.11-245.68';

    Future<void> submitStockOut(WidgetTester tester) async {
      await pickTwo(tester, Routes.toStockOut(_store));
      await tester.tap(find.text('Enregistrer la sortie'));
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
      // The check is a database transaction: let it finish in real time
      // before settling the frames it changes.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
    }

    testApp('the movements are saved under the employee who confirmed', (
      tester,
    ) async {
      final db = await pumpApp(tester, size: _tablet);
      await submitStockOut(tester);

      expect(find.text('Qui enregistre ?'), findsOneWidget);
      await tester.tap(find.text('Karim Haddouch'));
      await tester.pumpAndSettle();

      // Someone else's CIN, or a wrong one, is refused and nothing is saved.
      await enterCin(tester, '00.00.00-000.00');
      expect(find.textContaining('Numéro incorrect'), findsOneWidget);

      await enterCin(tester, karimCin);

      final recorded = (await MovementRepository(
        db,
      ).movementsForStore(_store)).take(2).toList();
      for (final movement in recorded) {
        expect(movement.employeeId, EmployeeIds.karim);
        expect(movement.userName, 'Karim Haddouch');
      }
    });

    testApp('closing the sheet saves nothing and keeps the form', (
      tester,
    ) async {
      final db = await pumpApp(tester, size: _tablet);
      final before = (await MovementRepository(
        db,
      ).movementsForStore(_store)).length;
      await submitStockOut(tester);

      await tester.tap(find.byTooltip('Fermer').first);
      await tester.pumpAndSettle();

      expect(
        (await MovementRepository(db).movementsForStore(_store)).length,
        before,
      );
      expect(find.byType(MovementLineCard), findsNWidgets(2));
    });

    testApp('the signed-in manager is on the grid as "Moi"', (tester) async {
      await pumpApp(tester, size: _tablet);
      await submitStockOut(tester);

      expect(find.text('Moi'), findsOneWidget);
    });
  });
}
