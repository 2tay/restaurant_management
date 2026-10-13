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
import 'package:stock_inventory/core/theme/app_colors.dart';
import 'package:stock_inventory/core/theme/app_spacing.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/core/utils/stock_status.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/features/inventory/presentation/pages/inventory_list_page.dart';
import 'package:stock_inventory/features/inventory/presentation/widgets/item_card.dart';
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
        expect(find.byType(DataTable), findsWidgets);
        expect(find.byType(ItemCard), findsNothing);
      });
    }

    testApp('and comes back to cards when asked', (tester) async {
      await _openInventory(tester, _tablet);
      await _switchToList(tester);
      await tester.tap(find.byTooltip('Vue grille').first);
      await tester.pumpAndSettle();

      expect(find.byType(ItemCard), findsWidgets);
      expect(find.byType(DataTable), findsNothing);
    });
  });

  // The phone case is a unit rather than a pumped frame: at 390 logical
  // pixels the shell around this screen overflows on its own, which no
  // assertion about the catalogue can see past.
  group('the grid sizes itself', () {
    test('one card per line on a phone, more as the window grows', () {
      // The photo sits beside the name, so a card wants about 300dp.
      expect(inventoryGridColumns(360), 1);
      expect(inventoryGridColumns(430), 1);
      expect(inventoryGridColumns(599), 1);
      expect(inventoryGridColumns(640), 2);
      expect(inventoryGridColumns(1000), 3);
      // Never a fifth column, however wide the window.
      expect(inventoryGridColumns(2400), 4);
    });

    test('a 1280dp window shows three cards across', () {
      const pane = 1280.0 - AppSizing.sidebarWidthExpanded - AppSpacing.xl * 2;
      expect(inventoryGridColumns(pane), 3);
      expect(itemCardHeight, lessThan(260));
    });
  });

  // The mock-up: photo beside the name, « Stock actuel » with the status,
  // supplier and category, then Qté min / Qté max where « Expire le » was.
  group('the card', () {
    for (final size in [const Size(390, 844), _tablet]) {
      testApp('shows the mock-up\'s blocks at ${size.width.toInt()}', (
        tester,
      ) async {
        await _openInventory(tester, size);
        expect(tester.takeException(), isNull);

        final card = find.byType(ItemCard).first;
        Finder inCard(String text) =>
            find.descendant(of: card, matching: find.text(text));

        expect(inCard('Stock actuel'), findsOneWidget);
        // No supplier on the card any more.
        expect(inCard('Fournisseur'), findsNothing);
        expect(inCard('Catégorie'), findsOneWidget);
        expect(
          find.descendant(
            of: card,
            matching: find.textContaining('Qté min', findRichText: true),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: card,
            matching: find.textContaining('Qté max', findRichText: true),
          ),
          findsOneWidget,
        );
        // The status in the employees' role-badge shape.
        expect(
          find.descendant(
            of: card,
            matching: find.byKey(const ValueKey('item-card-status')),
          ),
          findsOneWidget,
        );
      });
    }
  });

  group('the catalogue controls', () {
    testApp('a phone has no grid / table toggle', (tester) async {
      await _openInventory(tester, const Size(390, 844));

      expect(find.byTooltip('Vue tableau'), findsNothing);
      expect(find.byType(ItemCard), findsWidgets);
    });

    testApp('« Stock faible uniquement » puts a red edge on every card', (
      tester,
    ) async {
      await _openInventory(tester, _tablet);
      const edge = ValueKey('item-card-alert-edge');
      expect(find.byKey(edge), findsNothing);

      await tester.tap(find.text('Stock faible uniquement').first);
      await tester.pumpAndSettle();

      final cards = find.byType(ItemCard).evaluate().length;
      expect(cards, greaterThan(0));
      expect(find.byKey(edge), findsNWidgets(cards));
    });

    for (final size in [_tablet, _desktop]) {
      testApp('the table does not scroll sideways at ${size.width.toInt()}', (
        tester,
      ) async {
        await _openInventory(tester, size);
        await _switchToList(tester);

        expect(tester.takeException(), isNull);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is SingleChildScrollView &&
                w.scrollDirection == Axis.horizontal,
          ),
          findsNothing,
        );
      });
    }
  });

  group('ordering', () {
    testApp('sorts by name, both ways', (tester) async {
      await _openInventory(tester, _desktop);

      await _sortBy(tester, 'Nom A → Z');
      final ascending = _namesInOrder(tester);
      expect(ascending, isNotEmpty);
      expect(
        ascending,
        equals(
          [...ascending]
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())),
        ),
      );

      // Not the reverse of the list above: the grid is lazy, so what is built
      // is the *start* of each ordering rather than all of it. Descending is
      // checked the same way ascending was — against itself.
      await _sortBy(tester, 'Nom Z → A');
      final descending = _namesInOrder(tester);
      expect(descending, isNotEmpty);
      expect(
        descending,
        equals(
          [...descending]
            ..sort((a, b) => b.toLowerCase().compareTo(a.toLowerCase())),
        ),
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
      expect(find.byType(DataTable), findsWidgets);
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

  group('the filter menus', () {
    testApp('are white lists dropped under their pill, like Personnel', (
      tester,
    ) async {
      await _openInventory(tester, _tablet);

      // Catégorie, Fournisseur and the ordering all wear the same dress.
      final menus = tester.widgetList<PopupMenuButton<dynamic>>(
        find.byWidgetPredicate((w) => w is PopupMenuButton),
      );
      final filters = menus.where(
        (m) => const {
          'Catégorie',
          'Fournisseur',
          'Trier par',
        }.contains(m.tooltip),
      );
      expect(filters, hasLength(3));
      for (final menu in filters) {
        expect(menu.color, AppColors.surface, reason: menu.tooltip);
        expect(menu.position, PopupMenuPosition.under, reason: menu.tooltip);
      }

      // « Toutes » still clears a picked category.
      await tester.tap(find.byTooltip('Catégorie').first);
      await tester.pumpAndSettle();
      final before = _countShown(tester);
      final entries = tester
          .widgetList<PopupMenuItem<int>>(
            find.byWidgetPredicate((w) => w is PopupMenuItem<int>),
          )
          .toList();
      expect(entries.length, greaterThan(1));
      await tester.tap(find.byWidget(entries[1]));
      await tester.pumpAndSettle();
      expect(_countShown(tester), lessThan(before));

      await tester.tap(find.byTooltip('Catégorie').first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate((w) => w is PopupMenuItem<int>).first,
      );
      await tester.pumpAndSettle();
      expect(_countShown(tester), before);
    });
  });
}
