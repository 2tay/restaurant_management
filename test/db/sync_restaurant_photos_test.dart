// Group H: product photos across tablets (SYNC_TESTS_PLAN.md). Employee
// photos are left out with the rest of staff management.

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../support/restaurant_tablets.dart';

void main() {
  late Restaurant r;

  setUp(() async => r = await Restaurant.open(photos: true));

  /// A camera-sized photo in [t]'s product folder.
  Future<void> photo(Tablet t, String name, {int red = 200}) async {
    final picture = img.Image(width: 2000, height: 1200);
    img.fill(picture, color: img.ColorRgb8(red, 60, 40));
    await t.photos!.write('items', name, img.encodePng(picture));
  }

  Future<bool> hasFile(Tablet t, String name) async =>
      (await t.photos!.file('items', name))?.exists() ?? false;

  Future<int> queued(Tablet t) async =>
      (await t.db.select(t.db.photoUploads).get()).length;

  /// Every tablet shows the same photo for [itemId], and has its file.
  Future<String?> expectSamePhoto(String itemId) async {
    final names = {
      for (final t in r.tablets.values) (await t.items.item(itemId))?.imagePath,
    };
    expect(names, hasLength(1), reason: 'the tablets show different photos');
    final name = names.single;
    if (name != null) {
      for (final t in r.tablets.values) {
        expect(await hasFile(t, name), isTrue, reason: '$t has no file');
      }
    }
    return name;
  }

  test('H1 — a photo added on the office PC appears on every tablet', () async {
    await photo(r['Bureau'], 'tomates.png');
    await r['Bureau'].items.update(r.tomates.id, imagePath: 'tomates.png');
    await r.settle();
    expect(await expectSamePhoto(r.tomates.id), 'tomates.png');
  });

  test('H2 — a photo added offline goes up when the Wi-Fi is back', () async {
    final bureau = r['Bureau'];
    bureau.offline();
    await photo(bureau, 'saumon.png');
    await bureau.items.update(r.saumon.id, imagePath: 'saumon.png');
    await bureau.sync();
    expect(await queued(bureau), greaterThan(0));
    bureau.online();
    await r.settle();
    expect(await expectSamePhoto(r.saumon.id), 'saumon.png');
    expect(await queued(bureau), 0);
  });

  test(
    'H3 — the photo replaced on two tablets at once: one wins everywhere, '
    'no broken image, the other file leaves the server',
    () async {
      r['Cuisine'].offline();
      r['Bar'].offline();
      await photo(r['Cuisine'], 'oignons-cuisine.png', red: 10);
      await r['Cuisine'].items.update(
        r.oignons.id,
        imagePath: 'oignons-cuisine.png',
      );
      await photo(r['Bar'], 'oignons-bar.png', red: 250);
      await r['Bar'].items.update(r.oignons.id, imagePath: 'oignons-bar.png');
      r['Cuisine'].online();
      r['Bar'].online();
      await r.settle();
      final kept = await expectSamePhoto(r.oignons.id);
      expect(kept, isNotNull);
      final lost = kept == 'oignons-bar.png'
          ? 'oignons-cuisine.png'
          : 'oignons-bar.png';
      expect(
        r.server.photos.keys.where((path) => path.endsWith(lost)),
        isEmpty,
        reason: 'the losing photo stays on the server for ever',
      );
    },
    skip: knownIssue(
      'F14: when two tablets replace one photo, the losing '
      'file is never removed from the server',
    ),
  );

  test(
    'H3b — same as H3: what happens today is the same photo everywhere',
    () async {
      r['Cuisine'].offline();
      r['Bar'].offline();
      await photo(r['Cuisine'], 'oignons-cuisine.png', red: 10);
      await r['Cuisine'].items.update(
        r.oignons.id,
        imagePath: 'oignons-cuisine.png',
      );
      await photo(r['Bar'], 'oignons-bar.png', red: 250);
      await r['Bar'].items.update(r.oignons.id, imagePath: 'oignons-bar.png');
      r['Cuisine'].online();
      r['Bar'].online();
      await r.settle();
      expect(await expectSamePhoto(r.oignons.id), isNotNull);
    },
  );

  test('H4 — a photo added offline to a product deleted elsewhere: no upload '
      'stuck for ever, nothing breaks', () async {
    final cuisine = r['Cuisine'];
    cuisine.offline();
    expect(await r['Bureau'].items.delete(r.saumon.id), isTrue);
    await r.syncAll();
    await photo(cuisine, 'saumon.png');
    await cuisine.items.update(r.saumon.id, imagePath: 'saumon.png');
    cuisine.online();
    await r.settle();
    await r.syncAll();
    for (final t in r.tablets.values) {
      expect(await queued(t), 0, reason: '$t keeps a photo queued');
      expect(await t.items.item(r.saumon.id), isNull, reason: '$t');
    }
  });
}
