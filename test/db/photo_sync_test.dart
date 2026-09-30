// Photos between tablets (SYNC_PLAN.md, Phase 8).
//
// The rows naming a photo sync like any row. These tests hold the files:
// queued by triggers when a photo is set, replaced or dropped; shrunk and
// uploaded before the rows go; removed from the server once replaced; and
// downloaded by the other tablet after it receives the row.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/images/product_images.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/models/models.dart';
import 'package:stock_inventory/services/auth_service.dart';
import 'package:stock_inventory/services/photo_sync.dart';
import 'package:stock_inventory/services/sync_service.dart';

import '../support/db_fixture.dart';
import '../support/fake_account_backend.dart';

void main() {
  late FakeAccountBackend server;
  late String organization;
  late Directory temp;

  setUp(() async {
    server = FakeAccountBackend();
    organization = server.addOrganization('Brasserie');
    server.addUser(
      'owner@resto.be',
      'motdepasse',
      organizationId: organization,
    );
    await server.signIn(email: 'owner@resto.be', password: 'motdepasse');
    temp = await Directory.systemTemp.createTemp('photos_test_');
    addTearDown(() => temp.delete(recursive: true));
    // The app's own product folder, used when a replaced photo is deleted
    // locally; no platform folder in a unit test.
    ProductImages.directoryOverride = Directory(p.join(temp.path, 'app'));
    addTearDown(() => ProductImages.directoryOverride = null);
  });

  Future<AppDatabase> newDevice() async {
    final db = openEmptyDatabase();
    await server.registerDevice(await DeviceRepository(db).deviceId());
    await DeviceAccessRepository(db).writeAccount(
      email: 'owner@resto.be',
      organizationId: organization,
      organizationName: 'Brasserie',
      role: 'owner',
    );
    return db;
  }

  FolderPhotoFiles filesOf(String device) =>
      FolderPhotoFiles(Directory(p.join(temp.path, device)));

  /// A photo file in [files]'s folder, as a camera would leave it: big.
  Future<void> photo(FolderPhotoFiles files, String kind, String name) async {
    final picture = img.Image(width: 3000, height: 1500);
    img.fill(picture, color: img.ColorRgb8(200, 60, 40));
    await files.write(kind, name, img.encodePng(picture));
  }

  Future<({Store store, Item item})> shop(AppDatabase db) async {
    final store = await StoreRepository(db).createStore(
      name: 'Brasserie',
      addressLine: '',
      postalCode: '',
      city: 'Namur',
      phone: '081',
    );
    final category = (await CatalogRepository(
      db,
    ).createCategory(storeId: store.id, name: 'Légumes'))!;
    final unit = (await CatalogRepository(
      db,
    ).createUnit(storeId: store.id, name: 'Kilogramme', abbreviation: 'kg'))!;
    final item = (await ItemRepository(db).create(
      storeId: store.id,
      name: 'Tomates',
      categoryId: category.id,
      unitId: unit.id,
      lowStockThreshold: 1,
    ))!;
    return (store: store, item: item);
  }

  Future<List<PhotoUploadRow>> queue(AppDatabase db) =>
      db.select(db.photoUploads).get();

  group('the photo queue', () {
    test('a photo set on an article is queued for upload', () async {
      final db = openEmptyDatabase();
      final s = await shop(db);
      await ItemRepository(db).update(s.item.id, imagePath: 'tomates-1.jpg');

      final queued = (await queue(db)).single;
      expect(queued.kind, 'items');
      expect(queued.fileName, 'tomates-1.jpg');
      expect(queued.operation, 'upload');
      expect(queued.storeId, s.store.id);
    });

    test('a replaced photo queues the old one for removal', () async {
      final db = openEmptyDatabase();
      final s = await shop(db);
      await ItemRepository(db).update(s.item.id, imagePath: 'a.jpg');
      await ItemRepository(db).update(s.item.id, imagePath: 'b.jpg');

      final byName = {for (final e in await queue(db)) e.fileName: e.operation};
      expect(byName, {'a.jpg': 'remove', 'b.jpg': 'upload'});
    });

    test('a deleted article queues its photo for removal', () async {
      final db = openEmptyDatabase();
      final s = await shop(db);
      await ItemRepository(db).update(s.item.id, imagePath: 'a.jpg');
      await ItemRepository(db).delete(s.item.id);
      expect((await queue(db)).single.operation, 'remove');
    });

    test('an employee photo is queued the same way', () async {
      final db = openEmptyDatabase();
      final s = await shop(db);
      final employee = (await EmployeeRepository(db).create(
        storeId: s.store.id,
        firstName: 'Karim',
        lastName: 'B',
        pin: 'PIN-K',
        phone: '0',
        email: 'k@resto.be',
        role: EmployeeRole.staff,
        pay: 15,
      ))!;
      await EmployeeRepository(
        db,
      ).update(employee.id, photoAsset: 'karim-1.png');
      final queued = (await queue(db)).single;
      expect(queued.kind, 'employees');
      expect(queued.fileName, 'karim-1.png');
    });

    test('a photo named by a received row is not queued', () async {
      final db = openEmptyDatabase();
      final s = await shop(db);
      await SyncQuiet.run(
        db,
        () => ItemRepository(db).update(s.item.id, imagePath: 'from-a.jpg'),
      );
      expect(await queue(db), isEmpty);
    });
  });

  group('uploading', () {
    test('shrinks the photo to 1024 px and sends it', () async {
      final db = await newDevice();
      final files = filesOf('a');
      final s = await shop(db);
      await photo(files, 'items', 'big.png');
      await ItemRepository(db).update(s.item.id, imagePath: 'big.png');

      expect(
        await PhotoSync(db: db, backend: server, files: files).upload(),
        1,
      );

      final sent = server.photos['${s.store.id}/items/big.png']!;
      final decoded = img.decodeImage(sent)!;
      expect(decoded.width, 1024);
      expect(decoded.height, 512);
      expect(await queue(db), isEmpty);
    });

    test('keeps the photo queued when offline', () async {
      final db = await newDevice();
      final files = filesOf('a');
      final s = await shop(db);
      await photo(files, 'items', 'big.png');
      await ItemRepository(db).update(s.item.id, imagePath: 'big.png');
      server.failNext = const AccountException(AccountErrorCode.network);

      final result = await SyncRunner(
        db: db,
        backend: server,
        photoFiles: files,
      ).run();

      expect(result.outcome, SyncOutcome.offline);
      final queued = (await queue(db)).single;
      expect(queued.attempts, 1);
      expect(server.photos, isEmpty);
    });

    test(
      'a replaced photo leaves the server after the change is sent',
      () async {
        final db = await newDevice();
        final files = filesOf('a');
        final s = await shop(db);
        await photo(files, 'items', 'old.png');
        await ItemRepository(db).update(s.item.id, imagePath: 'old.png');
        await SyncRunner(db: db, backend: server, photoFiles: files).run();
        expect(server.photos.keys, ['${s.store.id}/items/old.png']);

        await photo(files, 'items', 'new.png');
        await ItemRepository(db).update(s.item.id, imagePath: 'new.png');
        await SyncRunner(db: db, backend: server, photoFiles: files).run();

        expect(server.photos.keys, ['${s.store.id}/items/new.png']);
        expect(server.removedPhotos, ['${s.store.id}/items/old.png']);
        expect(await queue(db), isEmpty);
      },
    );
  });

  test('a photo added on one tablet appears on the other', () async {
    final a = await newDevice();
    final b = await newDevice();
    final filesA = filesOf('a');
    final filesB = filesOf('b');
    final s = await shop(a);
    await photo(filesA, 'items', 'tomates.png');
    await ItemRepository(a).update(s.item.id, imagePath: 'tomates.png');

    await SyncRunner(db: a, backend: server, photoFiles: filesA).run();
    await SyncRunner(db: b, backend: server, photoFiles: filesB).run();

    expect((await ItemRepository(b).item(s.item.id))!.imagePath, 'tomates.png');
    final onB = (await filesB.file('items', 'tomates.png'))!;
    expect(await onB.exists(), isTrue);
    expect(await queue(b), isEmpty, reason: 'B has nothing to send back');
  });

  test('a photo the server does not have is skipped, not fatal', () async {
    final a = await newDevice();
    final b = await newDevice();
    final s = await shop(a);
    // A names a photo whose file never reached the server.
    await ItemRepository(a).update(s.item.id, imagePath: 'lost.png');
    await SyncRunner(db: a, backend: server, photoFiles: filesOf('a')).run();

    final result = await SyncRunner(
      db: b,
      backend: server,
      photoFiles: filesOf('b'),
    ).run();
    expect(result.outcome, SyncOutcome.done);
    expect(
      await (await filesOf('b').file('items', 'lost.png'))!.exists(),
      isFalse,
    );
  });

  test('anything that is not an image goes up as it is', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final shrunk = await PhotoSync.shrink(bytes);
    expect(shrunk.bytes, bytes);
  });
}
