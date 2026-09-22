// Achats: Commandes, Réceptions and Fournisseurs, grouped in the sidebar.
//
// What these hold: the group holds the three pages; Réceptions lists what is
// waiting with a button to receive it, and the history of every bon; the
// orders list filters by status tab; a finished order can be reordered in one
// tap; a new order goes through its three steps.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/data/view_models/view_models.dart';
import 'package:stock_inventory/features/orders/presentation/pages/receive_order_page.dart';
import 'package:stock_inventory/features/orders/presentation/widgets/order_row.dart';
import 'package:stock_inventory/models/models.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';

import 'support/app_harness.dart';
import 'support/db_fixture.dart';

const Size _tablet = Size(1280, 900);
const String _store = StoreIds.sablon;

void main() {
  Future<void> open(WidgetTester tester, String route) async {
    appRouter.go(Routes.toDashboard(_store));
    await tester.pumpAndSettle();
    appRouter.go(route);
    await tester.pumpAndSettle();
  }

  testApp('the sidebar groups Commandes, Réceptions and Fournisseurs', (
    tester,
  ) async {
    await pumpApp(tester, size: _tablet);
    await open(tester, Routes.toOrders(_store));

    final sidebar = find.byType(AppSidebar);
    for (final label in ['Achats', 'Commandes', 'Réceptions', 'Fournisseurs']) {
      expect(
        find.descendant(of: sidebar, matching: find.text(label)),
        findsOneWidget,
        reason: label,
      );
    }

    await tester.tap(
      find.descendant(of: sidebar, matching: find.text('Réceptions')),
    );
    await tester.pumpAndSettle();
    expect(find.text('À réceptionner'), findsWidgets);
  });

  testApp('Réceptions: an order waiting has its button to receive it', (
    tester,
  ) async {
    await pumpApp(tester, size: _tablet);
    await open(tester, Routes.toReceptions(_store));

    final receive = find.widgetWithText(PrimaryButton, 'Réceptionner');
    expect(receive, findsWidgets);

    await tester.ensureVisible(receive.first);
    await tester.pumpAndSettle();
    await tester.tap(receive.first);
    await tester.pumpAndSettle();

    expect(find.byType(ReceiveOrderPage), findsOneWidget);
  });

  testApp('Réceptions: the history lists every bon as a table', (tester) async {
    await pumpApp(tester, size: _tablet);
    await open(tester, Routes.toReceptions(_store));

    await tester.tap(find.text('Historique'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AppTable<StoreReceiptRowView>), findsOneWidget);
  });

  testApp('Commandes: a status tab shows only that status', (tester) async {
    await pumpApp(tester, size: _tablet);
    await open(tester, Routes.toOrders(_store));

    await tester.tap(find.textContaining('Brouillons').first);
    await tester.pumpAndSettle();

    final rows = tester.widgetList<OrderRow>(find.byType(OrderRow));
    expect(rows, isNotEmpty);
    for (final row in rows) {
      expect(row.view.order.status, PurchaseOrderStatus.draft);
    }
  });

  testApp('Commandes: a finished order is reordered in one tap', (
    tester,
  ) async {
    final db = await pumpApp(tester, size: _tablet);
    final before = (await OrderRepository(db).orders(_store)).length;
    await open(tester, Routes.toOrders(_store));

    await tester.tap(find.textContaining('Terminées').first);
    await tester.pumpAndSettle();
    final duplicate = find.widgetWithText(SecondaryButton, 'Dupliquer');
    expect(duplicate, findsWidgets);
    await tester.ensureVisible(duplicate.first);
    await tester.pumpAndSettle();
    await tester.tap(duplicate.first);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    final after = await OrderRepository(db).orders(_store);
    expect(after.length, before + 1);
    expect(
      after.where((o) => o.status == PurchaseOrderStatus.draft).length,
      greaterThan(0),
    );
  });

  testApp('a new order shows its three steps', (tester) async {
    await pumpApp(tester, size: _tablet);
    await open(tester, Routes.toNewOrder(_store));

    for (final label in ['Fournisseur', 'Produits', 'Récapitulatif']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
  });

  group('the store receipt history', () {
    late AppDatabase db;

    setUp(() async => db = await openSeededDatabase());

    test('numbers each bon by its place in its own order', () async {
      final rows = await OrderRepository(
        db,
      ).watchStoreReceiptRows(_store).first;
      expect(rows, isNotEmpty);

      // Newest first overall…
      for (var i = 1; i < rows.length; i++) {
        expect(
          rows[i - 1].receipt.receivedAt.isBefore(rows[i].receipt.receivedAt),
          isFalse,
        );
      }
      // …and each reference agrees with the one the bon itself carries.
      for (final row in rows) {
        expect(
          row.reference,
          await OrderRepository(db).receiptReferenceOf(row.receipt),
        );
      }
    });
  });
}
