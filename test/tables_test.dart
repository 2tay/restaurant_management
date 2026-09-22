// The tables: the product catalogue, the movement history and the
// dashboard's two panels.
//
// What these hold: each table appears where it should, its headers sort,
// its rows open what they name, and a narrow screen drops columns rather
// than overflowing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart';
import 'package:stock_inventory/data/view_models/view_models.dart';
import 'package:stock_inventory/features/inventory/presentation/widgets/item_detail_view.dart';
import 'package:stock_inventory/features/stock_movement/presentation/widgets/movement_row.dart';
import 'package:stock_inventory/features/stock_movement/presentation/widgets/movement_table.dart';
import 'package:stock_inventory/shared/widgets/app_table.dart';
import 'package:stock_inventory/shared/widgets/view_mode_toggle.dart';

import 'support/app_harness.dart';

const Size _tablet = Size(1280, 800);
const Size _phone = Size(360, 740);
const String _store = StoreIds.sablon;

void main() {
  Future<void> open(WidgetTester tester, Size size, String route) async {
    await pumpApp(tester, size: size);
    appRouter.go(Routes.toDashboard(_store));
    await tester.pumpAndSettle();
    appRouter.go(route);
    await tester.pumpAndSettle();
  }

  /// The product names in the table, top to bottom, as far as it has built.
  List<String> namesInTable(WidgetTester tester) {
    final table = find.byType(AppTable<ItemRowView>);
    final names = <String>[];
    for (final row
        in tester.widget<AppTable<ItemRowView>>(table).rows.take(8)) {
      names.add(row.item.name);
    }
    return names;
  }

  group('the product table', () {
    for (final (name, size) in [('tablet', _tablet), ('phone', _phone)]) {
      testApp('shows on a $name without overflowing', (tester) async {
        await open(tester, size, Routes.toInventory(_store));
        await tester.tap(find.byTooltip('Vue tableau').first);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(AppTable<ItemRowView>), findsOneWidget);
      });
    }

    testApp('the Produit header sorts by name, and again the other way', (
      tester,
    ) async {
      await open(tester, _tablet, Routes.toInventory(_store));
      await tester.tap(find.byTooltip('Vue tableau').first);
      await tester.pumpAndSettle();

      final header = find.descendant(
        of: find.byType(AppTable<ItemRowView>),
        // Headers are set in capitals.
        matching: find.text('PRODUIT'),
      );
      await tester.tap(header);
      await tester.pumpAndSettle();
      final ascending = namesInTable(tester);
      expect(ascending, equals([...ascending]..sort()));

      await tester.tap(header);
      await tester.pumpAndSettle();
      final descending = namesInTable(tester);
      expect(
        descending,
        equals([...descending]..sort((a, b) => b.compareTo(a))),
      );
    });

    testApp('a row opens the product drawer', (tester) async {
      await open(tester, _tablet, Routes.toInventory(_store));
      await tester.tap(find.byTooltip('Vue tableau').first);
      await tester.pumpAndSettle();

      final first = tester
          .widget<AppTable<ItemRowView>>(find.byType(AppTable<ItemRowView>))
          .rows
          .first;
      await tester.tap(
        find.descendant(
          of: find.byType(AppTable<ItemRowView>),
          matching: find.text(first.item.name),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ItemDetailView), findsOneWidget);
    });
  });

  group('the movement history', () {
    testApp('switches between the list and the table', (tester) async {
      await open(tester, _tablet, Routes.toMovements(_store));
      expect(find.byType(MovementRow), findsWidgets);
      expect(find.byType(MovementTable), findsNothing);

      await tester.tap(find.byTooltip('Vue tableau').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(MovementTable), findsOneWidget);
      expect(find.byType(MovementRow), findsNothing);

      await tester.tap(find.byTooltip('Vue liste').first);
      await tester.pumpAndSettle();
      expect(find.byType(MovementRow), findsWidgets);
    });

    testApp('a phone keeps the cards, and offers no table', (tester) async {
      await open(tester, _phone, Routes.toMovements(_store));

      expect(find.byTooltip('Vue tableau'), findsNothing);
      expect(find.byType(MovementRow), findsWidgets);
    });
  });

  testApp('the dashboard shows its activity and alerts as tables', (
    tester,
  ) async {
    await open(tester, _tablet, Routes.toDashboard(_store));

    expect(tester.takeException(), isNull);
    expect(find.byType(AppTable<MovementRowView>), findsOneWidget);
    expect(find.byType(AppTable<ItemRowView>), findsOneWidget);
  });

  testApp('the list/table switch sits at the right end of the filter bar', (
    tester,
  ) async {
    await open(tester, _tablet, Routes.toMovements(_store));

    final toggle = tester.getRect(
      find.byType(ViewModeToggle<MovementsViewMode>),
    );
    final list = tester.getRect(find.byType(MovementRow).first);
    // Its right edge lines up with the list's, give or take a pixel.
    expect((toggle.right - list.right).abs(), lessThan(2));
  });

  testApp('each dashboard panel has "Tout afficher" at its right edge', (
    tester,
  ) async {
    await open(tester, _tablet, Routes.toDashboard(_store));

    // The buttons, not their label: the label sits inside the button's own
    // padding, beside its arrow.
    final buttons = [
      for (final element
          in find
              .ancestor(
                of: find.text('Tout afficher'),
                matching: find.byType(TextButton),
              )
              .evaluate())
        tester.getRect(find.byWidget(element.widget)),
    ];

    for (final type in [AppTable<MovementRowView>, AppTable<ItemRowView>]) {
      final table = tester.getRect(find.byType(type));
      // The button above this table ends at the table's right edge — not
      // somewhere in the middle of the header.
      final above = buttons.where(
        (rect) => rect.bottom <= table.top && rect.left >= table.left,
      );
      expect(above, isNotEmpty, reason: '$type');
      expect(
        above.any((rect) => (table.right - rect.right).abs() < 16),
        isTrue,
        reason: '$type',
      );
    }
  });
}
