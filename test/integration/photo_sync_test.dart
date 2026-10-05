// Photos through a running Supabase (SYNC_PLAN.md, Phase 8).
//
// Tablet A creates a restaurant and gives an article a photo; one pass
// sends the rows and uploads the shrunk photo to the private `photos` store.
// Tablet B joins, and its first pass brings the article and its photo.
// Replacing the photo on A removes the old file from the server.
//
//   supabase start
//   flutter test test/integration --concurrency=1 --dart-define-from-file=config/local.json

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock_inventory/core/config/env.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/device_access.dart';
import 'package:stock_inventory/data/employee_photo_store.dart';
import 'package:stock_inventory/data/images/product_images.dart';
import 'package:stock_inventory/data/providers.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/services/auth_service.dart';
import 'package:stock_inventory/services/photo_sync.dart';
import 'package:stock_inventory/services/sync_service.dart';

import '../support/db_fixture.dart';

void main() {
  final skip = Env.hasServer
      ? false
      : 'no server: run with --dart-define-from-file=config/local.json';

  Future<(AppDatabase, AccountBackend, DeviceAccessController)> tablet() async {
    final db = openEmptyDatabase();
    final backend = SupabaseAccountBackend(
      SupabaseClient(
        Env.supabaseUrl,
        Env.supabasePublishableKey,
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
          authFlowType: AuthFlowType.implicit,
        ),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        accountBackendProvider.overrideWithValue(backend),
        employeePhotoStoreProvider.overrideWithValue(_NoPhotos()),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() => seedDeviceAccessSnapshot(DeviceAccess.demo));
    final controller = container.read(deviceAccessProvider.notifier);
    await controller.hydrate();
    return (db, backend, controller);
  }

  test(
    'a photo taken on one tablet shows on the other',
    () async {
      final run = DateTime.now().microsecondsSinceEpoch;
      final temp = await Directory.systemTemp.createTemp('photos_it_');
      addTearDown(() => temp.delete(recursive: true));
      ProductImages.directoryOverride = Directory(p.join(temp.path, 'app'));
      addTearDown(() => ProductImages.directoryOverride = null);
      final filesA = FolderPhotoFiles(Directory(p.join(temp.path, 'a')));
      final filesB = FolderPhotoFiles(Directory(p.join(temp.path, 'b')));

      final (a, backendA, controllerA) = await tablet();
      await controllerA.signUp('owner-$run@example.test', 'motdepasse-local');
      final owner = await controllerA.createRestaurant(
        restaurantName: 'Resto $run',
        city: 'Namur',
        phone: '081',
        firstName: 'Léa',
        lastName: 'Martin',
        pin: 'PIN-$run',
      );
      final category = (await CatalogRepository(
        a,
      ).createCategory(storeId: owner.storeId, name: 'Légumes'))!;
      final unit = (await CatalogRepository(a).createUnit(
        storeId: owner.storeId,
        name: 'Kilogramme',
        abbreviation: 'kg',
      ))!;
      final item = (await ItemRepository(a).create(
        storeId: owner.storeId,
        name: 'Tomates',
        categoryId: category.id,
        unitId: unit.id,
        lowStockThreshold: 1,
      ))!;
      final picture = img.Image(width: 2000, height: 1000);
      img.fill(picture, color: img.ColorRgb8(30, 140, 60));
      await filesA.write('items', 'tomates-$run.png', img.encodePng(picture));
      await ItemRepository(a).update(item.id, imagePath: 'tomates-$run.png');

      var result = await SyncRunner(
        db: a,
        backend: backendA,
        photoFiles: filesA,
      ).run();
      expect(result.outcome, SyncOutcome.done, reason: result.detail);
      expect(await a.select(a.photoUploads).get(), isEmpty, reason: 'uploaded');

      final stored = await backendA.downloadPhoto(
        '${owner.storeId}/items/tomates-$run.png',
      );
      expect(stored, isNotNull);
      expect(img.decodeImage(stored!)!.width, PhotoSync.maxSide);

      // Tablet B joins and receives the article with its photo.
      final code = await backendA.createJoinCode();
      final (b, backendB, controllerB) = await tablet();
      await controllerB.signUp('manager-$run@example.test', 'motdepasse-local');
      await controllerB.joinWithCode(code);
      result = await SyncRunner(
        db: b,
        backend: backendB,
        photoFiles: filesB,
      ).run();
      expect(result.outcome, SyncOutcome.done, reason: result.detail);
      final onB = (await filesB.file('items', 'tomates-$run.png'))!;
      expect(await onB.exists(), isTrue);

      // A replaces the photo: the old file leaves the server.
      await filesA.write('items', 'tomates2-$run.png', img.encodePng(picture));
      await ItemRepository(a).update(item.id, imagePath: 'tomates2-$run.png');
      await SyncRunner(db: a, backend: backendA, photoFiles: filesA).run();
      expect(
        await backendA.downloadPhoto('${owner.storeId}/items/tomates-$run.png'),
        isNull,
      );
      expect(
        await backendA.downloadPhoto(
          '${owner.storeId}/items/tomates2-$run.png',
        ),
        isNotNull,
      );
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _NoPhotos extends EmployeePhotoStore {
  @override
  Future<void> deleteFor(String employeeId) async {}
}
