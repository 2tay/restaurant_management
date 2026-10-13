// Achats: Commandes, Réceptions and Fournisseurs, grouped in the sidebar.
//
// What these hold: the group holds the three pages; Réceptions lists what is
// waiting with a button to receive it, and the history of every bon; the
// orders list filters by status and searches by reference, with its KPI tiles
// and no Dupliquer button; a new order goes through its three steps.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/data/view_models/view_models.dart';
import 'package:stock_inventory/features/orders/presentation/pages/receive_order_page.dart';
import 'package:stock_inventory/features/orders/presentation/widgets/order_status_badge.dart';
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

  testApp('Commandes: the Statut filter shows only that status', (
    tester,
  ) async {
    await pumpApp(tester, size: _tablet);
    await open(tester, Routes.toOrders(_store));

    await tester.tap(find.byType(FilterMenu<PurchaseOrderStatus?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Brouillon').last);
    await tester.pumpAndSettle();

    final badges = tester.widgetList<OrderStatusBadge>(
      find.byType(OrderStatusBadge),
    );
    expect(badges, isNotEmpty);
    for (final badge in badges) {
      expect(badge.status, PurchaseOrderStatus.draft);
    }
  });

  testApp('Commandes: the search finds an order by its reference', (
    tester,
  ) async {
    final db = await pumpApp(tester, size: _tablet);
    final reference = (await OrderRepository(
      db,
    ).orders(_store)).first.reference;
    await open(tester, Routes.toOrders(_store));

    await tester.enterText(
      find.descendant(
        of: find.byType(SearchField),
        matching: find.byType(TextField),
      ),
      reference,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('1 commande'), findsOneWidget);
    expect(find.text(reference), findsWidgets);
  });

  testApp('Commandes: KPI tiles sit above the table, no Dupliquer button', (
    tester,
  ) async {
    await pumpApp(tester, size: _tablet);
    await open(tester, Routes.toOrders(_store));

    expect(tester.takeException(), isNull);
    for (final label in [
      'Montant total',
      'À recevoir',
      'En retard',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    // The date pills read « Début : 01/10/2026 », as on the pointage history.
    expect(find.textContaining('Début :'), findsOneWidget);
    expect(find.textContaining('Fin :'), findsOneWidget);
    expect(find.byType(DataTableWrapper), findsOneWidget);
    expect(find.byTooltip('Dupliquer'), findsNothing);
    expect(find.text('Dupliquer'), findsNothing);
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
