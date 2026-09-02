// Creating, editing and deleting an article.
//
// The rule these exist to defend:
//
//   **Every change to an article's quantity is a stock movement.**
//
// If that ever stops holding, the movement log becomes a partial record that
// looks complete — worse than no log at all, because people would trust it.
//
// These three groups are lifted from `test/inventory_test.dart`, whose other
// groups cover the movement recorder itself and one that needs `confirmReceipt`.
// Those port in stages 5 and 6; the item writes arrived in stage 4 and are
// covered here rather than shipping untested for a stage.

import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stock_inventory/core/utils/stock_status.dart';
import 'package:stock_inventory/data/images/product_images.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart'
    show CategoryIds, ItemIds, StoreIds, SupplierIds, UnitIds;
import 'package:stock_inventory/models/models.dart';

import '../support/db_fixture.dart';

void main() {
  late AppDatabase db;
  late ItemRepository items;
  late MovementRepository movements;
  late SupplierRepository suppliers;

  late Directory imageRoot;

  setUp(() async {
    db = await openSeededDatabase();
    items = ItemRepository(db);
    movements = MovementRepository(db);
    suppliers = SupplierRepository(db);

    // The repository deletes photo files as products are edited and removed.
    // Pointed at a temp folder: these tests have no platform channels and no
    // business writing into the real application-support directory.
    imageRoot = Directory.systemTemp.createTempSync('items_test_images');
    ProductImages.directoryOverride = imageRoot;
  });

  tearDown(() {
    ProductImages.directoryOverride = null;
    if (imageRoot.existsSync()) imageRoot.deleteSync(recursive: true);
  });

  /// A stored photo, and the file behind it.
  Future<(String, File)> storedPhoto() async {
    final picked = File(p.join(imageRoot.path, 'picked.jpg'))
      ..writeAsStringSync('photo-bytes');
    final name = (await ProductImages.save(picked))!;
    return (name, (await ProductImages.fileFor(name))!);
  }

  /// Quantity as reconstructed from the log alone.
  ///
  /// The invariant this file leans on: an article's quantity is the sum of its
  /// movements, because it starts at zero and only movements change it.
  Future<double> sumOfMovements(String itemId) async {
    var total = 0.0;
    for (final movement in await movements.movementsForItem(itemId)) {
      total += movement.quantity;
    }
    return total;
  }

  Future<Item?> chicons({double quantity = 0, double? openingUnitCost}) =>
      items.create(
        storeId: StoreIds.sablon,
        name: 'Chicons',
        categoryId: CategoryIds.legumes,
        unitId: UnitIds.kg,
        quantity: quantity,
        lowStockThreshold: 4,
        openingUnitCost: openingUnitCost,
      );

  group('creating an article', () {
    test('records the starting quantity as an opening balance', () async {
      final created = await chicons(quantity: 12);

      expect(created, isNotNull);
      expect(created!.quantity, 12);

      // Not written onto the article: recorded, then applied. A newly created
      // article's history opens with a line explaining where its stock came
      // from rather than an unexplained 12 with no entries.
      final log = await movements.movementsForItem(created.id);
      expect(log.length, 1);
      expect(log.single.type, StockMovementType.adjustment);
      expect(log.single.systemQuantity, 0);
      expect(log.single.countedQuantity, 12);
      expect(await sumOfMovements(created.id), 12);
    });

    test('records nothing when it starts empty', () async {
      final created = (await chicons())!;

      expect(created.quantity, 0);
      expect(await movements.movementsForItem(created.id), isEmpty);
    });

    // The product form asks for neither a quantity nor an opening cost any
    // more — it describes the product, and stock arrives through a receipt or
    // an adjustment. That is the shape of the call it makes now.
    test('a product form with no stock fields still creates the article',
        () async {
      final created = (await items.create(
        storeId: StoreIds.sablon,
        name: 'Chicons',
        categoryId: CategoryIds.legumes,
        unitId: UnitIds.kg,
        lowStockThreshold: 4,
      ))!;

      expect(created.quantity, 0);
      expect(created.averageCost, isNull);
      expect(await movements.movementsForItem(created.id), isEmpty);

      // And it reads as out of stock from its first day, which is the truth:
      // the catalogue knows the product, the shelf has none of it.
      expect(stockStatusOf(created), StockStatus.outOfStock);
    });

    test('the maximum defaults to none when nothing asks for one', () async {
      final created = (await chicons())!;

      expect(created.maxStock, 0);
    });

    test('a photo and a default supplier are stored and read back', () async {
      final (name, _) = await storedPhoto();

      final created = (await items.create(
        storeId: StoreIds.sablon,
        name: 'Chicons',
        categoryId: CategoryIds.legumes,
        unitId: UnitIds.kg,
        lowStockThreshold: 4,
        defaultSupplierId: SupplierIds.maraicher,
        imagePath: name,
      ))!;

      final read = (await items.item(created.id))!;
      expect(read.imagePath, name);
      expect(read.defaultSupplierId, SupplierIds.maraicher);
    });

    test('neither is required', () async {
      final created = (await chicons())!;

      expect(created.imagePath, isNull);
      expect(created.defaultSupplierId, isNull);
    });

    test('the maximum is stored and read back', () async {
      final created = (await items.create(
        storeId: StoreIds.sablon,
        name: 'Chicons',
        categoryId: CategoryIds.legumes,
        unitId: UnitIds.kg,
        lowStockThreshold: 4,
        maxStock: 20,
      ))!;

      expect(created.maxStock, 20);
      expect((await items.item(created.id))!.maxStock, 20);
    });

    test('the article and its opening movement arrive together', () async {
      // One transaction, so the state where an article exists with stock and no
      // movement explaining it is not merely unlikely, it is unreachable.
      final created = (await chicons(quantity: 12))!;

      final row = await items.item(created.id);
      final log = await movements.movementsForItem(created.id);
      expect(row!.quantity, 12);
      expect(log, hasLength(1));
      expect(log.single.occurredAt, row.updatedAt);
    });

    test('refuses a barcode another article already has', () async {
      final taken = (await items.item(ItemIds.jupiler))!.barcode!;

      expect(
        await items.create(
          storeId: StoreIds.sablon,
          name: 'Jupiler bis',
          categoryId: CategoryIds.boissons,
          unitId: UnitIds.bac,
          quantity: 0,
          lowStockThreshold: 1,
          barcode: taken,
        ),
        isNull,
      );
    });

    test('stores an empty barcode as null rather than as an empty string',
        () async {
      final created = (await items.create(
        storeId: StoreIds.sablon,
        name: 'Chicons',
        categoryId: CategoryIds.legumes,
        unitId: UnitIds.kg,
        quantity: 0,
        lowStockThreshold: 4,
        barcode: '   ',
      ))!;

      expect(created.barcode, isNull);
    });

    test('the opening cost becomes the average cost', () async {
      final created = (await chicons(quantity: 10, openingUnitCost: 2.40))!;

      expect(created.averageCost, 2.40);
      final log = await movements.movementsForItem(created.id);
      expect(log.single.unitCost, 2.40);
      expect(log.single.averageCostAfter, 2.40);
    });

    test('without one, the cost stays unknown rather than zero', () async {
      final created = (await chicons(quantity: 10))!;

      // Understating beats inventing: an article with no cost on file
      // contributes nothing to the valuation instead of dragging it to zero.
      expect(created.averageCost, isNull);
    });
  });

  group('editing an article', () {
    test('the default supplier can be set, changed and cleared', () async {
      final created = (await chicons())!;

      expect(
        (await items.update(
          created.id,
          defaultSupplierId: SupplierIds.maraicher,
        ))!.defaultSupplierId,
        SupplierIds.maraicher,
      );

      // Clearing needs its own flag: a null `defaultSupplierId` means "not
      // mentioned in this edit", which is what leaves every other untouched
      // field alone.
      expect(
        (await items.update(created.id, clearDefaultSupplier: true))!
            .defaultSupplierId,
        isNull,
      );
    });

    test('replacing a photo deletes the one it replaced', () async {
      final (first, firstFile) = await storedPhoto();
      final created = (await items.create(
        storeId: StoreIds.sablon,
        name: 'Chicons',
        categoryId: CategoryIds.legumes,
        unitId: UnitIds.kg,
        lowStockThreshold: 4,
        imagePath: first,
      ))!;

      final (second, secondFile) = await storedPhoto();
      final updated = (await items.update(created.id, imagePath: second))!;

      expect(updated.imagePath, second);
      expect(secondFile.existsSync(), isTrue);
      expect(
        firstFile.existsSync(),
        isFalse,
        reason: 'the replaced photo is nothing but disk now',
      );
    });

    test('clearing a photo deletes the file', () async {
      final (name, file) = await storedPhoto();
      final created = (await items.create(
        storeId: StoreIds.sablon,
        name: 'Chicons',
        categoryId: CategoryIds.legumes,
        unitId: UnitIds.kg,
        lowStockThreshold: 4,
        imagePath: name,
      ))!;

      expect((await items.update(created.id, clearImage: true))!.imagePath,
          isNull);
      expect(file.existsSync(), isFalse);
    });

    test('an edit that says nothing about the photo keeps it', () async {
      final (name, file) = await storedPhoto();
      final created = (await items.create(
        storeId: StoreIds.sablon,
        name: 'Chicons',
        categoryId: CategoryIds.legumes,
        unitId: UnitIds.kg,
        lowStockThreshold: 4,
        imagePath: name,
      ))!;

      final updated = (await items.update(created.id, name: 'Chicons belges'))!;

      expect(updated.imagePath, name);
      expect(file.existsSync(), isTrue);
    });

    test('the maximum can be changed, and survives an edit that ignores it',
        () async {
      final created = (await items.create(
        storeId: StoreIds.sablon,
        name: 'Chicons',
        categoryId: CategoryIds.legumes,
        unitId: UnitIds.kg,
        lowStockThreshold: 4,
        maxStock: 20,
      ))!;

      expect((await items.update(created.id, maxStock: 30))!.maxStock, 30);

      // An edit that says nothing about the maximum leaves it alone, the way
      // every other untouched field on this form does.
      expect((await items.update(created.id, name: 'Chicons belges'))!.maxStock,
          30);
    });

    test('cannot change the quantity', () async {
      final before = (await items.item(ItemIds.tomates))!.quantity;

      await items.update(ItemIds.tomates, name: 'Tomates grappe');

      final after = (await items.item(ItemIds.tomates))!;
      expect(after.name, 'Tomates grappe');
      expect(
        after.quantity,
        before,
        reason: 'stock moves through the movement log and nowhere else',
      );
    });

    test('keeps its own barcode without colliding with itself', () async {
      final jupiler = (await items.item(ItemIds.jupiler))!;

      expect(
        await items.update(jupiler.id, barcode: jupiler.barcode),
        isNotNull,
      );
    });

    test("refuses another article's barcode", () async {
      final taken = (await items.item(ItemIds.jupiler))!.barcode!;

      expect(await items.update(ItemIds.cola, barcode: taken), isNull);
      expect(
        (await items.item(ItemIds.cola))!.barcode,
        isNot(taken),
        reason: 'a refused edit must not half-apply',
      );
    });

    test('can clear a barcode', () async {
      await items.update(ItemIds.jupiler, clearBarcode: true);
      expect((await items.item(ItemIds.jupiler))!.barcode, isNull);
    });
  });

  group('deleting an article', () {
    test('is refused while it is on an open commande', () async {
      // Poulet is on the sent Grossiste Central commande.
      expect(
        await items.deleteBlockedBy(ItemIds.poulet),
        ItemDeleteBlock.onOpenOrder,
      );
      expect(await items.delete(ItemIds.poulet), isFalse);
      expect(await items.item(ItemIds.poulet), isNotNull);
    });

    test('cascades to its links, price history and movements', () async {
      const id = ItemIds.tomates;
      expect(await suppliers.pricesForItem(id), isNotEmpty);
      expect(await movements.movementsForItem(id), isNotEmpty);

      expect(await items.delete(id), isTrue);

      expect(await items.item(id), isNull);
      expect(await suppliers.pricesForItem(id), isEmpty);
      expect(await movements.movementsForItem(id), isEmpty);

      final history = await db
          .customSelect(
            'SELECT id FROM price_history WHERE item_id = ?',
            variables: [const Variable<String>(id)],
          )
          .get();
      expect(history, isEmpty);
    });

    test('leaves no movement pointing at an article that no longer exists',
        () async {
      for (final item in await items.items(StoreIds.sablon)) {
        await items.delete(item.id);
      }

      for (final movement in await movements.movementsForStore(
        StoreIds.sablon,
      )) {
        expect(
          await items.item(movement.itemId),
          isNotNull,
          reason: '${movement.id} was orphaned',
        );
      }
    });
  });
}
