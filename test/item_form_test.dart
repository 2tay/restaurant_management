// The product wizard: « Ajouter un produit » / « Modifier le produit » in the
// same pop-up as « Ajouter un employé », in four steps — Identité,
// Classification, Gestion stock, Vérification.
//
// The rules these defend:
//
//   **An edit opens showing what is on the record**, including the default
//   supplier — a field that reads "Aucun" for a product that has one is a
//   wrong answer, and saving writes it back.
//
//   **The default supplier is an edit-only field.** At creation there is no
//   supplier link yet for a preference to be about.
//
//   **A step cannot be left half-done** when creating: Suivant waits for its
//   required fields.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/features/inventory/presentation/pages/inventory_list_page.dart';
import 'package:stock_inventory/features/inventory/presentation/widgets/product_wizard_dialog.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';

import 'support/app_harness.dart';

const Size _tablet = Size(1280, 800);
const Size _phone = Size(360, 780);
const String _store = StoreIds.sablon;
const String _supplierLabel = 'Fournisseur par défaut';

void main() {
  /// A seeded product that has a default supplier on file.
  String itemWithSupplier() => mockItems
      .firstWhere(
        (item) => item.storeId == _store && item.defaultSupplierId != null,
      )
      .id;

  /// Opens the catalogue, then the wizard over it.
  Future<void> openWizard(
    WidgetTester tester, {
    Size size = _tablet,
    String? itemId,
  }) async {
    await pumpApp(tester, size: size);
    appRouter.go(Routes.toInventory(_store));
    await tester.pumpAndSettle();
    unawaited(
      showProductWizard(
        tester.element(find.byType(InventoryListPage)),
        storeId: _store,
        itemId: itemId,
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Jumps through the indicator — the way a user picks a step on an edit.
  /// Called on the widget rather than tapped: with the test font the four
  /// labels run wider than Montserrat and the indicator may be compact.
  Future<void> goToStep(WidgetTester tester, int index) async {
    tester
        .widget<WizardStepIndicator>(find.byType(WizardStepIndicator))
        .onStepTapped!(index);
    await tester.pumpAndSettle();
  }

  PrimaryButton primary(WidgetTester tester, String label) =>
      tester.widget<PrimaryButton>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(PrimaryButton),
        ),
      );

  testApp('opens as a four-step wizard over the catalogue', (tester) async {
    await openWizard(tester);

    expect(find.byType(WizardDialog), findsOneWidget);
    expect(find.byType(InventoryListPage), findsOneWidget);
    expect(
      tester.widget<WizardStepIndicator>(find.byType(WizardStepIndicator)).labels,
      ['Identité', 'Classification', 'Gestion stock', 'Vérification'],
    );
  });

  testApp('creating: Suivant waits for the name', (tester) async {
    await openWizard(tester);

    expect(primary(tester, 'Suivant').onPressed, isNull);

    await tester.enterText(
      find
          .descendant(
            of: find.byType(WizardDialog),
            matching: find.byType(TextField),
          )
          .first,
      'Chicons',
    );
    await tester.pump();
    expect(primary(tester, 'Suivant').onPressed, isNotNull);

    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();

    // Classification: no category or unit yet, so still blocked — and no
    // default supplier on a create.
    expect(find.text(_supplierLabel), findsNothing);
    expect(primary(tester, 'Suivant').onPressed, isNull);
  });

  testApp('the edit opens on the supplier already on the record', (
    tester,
  ) async {
    final itemId = itemWithSupplier();
    await openWizard(tester, itemId: itemId);
    await goToStep(tester, 1);

    // The widget's own value, not `find.text`: a dropdown builds every option.
    final picker = tester.widget<AppDropdown<String>>(
      find.byWidgetPredicate(
        (w) => w is AppDropdown<String> && w.label == _supplierLabel,
      ),
    );
    expect(
      picker.value,
      mockItems.firstWhere((i) => i.id == itemId).defaultSupplierId,
    );
  });

  testApp('editing reaches Vérification and saves from there', (
    tester,
  ) async {
    final item = mockItems.firstWhere((i) => i.id == itemWithSupplier());
    await openWizard(tester, itemId: item.id);

    await goToStep(tester, 3);
    expect(find.text(item.name), findsWidgets);
    expect(find.text('Stock minimum'), findsWidgets);

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.byType(WizardDialog), findsNothing);
  });

  testApp('a phone gets it full screen, every step without overflow', (
    tester,
  ) async {
    await openWizard(tester, size: _phone, itemId: itemWithSupplier());

    expect(
      find.descendant(
        of: find.byType(WizardDialog),
        matching: find.byWidgetPredicate(
          (w) => w is Dialog && w.insetPadding == EdgeInsets.zero,
        ),
      ),
      findsOneWidget,
    );

    for (var i = 0; i < 4; i++) {
      expect(tester.takeException(), isNull, reason: 'step ${i + 1}');
      if (i < 3) {
        await tester.tap(find.byTooltip('Suivant').first);
        await tester.pumpAndSettle();
      }
    }
  });
}
