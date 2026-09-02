// Where product photos live.
//
// The rules these exist to defend:
//
//   **The database stores a file name, never a path**, so a photo survives a
//   reinstall moving the app's container and a database opened on another
//   machine asks for files rather than for somebody else's `C:\Users\...`.
//
//   **The picked file is copied, not referenced**, so tidying a downloads
//   folder does not blank the catalogue.
//
// `directoryOverride` points the whole thing at a temp folder: these tests have
// no platform channels, and no business writing into the real
// application-support directory.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stock_inventory/data/images/product_images.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('product_images_test');
    ProductImages.directoryOverride = root;
  });

  tearDown(() {
    ProductImages.directoryOverride = null;
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// A file standing in for something the user picked.
  File source(String name, {String contents = 'photo-bytes'}) {
    final file = File(p.join(root.path, name))..writeAsStringSync(contents);
    return file;
  }

  test('a picked file is copied in, not referenced', () async {
    final picked = source('IMG_0042.jpg');
    final name = (await ProductImages.save(picked))!;

    // The original can go. That is the point: a cook who photographs a crate
    // and then clears their downloads must not blank the catalogue.
    picked.deleteSync();

    final stored = (await ProductImages.fileFor(name))!;
    expect(stored.existsSync(), isTrue);
    expect(stored.readAsStringSync(), 'photo-bytes');
  });

  test('what is stored is a name, not a path', () async {
    final name = (await ProductImages.save(source('IMG_0042.jpg')))!;

    expect(name, isNot(contains(Platform.pathSeparator)));
    expect(name, isNot(contains('/')));
    expect(p.isAbsolute(name), isFalse);
  });

  test('the extension is kept so the decoder knows what it has', () async {
    expect(await ProductImages.save(source('a.png')), endsWith('.png'));
    expect(await ProductImages.save(source('b.JPEG')), endsWith('.jpeg'));
  });

  // Two products photographed on the same phone both arrive as IMG_0042.jpg.
  // Storing under the picked name would have the second silently replace the
  // first's photo.
  test('two files picked under the same name do not collide', () async {
    final first = (await ProductImages.save(source('IMG_0042.jpg',
        contents: 'tomatoes')))!;
    final second = (await ProductImages.save(source('IMG_0042.jpg',
        contents: 'potatoes')))!;

    expect(first, isNot(second));
    expect((await ProductImages.fileFor(first))!.readAsStringSync(),
        'tomatoes');
    expect((await ProductImages.fileFor(second))!.readAsStringSync(),
        'potatoes');
  });

  test('no photo resolves to no file rather than to the directory', () async {
    expect(await ProductImages.fileFor(null), isNull);
    expect(await ProductImages.fileFor(''), isNull);
  });

  test('deleting removes the file', () async {
    final name = (await ProductImages.save(source('a.jpg')))!;
    final stored = (await ProductImages.fileFor(name))!;

    await ProductImages.delete(name);
    expect(stored.existsSync(), isFalse);
  });

  // Every filesystem call here is best-effort: the photo is decoration and the
  // product is the record, so none of this is worth failing a save for.
  test('deleting something already gone is not an error', () async {
    await ProductImages.delete('never-existed.jpg');
    await ProductImages.delete(null);
    await ProductImages.delete('');
  });

  test('saving a file that is not there returns no name', () async {
    final missing = File(p.join(root.path, 'gone.jpg'));

    expect(await ProductImages.save(missing), isNull);
  });
}
