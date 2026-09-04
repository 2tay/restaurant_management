// The product catalogue: cards, rows, and the controls above them.
//
// `router_test.dart` already walks the inventory route at four tablet sizes and
// fails on an overflow. What it cannot see is the half of this screen that only
// exists once somebody touches a control — the list view, the ordering menu —
// or the products it does not happen to seed: a phone-width column, a name too
// long for its card, a quantity that has gone negative.
//
// Everything here drives the real screen through the real database. Nothing is
// asserted about pixels; the assertions are about what is on screen and in what
// order, which is what a redesign is allowed to change and this is what stops
// it changing anything else.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/core/utils/stock_status.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/features/inventory/presentation/pages/inventory_list_page.dart';
import 'package:stock_inventory/features/inventory/presentation/widgets/item_card.dart';
import 'package:stock_inventory/features/inventory/presentation/widgets/item_list_row.dart';
import 'package:drift/drift.dart' show Value;

import 'support/app_harness.dart';

const _store = StoreIds.sablon;

/// A 7" tablet in portrait — the narrowest frame the shell itself survives —
/// the 10" baseline, and a wide desktop window.
const _narrow = Size(720, 1000);
const _tablet = Size(1024, 768);
const _desktop = Size(1600, 900);



Future<void> _openInventory(WidgetTester tester, Size size) async {
  await pumpApp(tester, size: size);
  appRouter.go(Routes.toInventory(_store));
  await tester.pumpAndSettle();
}

/// Switches the catalogue to rows, by pressing the button a user would.
Future<void> _switchToList(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Vue liste').first);
  await tester.pumpAndSettle();
}

/// Picks an entry from the "Trier par" menu.
Future<void> _sortBy(WidgetTester tester, String option) async {
  await tester.tap(find.byTooltip('Trier par').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

/// The product names currently on screen, top to bottom.
///
/// Read off the cards themselves rather than off `find.text`, so a name that
/// also appears in a filter menu or a detail pane cannot join the list.
List<String> _namesInOrder(WidgetTester tester) => [
  for (final card in tester.widgetList<ItemCard>(find.byType(ItemCard)))
    card.view.item.name,
];

/// The "N produits" line above the grid, which counts the whole filtered set
/// rather than the cards the grid has got round to building.
int _countShown(WidgetTester tester) {
  final text = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .firstWhere(
        (data) => data != null && RegExp(r'^\d+ produits$').hasMatch(data),
        orElse: () => null,
      );
  expect(text, isNotNull, reason: 'the product count should be on screen');
  return int.parse(text!.split(' ').first);
}

void main() {
  group('the catalogue renders', () {
    for (final size in [_narrow, _tablet, _desktop]) {
      testApp('as cards at ${size.width.toInt()}x${size.height.toInt()}', (
        tester,
      ) async {
        await _openInventory(tester, size);

        expect(tester.takeException(), isNull);
        expect(find.byType(ItemCard), findsWidgets);
      });

      testApp('as rows at ${size.width.toInt()}x${size.height.toInt()}', (
        tester,
      ) async {
        await _openInventory(tester, size);
        await _switchToList(tester);

        expect(tester.takeException(), isNull);
        expect(find.byType(ItemListRow), findsWidgets);
        expect(find.byType(ItemCard), findsNothing);
      });
    }

    testApp('and comes back to cards when asked', (tester) async {
      await _openInventory(tester, _tablet);
      await _switchToList(tester);
      await tester.tap(find.byTooltip('Vue grille').first);
      await tester.pumpAndSettle();

      expect(find.byType(ItemCard), findsWidgets);
      expect(find.byType(ItemListRow), findsNothing);
    });
  });

  // The phone case is a unit rather than a pumped frame: at 390 logical
  // pixels the shell around this screen — the top bar, the store selector
  // behind it — overflows on its own, which no assertion about the catalogue
  // can see past. These two functions are the whole of the grid's responsive
  // behaviour, and they are what the phone case is actually about.
  group('the grid sizes itself', () {
    test('one column on a phone, more as the window grows', () {
      expect(inventoryGridColumns(390), 1);
      expect(inventoryGridColumns(430), 1);
      expect(inventoryGridColumns(640), 2);
      expect(inventoryGridColumns(800), 3);
      expect(inventoryGridColumns(1100), 4);
      // Never a sixth column, however wide the window. Five is already a lot
      // of photographs across a desktop.
      expect(inventoryGridColumns(2400), 5);
    });

    test('the picture stays about half the card at every column width', () {
      // Not a fixed share: the image is a ratio of the column width and the
      // text block under it is a fixed height, so a narrow column gives the
      // picture proportionally less. The band is what keeps a card from
      // becoming either a poster or a caption with a thumbnail.
      for (final cellWidth in [440.0, 300.0, 260.0, 220.0, 160.0]) {
        final image = inventoryImageHeight(cellWidth);
        final share = image / (image + itemCardTextHeight);
        expect(share, greaterThan(0.45), reason: 'at a $cellWidth column');
        expect(share, lessThan(0.62), reason: 'at a $cellWidth column');
      }
    });

    test('and is bounded at both ends', () {
      expect(inventoryImageHeight(120), 110);
      expect(inventoryImageHeight(900), 190);
    });

    test('a card is not taller than it needs to be', () {
      // The regression this guards: the picture was three quarters of the
      // column width with a 240dp ceiling and the text block was 140dp, which
      // made a card 376dp tall — one and a half products on a phone, six on
      // the 1280dp design baseline.
      for (final cellWidth in [440.0, 300.0, 230.0]) {
        final tile = inventoryImageHeight(cellWidth) + itemCardTextHeight;
        expect(tile, lessThan(320), reason: 'at a $cellWidth column');
      }
    });
  });

  group('ordering', () {
    testApp('sorts by name, both ways', (tester) async {
      await _openInventory(tester, _desktop);

      await _sortBy(tester, 'Nom A → Z');
      final ascending = _namesInOrder(tester);
      expect(ascending, isNotEmpty);
      expect(
        ascending,
        equals([...ascending]..sort(
          (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
        )),
      );

      // Not the reverse of the list above: the grid is lazy, so what is built
      // is the *start* of each ordering rather than all of it. Descending is
      // checked the same way ascending was — against itself.
      await _sortBy(tester, 'Nom Z → A');
      final descending = _namesInOrder(tester);
      expect(descending, isNotEmpty);
      expect(
        descending,
        equals([...descending]..sort(
          (a, b) => b.toLowerCase().compareTo(a.toLowerCase()),
        )),
      );
      expect(descending.first, isNot(equals(ascending.first)));
    });

    testApp('sorts by quantity', (tester) async {
      await _openInventory(tester, _desktop);

      await _sortBy(tester, 'Stock croissant');
      final ascending = [
        for (final card in tester.widgetList<ItemCard>(find.byType(ItemCard)))
          card.view.item.quantity,
      ];
      expect(ascending, isNotEmpty);
      expect(ascending, equals([...ascending]..sort()));
    });

    testApp('survives the list view too', (tester) async {
      await _openInventory(tester, _desktop);
      await _switchToList(tester);
      await _sortBy(tester, 'Nom A → Z');

      expect(tester.takeException(), isNull);
      expect(find.byType(ItemListRow), findsWidgets);
    });

    // The ordering is not a filter, and clearing the filters must not quietly
    // reshuffle the list somebody is reading.
    testApp('outlives a filter reset', (tester) async {
      await _openInventory(tester, _desktop);
      await _sortBy(tester, 'Nom Z → A');
      final ordered = _namesInOrder(tester);

      await tester.enterText(find.byType(TextField).first, 'a');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Effacer les filtres'));
      await tester.pumpAndSettle();

      expect(_namesInOrder(tester), equals(ordered));
    });
  });

  group('the awkward products', () {
    testApp('a very long name and a negative quantity', (tester) async {
      final db = await pumpApp(tester, size: _narrow);
      final target = mockItems.first.id;

      await (db.update(db.items)..where((t) => t.id.equals(target))).write(
        const ItemsCompanion(
          name: Value(
            'Tomates cerises grappe biologiques de Sicile calibre 25/30',
          ),
          quantity: Value(-29),
        ),
      );

      appRouter.go(Routes.toInventory(_store));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Rupture de stock'), findsWidgets);
      expect(find.textContaining('-29'), findsOneWidget);

      await _switchToList(tester);
      expect(tester.takeException(), isNull);
    });

    // Every seeded product without a photo draws the placeholder, so the
    // catalogue coming up clean at all is the assertion. The filter narrows it
    // to the products that need attention, which is where the status pill,
    // the coloured figure and the accent stripe all have to agree.
    testApp('the low-stock filter still narrows the grid', (tester) async {
      await _openInventory(tester, _tablet);
      final all = _countShown(tester);

      await tester.tap(find.text('Stock faible uniquement'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The count line covers the whole filtered set; the cards on screen are
      // only the ones the lazy grid has built, which is why the assertion is
      // made against the count and the cards are checked for agreement.
      expect(_countShown(tester), lessThan(all));
      final built = tester.widgetList<ItemCard>(find.byType(ItemCard));
      expect(built, isNotEmpty);
      expect(built.every((card) => needsAttention(card.view.item)), isTrue);
    });
  });
}
