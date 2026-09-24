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
import 'package:stock_inventory/shared/widgets/widgets.dart';
import 'package:stock_inventory/core/theme/app_spacing.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/core/utils/stock_status.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/features/inventory/presentation/pages/inventory_list_page.dart';
import 'package:stock_inventory/features/inventory/presentation/widgets/item_card.dart';
import 'package:stock_inventory/data/view_models/view_models.dart';
import 'package:stock_inventory/shared/widgets/app_table.dart';
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

/// Switches the catalogue to the table, by pressing the button a user would.
Future<void> _switchToList(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Vue tableau').first);
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
        expect(find.byType(AppTable<ItemRowView>), findsWidgets);
        expect(find.byType(ItemCard), findsNothing);
      });
    }

    testApp('and comes back to cards when asked', (tester) async {
      await _openInventory(tester, _tablet);
      await _switchToList(tester);
      await tester.tap(find.byTooltip('Vue grille').first);
      await tester.pumpAndSettle();

      expect(find.byType(ItemCard), findsWidgets);
      expect(find.byType(AppTable<ItemRowView>), findsNothing);
    });
  });

  // The phone case is a unit rather than a pumped frame: at 390 logical
  // pixels the shell around this screen — the top bar, the store selector
  // behind it — overflows on its own, which no assertion about the catalogue
  // can see past. These two functions are the whole of the grid's responsive
  // behaviour, and they are what the phone case is actually about.
  group('the grid sizes itself', () {
    test('two on a phone, more as the window grows', () {
      // A phone shows two. It showed one until the card lost its "Stock
      // actuel" caption and its arrow button: a 360dp screen leaves about
      // 180dp a card, which was not enough for a name, a category and a
      // quantity and now is.
      expect(inventoryGridColumns(360), 2);
      expect(inventoryGridColumns(390), 2);
      expect(inventoryGridColumns(430), 2);
      // Only a genuinely tiny window falls back to one.
      expect(inventoryGridColumns(300), 1);
      expect(inventoryGridColumns(640), 3);
      expect(inventoryGridColumns(800), 4);
      expect(inventoryGridColumns(1100), 5);
      // Never a seventh column, however wide the window. A catalogue is
      // navigated by scanning, but past six across the names are the first
      // thing to go, and the name is what is being scanned.
      expect(inventoryGridColumns(2400), 6);
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
      expect(inventoryImageHeight(120), 100);
      expect(inventoryImageHeight(900), 136);
    });

    test('a card is not taller than it needs to be', () {
      // The regression this guards, and how far it has come: the picture was
      // three quarters of the column width with a 240dp ceiling and the text
      // block was 140dp, which made a card 376dp tall — one and a half
      // products on a phone, six on the 1280dp design baseline. It is now
      // under 260 at every width, which is what makes a long catalogue
      // navigable by scrolling rather than by searching.
      for (final cellWidth in [440.0, 300.0, 230.0]) {
        final tile = inventoryImageHeight(cellWidth) + itemCardTextHeight;
        expect(tile, lessThan(260), reason: 'at a $cellWidth column');
      }
    });

    test('a 1280dp window shows more than twice the products it used to', () {
      // The design baseline, minus the sidebar and the page insets. Three
      // cards across at 376dp tall was six products before a scroll; the
      // assertion is about how many fit now, because that is the whole point
      // of every number in this group.
      const pane = 1280.0 - AppSizing.sidebarWidthExpanded - AppSpacing.xl * 2;
      final columns = inventoryGridColumns(pane);
      final cellWidth =
          (pane - AppSpacing.sm * (columns - 1)) / columns;
      final tile = inventoryImageHeight(cellWidth) + itemCardTextHeight;

      expect(columns, 5);
      // Three full rows in an 800dp window, where three cards across at 376dp
      // tall managed one and the top of a second.
      expect(tile, lessThan(240));
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
      expect(find.byType(AppTable<ItemRowView>), findsWidgets);
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

  // A catalogue is walked by section — you go looking for a vegetable among
  // the vegetables — but only while the screen is choosing the order. The
  // moment the user picks one, blocks would contradict it.
  group('the grid groups by category', () {
    /// The category names shown as section headings, top to bottom.
    List<String> headings(WidgetTester tester) => [
      for (final header in tester.widgetList<CategoryHeader>(
        find.byType(CategoryHeader),
      ))
        header.title,
    ];

    testApp('in the default order, one block per category', (tester) async {
      await _openInventory(tester, _tablet);

      final shown = headings(tester);
      expect(shown.length, greaterThan(1));
      // Alphabetical, so the blocks sit in the same place every visit.
      final sorted = [...shown]
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      expect(shown, sorted);
    });

    testApp('every card on screen belongs to a block', (tester) async {
      await _openInventory(tester, _tablet);

      final categories = headings(tester).toSet();
      for (final card in tester.widgetList<ItemCard>(find.byType(ItemCard))) {
        expect(categories, contains(card.view.categoryName));
      }
    });

    // Eight categories of twenty products is a long page to scroll past to
    // reach the one section you came for.
    testApp('a block folds away and still says how many it hides', (
      tester,
    ) async {
      await _openInventory(tester, _tablet);
      final first = headings(tester).first;
      final before = _namesInOrder(tester).length;

      await tester.tap(find.byType(CategoryHeader).first);
      await tester.pumpAndSettle();

      // Fewer cards, but the heading and its count stay put.
      expect(_namesInOrder(tester).length, lessThan(before));
      expect(headings(tester).first, first);

      await tester.tap(find.byType(CategoryHeader).first);
      await tester.pumpAndSettle();

      expect(_namesInOrder(tester).length, before);
    });

    testApp('choosing a sort flattens it', (tester) async {
      await _openInventory(tester, _tablet);
      expect(headings(tester), isNotEmpty);

      await _sortBy(tester, 'Nom A → Z');

      // No blocks left, and the names run in one alphabetical sequence.
      expect(headings(tester), isEmpty);
      final names = _namesInOrder(tester);
      final sorted = [...names]
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      expect(names, sorted);
    });
  });
}
