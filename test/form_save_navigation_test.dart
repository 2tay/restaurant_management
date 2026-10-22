// Where a form leaves to once saved: back to where it was opened from, never
// a page pushed on top of it. A page on top leaves the finished form behind
// it, and back returns to it — for « Associer un fournisseur », a form whose
// supplier is no longer in its menu, which threw (a red screen).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'support/seed/dataset/dataset.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';

import 'support/app_harness.dart';

const String _store = StoreIds.sablon;

/// The menu's last entry, which opens the supplier form.
const String _createSupplierLabel = '+ Créer un fournisseur';

Future<void> _pump(WidgetTester tester) =>
    pumpApp(tester, size: const Size(1280, 800));

/// An article of the store with a supplier of the store not linked to it yet.
({String itemId, String supplierName}) _linkable() {
  for (final item in mockItems.where((i) => i.storeId == _store)) {
    final linked = {
      for (final price in mockSupplierPrices)
        if (price.itemId == item.id) price.supplierId,
    };
    for (final supplier in mockSuppliers) {
      if (supplier.storeId == _store && !linked.contains(supplier.id)) {
        return (itemId: item.id, supplierName: supplier.name);
      }
    }
  }
  throw StateError('the demo has no article left to link');
}

Future<void> _tapBack(WidgetTester tester) async {
  await tester.tap(find.byType(BackControl).first);
  await tester.pumpAndSettle();
}

void main() {
  testApp('linking a supplier goes back to the product, and back again '
      'leaves it', (tester) async {
    final target = _linkable();
    await _pump(tester);
    appRouter.go(Routes.toInventory(_store));
    await tester.pumpAndSettle();
    unawaited(appRouter.push(Routes.toItem(_store, target.itemId)));
    await tester.pumpAndSettle();
    unawaited(appRouter.push(Routes.toLinkSupplier(_store, target.itemId)));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<Object?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(target.supplierName).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), '2,50');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Associer'));
    await tester.pumpAndSettle();

    expect(appRouter.state.uri.path, Routes.toItem(_store, target.itemId));
    await _tapBack(tester);
    expect(tester.takeException(), isNull);
    expect(appRouter.state.uri.path, Routes.toInventory(_store));
  });

  testApp('editing a supplier goes back to its page, not a copy on top', (
    tester,
  ) async {
    final supplier = mockSuppliers.firstWhere((s) => s.storeId == _store);
    await _pump(tester);
    appRouter.go(Routes.toSupplier(_store, supplier.id));
    await tester.pumpAndSettle();
    unawaited(appRouter.push(Routes.toEditSupplier(_store, supplier.id)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText).first, 'Nouveau nom');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer').last);
    await tester.pumpAndSettle();

    expect(appRouter.state.uri.path, Routes.toSupplier(_store, supplier.id));
    expect(appRouter.canPop(), isFalse);
  });

  testApp('a supplier created from « Associer » comes back to that form, '
      'chosen', (tester) async {
    final target = _linkable();
    await _pump(tester);
    appRouter.go(Routes.toItem(_store, target.itemId));
    await tester.pumpAndSettle();
    unawaited(appRouter.push(Routes.toLinkSupplier(_store, target.itemId)));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<Object?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_createSupplierLabel).last);
    await tester.pumpAndSettle();
    expect(appRouter.state.uri.path, Routes.toAddSupplier(_store));

    await tester.enterText(find.byType(EditableText).first, 'Primeurs Dupont');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer').last);
    await tester.pumpAndSettle();

    expect(
      appRouter.state.uri.path,
      Routes.toLinkSupplier(_store, target.itemId),
    );
    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byType(DropdownButtonFormField<Object?>),
        matching: find.text('Primeurs Dupont'),
      ),
      findsOneWidget,
    );
  });

  testApp('sending an order being edited goes back to it, not a second copy', (
    tester,
  ) async {
    await _pump(tester);
    appRouter.go(Routes.toOrder(_store, OrderIds.draftMaraicher));
    await tester.pumpAndSettle();
    unawaited(
      appRouter.push(Routes.toEditOrder(_store, OrderIds.draftMaraicher)),
    );
    await tester.pumpAndSettle();

    // An edit opens on the products; send is on the summary after them.
    await tester.tap(find.text('Continuer').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Envoyer la commande').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Envoyer'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      appRouter.state.uri.path,
      Routes.toOrder(_store, OrderIds.draftMaraicher),
    );
    expect(appRouter.canPop(), isFalse);
  });
}
