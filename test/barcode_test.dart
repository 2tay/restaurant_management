// Scanning a barcode.
//
// The rules this exists to defend:
//
//   **A scan says "one of these"** — so a counted unit takes it as the
//   quantity, and a weighed one (kg, L) asks instead: a 25 kg sack scanned
//   once is not 1 kg.
//
//   **A handheld scanner needs no button** — it types the code fast and ends
//   it with Enter; with nothing focused the screen still gets it. With a text
//   field focused, the field gets the keys and the listener stands aside.
//
//   **A code matches exactly** — trimmed and blind to case, never partially.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/core/utils/item_search.dart';
import 'package:stock_inventory/features/barcode/presentation/barcode_support.dart';
import 'package:stock_inventory/features/barcode/presentation/hardware_scan_listener.dart';
import 'package:stock_inventory/models/models.dart';

Item _item({String? barcode}) => Item(
  id: 'i1',
  storeId: 's1',
  name: 'Coca 33cl',
  categoryId: 'c1',
  unitId: 'u1',
  quantity: 0,
  lowStockThreshold: 1,
  updatedAt: DateTime(2026),
  barcode: barcode,
);

Future<void> _typeFast(WidgetTester tester, String code) async {
  for (final char in code.split('')) {
    await tester.sendKeyEvent(_keyFor(char), character: char);
  }
}

LogicalKeyboardKey _keyFor(String char) => switch (char) {
  '0' => LogicalKeyboardKey.digit0,
  '1' => LogicalKeyboardKey.digit1,
  '2' => LogicalKeyboardKey.digit2,
  '3' => LogicalKeyboardKey.digit3,
  '4' => LogicalKeyboardKey.digit4,
  '5' => LogicalKeyboardKey.digit5,
  '6' => LogicalKeyboardKey.digit6,
  '7' => LogicalKeyboardKey.digit7,
  '8' => LogicalKeyboardKey.digit8,
  _ => LogicalKeyboardKey.digit9,
};

void main() {
  group('a scan says "one of these"', () {
    test('weights and volumes are measured', () {
      for (final unit in ['kg', 'KG', 'g', 'L', 'l', 'cl', 'ml', 'kg.']) {
        expect(isMeasuredUnit(unit), isTrue, reason: unit);
      }
    });

    test('pieces, bottles and crates are counted', () {
      for (final unit in ['pc', 'pièce', 'bt', 'bac', 'caisse', 'boîte', '']) {
        expect(isMeasuredUnit(unit), isFalse, reason: unit);
      }
    });
  });

  group('a code matches exactly', () {
    test('trimmed and blind to case', () {
      final item = _item(barcode: 'AB-5412345001019');
      expect(itemHasBarcode(item, ' ab-5412345001019 '), isTrue);
    });

    test('never partially, never on an empty code', () {
      final item = _item(barcode: '5412345001019');
      expect(itemHasBarcode(item, '54123450010'), isFalse);
      expect(itemHasBarcode(item, '   '), isFalse);
      expect(itemHasBarcode(_item(), '5412345001019'), isFalse);
    });
  });

  group('a handheld scanner needs no button', () {
    testWidgets('a fast burst ending in Enter is a scan', (tester) async {
      final scanned = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: HardwareScanListener(
            onScan: scanned.add,
            child: const Scaffold(body: SizedBox()),
          ),
        ),
      );

      await _typeFast(tester, '5412345001019');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(scanned, ['5412345001019']);
    });

    testWidgets('a burst with no Enter still lands once it stops', (
      tester,
    ) async {
      final scanned = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: HardwareScanListener(
            onScan: scanned.add,
            child: const Scaffold(body: SizedBox()),
          ),
        ),
      );

      await _typeFast(tester, '96385074');
      await tester.pump(const Duration(milliseconds: 200));

      expect(scanned, ['96385074']);
    });

    testWidgets('too short to be a code is not a scan', (tester) async {
      final scanned = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: HardwareScanListener(
            onScan: scanned.add,
            child: const Scaffold(body: SizedBox()),
          ),
        ),
      );

      await _typeFast(tester, '123');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 200));

      expect(scanned, isEmpty);
    });

    testWidgets('a focused text field gets the keys, not the listener', (
      tester,
    ) async {
      final scanned = <String>[];
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: HardwareScanListener(
            onScan: scanned.add,
            child: Scaffold(body: TextField(controller: controller)),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();

      await tester.enterText(find.byType(TextField), '5412345001019');
      await _typeFast(tester, '5412345001019');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 200));

      expect(scanned, isEmpty);
    });
  });
}
