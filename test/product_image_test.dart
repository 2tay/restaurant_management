// A product photo that arrives from the server while its card is on screen
// (SYNC_PLAN.md, Phase 8).
//
// The card is drawn before the file exists, so the first load fails and shows
// the placeholder. When the file lands, the card has to load it again rather
// than keep the failure it remembered for that path.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/data/images/product_images.dart';
import 'package:stock_inventory/shared/widgets/product_image.dart';

/// A 1×1 transparent PNG.
final List<int> _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
);

void main() {
  late Directory folder;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('product_image_test');
    ProductImages.directoryOverride = folder;
  });

  tearDown(() {
    ProductImages.directoryOverride = null;
    folder.deleteSync(recursive: true);
  });

  /// Lets the file reads and the image decode finish, then draws.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
  }

  testWidgets('a photo that arrives is loaded again, not served from the '
      'failed attempt', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: ProductImage(imagePath: 'carrot.png', size: 80)),
      ),
    );
    await settle(tester);
    // Drawn before the file exists: this first load is the one that fails.
    final before = tester.state(find.byType(Image));

    await tester.runAsync(() => ProductImages.write('carrot.png', _png));
    await settle(tester);

    // A fresh image, so a fresh load. Keeping the same one keeps its failure.
    expect(tester.state(find.byType(Image)), isNot(same(before)));
  });
}
