// The ordering rules, against the database.
//
// The one they all defend:
//
//   **A commande never changes stock. Only a receipt does.**
//
// Ported from `test/orders_test.dart` — same tests, same assertions. Two things
// are new: the rollback test, which is the acceptance criterion for
// `confirmReceipt` being one transaction, and the stale-order group now reads
// the establishment's own column instead of a mutable global.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/core/utils/item_search.dart';
import 'package:stock_inventory/core/utils/order_status.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart'
    show ItemIds, OrderIds, StoreIds, SupplierIds;
import 'package:stock_inventory/models/models.dart';

import '../support/db_fixture.dart';

void main() {
  late AppDatabase db;
  late ItemRepository items;
  late MovementRepository movements;
  late OrderRepository orders;
  late SupplierRepository suppliers;

  setUp(() async {
    db = await openSeededDatabase();
    items = ItemRepository(db);
    movements = MovementRepository(db);
    orders = OrderRepository(db);
    suppliers = SupplierRepository(db);
  });

  Future<double> quantityOf(String itemId) async =>
      (await items.item(itemId))!.quantity;

  Future<int> movementCount() async =>
      (await movements.movementsForStore(StoreIds.sablon)).length;

  Future<StockMovement> newestMovement() async =>
      (await movements.movementsForStore(StoreIds.sablon)).first;

  Future<PurchaseOrder> orderOf(String id) async => (await orders.order(id))!;

  group('barcodes', () {
    test('are unique across the articles of an establishment', () async {
      final seen = <String, Map<String, String>>{};

      for (final storeId in [StoreIds.sablon, StoreIds.liege]) {
        for (final item in await items.items(storeId)) {
          final barcode = item.barcode;
          if (barcode == null) continue;
          final byStore = seen.putIfAbsent(item.storeId, () => {});
          expect(
            byStore.containsKey(barcode),
            isFalse,
            reason: '$barcode is on both ${byStore[barcode]} and ${item.name} '
                'in ${item.storeId}',
          );
          byStore[barcode] = item.name;
        }
      }
    });

    test('are optional, and absent on fresh produce', () async {
      final all = await items.items(StoreIds.sablon);
      final withBarcode = all.where((i) => i.barcode != null).length;

      expect(withBarcode, greaterThan(0));
      expect(
        withBarcode,
        lessThan(all.length),
        reason: 'an app where everything has one would not prove it is optional',
      );

      // Produce arrives loose in the supplier's crates. If this ever gains a
      // barcode it means somebody treated the field as required.
      expect((await items.item(ItemIds.tomates))!.barcode, isNull);
      expect((await items.item(ItemIds.poulet))!.barcode, isNull);
      expect((await items.item(ItemIds.jupiler))!.barcode, isNotNull);
    });

    test('lookup returns a collection, not a single article', () async {
      final barcode = (await items.item(ItemIds.jupiler))!.barcode!;
      final matches = await items.itemsWithBarcode(StoreIds.sablon, barcode);

      // The shape is the point: multiple barcodes per article is the likeliest
      // next requirement, and a collection absorbs it.
      expect(matches, isA<List<Item>>());
      expect(matches.single.id, ItemIds.jupiler);
    });

    test('conflict detection ignores the article being edited', () async {
      final jupiler = (await items.item(ItemIds.jupiler))!;

      expect(
        await items.barcodeConflict(StoreIds.sablon, jupiler.barcode!),
        isNotNull,
        reason: 'a new article using this code collides',
      );
      expect(
        await items.barcodeConflict(
          StoreIds.sablon,
          jupiler.barcode!,
          excludingItemId: jupiler.id,
        ),
        isNull,
        reason: 'saving an article with its own barcode unchanged must work',
      );
    });

    test('the same barcode in another establishment is not a conflict',
        () async {
      final shared = (await items.item(ItemIds.liegeJupiler))!.barcode;

      expect(shared, (await items.item(ItemIds.jupiler))!.barcode);
      expect(
        (await items.itemsWithBarcode(StoreIds.liege, shared!)).single.id,
        ItemIds.liegeJupiler,
      );
    });

    test('search matches an exact barcode but not a fragment', () async {
      final item = (await items.item(ItemIds.cola))!;
      final barcode = item.barcode!;

      expect(itemMatchesSearch(item, barcode.toLowerCase()), isTrue);
      expect(
        itemMatchesSearch(item, barcode.substring(0, 6)),
        isFalse,
        reason: 'a partial barcode is not a barcode',
      );
      expect(itemMatchesSearch(item, 'coca'), isTrue);
    });
  });

  group('a commande never moves stock', () {
    test('creating a draft leaves quantities alone', () async {
      final before = await quantityOf(ItemIds.tomates);

      await orders.createDraft(
        storeId: StoreIds.sablon,
        supplierId: SupplierIds.maraicher,
        lines: const [
          PurchaseOrderLine(
            id: 'test-line',
            itemId: ItemIds.tomates,
            quantityOrdered: 50,
            unitPrice: 3.20,
          ),
        ],
      );

      expect(await quantityOf(ItemIds.tomates), before);
    });

    test('a new draft continues the seeded series', () async {
      final existing = await orders.orders(StoreIds.sablon);
      final highest = existing
          .map((o) => int.parse(o.reference.split('-').last))
          .reduce((a, b) => a > b ? a : b);

      final created = await orders.createDraft(
        storeId: StoreIds.sablon,
        supplierId: SupplierIds.maraicher,
        lines: const [],
      );

      // A demo must not produce CMD-2026-001 next to CMD-2026-018.
      expect(created.reference, endsWith((highest + 1).toString()));
    });

    // The create form numbers its lines from a counter that restarts with the
    // form, so every commande's first line arrives as `draft-line-1`. The line
    // id is a primary key, so the second commande ever created used to fail on
    // it. `_writeLines` mints the ids now; what the caller sends is the form's
    // own bookkeeping and is not persisted.
    test('two drafts built from the same line ids both survive', () async {
      const lines = [
        PurchaseOrderLine(
          id: 'draft-line-1',
          itemId: ItemIds.tomates,
          quantityOrdered: 50,
          unitPrice: 3.20,
        ),
        PurchaseOrderLine(
          id: 'draft-line-2',
          itemId: ItemIds.poulet,
          quantityOrdered: 10,
          unitPrice: 8.50,
        ),
      ];

      final first = await orders.createDraft(
        storeId: StoreIds.sablon,
        supplierId: SupplierIds.maraicher,
        lines: lines,
      );
      final second = await orders.createDraft(
        storeId: StoreIds.sablon,
        supplierId: SupplierIds.maraicher,
        lines: lines,
      );

      final stored = [
        ...(await orderOf(first.id)).lines,
        ...(await orderOf(second.id)).lines,
      ];

      expect(stored, hasLength(4));
      expect(stored.map((l) => l.id).toSet(), hasLength(4));
      expect(stored.map((l) => l.id), isNot(contains('draft-line-1')));

      // The returned commande has to agree with the table, or the caller is
      // holding ids that address nothing.
      expect(
        first.lines.map((l) => l.id),
        (await orderOf(first.id)).lines.map((l) => l.id),
      );

      // Only the ids changed: the contents and their order are untouched.
      expect(
        (await orderOf(second.id)).lines.map((l) => l.itemId),
        [ItemIds.tomates, ItemIds.poulet],
      );
    });

    test('a line added while editing a draft gets an id of its own', () async {
      final created = await orders.createDraft(
        storeId: StoreIds.sablon,
        supplierId: SupplierIds.maraicher,
        lines: const [
          PurchaseOrderLine(
            id: 'draft-line-1',
            itemId: ItemIds.tomates,
            quantityOrdered: 50,
            unitPrice: 3.20,
          ),
        ],
      );

      // What the edit form hands back: the line already on the commande with
      // its stored id, and a new one numbered from the counter that just
      // restarted with the form.
      final updated = await orders.updateDraft(
        created.id,
        lines: [
          created.lines.single,
          const PurchaseOrderLine(
            id: 'draft-line-2',
            itemId: ItemIds.poulet,
            quantityOrdered: 10,
            unitPrice: 8.50,
          ),
        ],
      );

      expect(updated!.lines, hasLength(2));
      expect(updated.lines.map((l) => l.id).toSet(), hasLength(2));
      expect(updated.lines.map((l) => l.id), isNot(contains('draft-line-2')));
      expect(updated.lines.map((l) => l.itemId), [
        ItemIds.tomates,
        ItemIds.poulet,
      ]);
    });

    test('sending a commande leaves quantities alone', () async {
      final before = await quantityOf(ItemIds.tomates);
      final movementsBefore = await movementCount();

      await orders.send(OrderIds.draftMaraicher);

      expect(
        (await orderOf(OrderIds.draftMaraicher)).status,
        PurchaseOrderStatus.sent,
      );
      expect(await quantityOf(ItemIds.tomates), before);
      expect(await movementCount(), movementsBefore);
    });

    test('but it does count towards on-order', () async {
      final before = await orders.onOrderQuantity(
        StoreIds.sablon,
        ItemIds.tomates,
      );

      await orders.send(OrderIds.draftMaraicher);

      expect(
        await orders.onOrderQuantity(StoreIds.sablon, ItemIds.tomates),
        before + 20,
        reason: 'a draft is not on order; a sent commande is',
      );
    });
  });

  group('status transitions', () {
    test('a sent commande is locked against editing', () async {
      await orders.send(OrderIds.draftMaraicher);
      final order = await orderOf(OrderIds.draftMaraicher);

      expect(orderIsEditable(order), isFalse);

      expect(await orders.updateDraft(order.id, lines: const []), isNull);
      expect(
        (await orderOf(order.id)).lines,
        isNotEmpty,
        reason: 'the supplier already holds this document',
      );
    });

    test('a draft can be deleted; a sent commande cannot', () async {
      expect(await orders.deleteDraft(OrderIds.draftMaraicher), isTrue);
      expect(await orders.order(OrderIds.draftMaraicher), isNull);

      expect(await orders.deleteDraft(OrderIds.sentGrossiste), isFalse);
      expect(await orders.order(OrderIds.sentGrossiste), isNotNull);
    });

    test('deleting a draft takes its lines with it', () async {
      await orders.deleteDraft(OrderIds.draftMaraicher);

      final orphans = await db
          .customSelect(
            'SELECT id FROM purchase_order_lines WHERE order_id = ?',
            variables: [const Variable<String>(OrderIds.draftMaraicher)],
          )
          .get();
      expect(orphans, isEmpty);
    });

    test('a sent commande can be cancelled only before anything arrives',
        () async {
      expect(orderCanCancel(await orderOf(OrderIds.sentGrossiste)), isTrue);

      // Partially received: cancelling would orphan the stock movements the
      // delivered lines already created.
      expect(orderCanCancel(await orderOf(OrderIds.partialBoucherie)), isFalse);

      expect(await orders.cancel(OrderIds.partialBoucherie), isNull);
      expect(
        (await orderOf(OrderIds.partialBoucherie)).status,
        PurchaseOrderStatus.partial,
      );
    });

    test('closing short records the shortfall instead of erasing it', () async {
      await orders.closeShort(OrderIds.partialBoucherie);
      final order = await orderOf(OrderIds.partialBoucherie);

      expect(order.status, PurchaseOrderStatus.received);

      final jambon = order.lines.firstWhere(
        (line) => line.itemId == ItemIds.jambonArdenne,
      );
      expect(jambon.closedShort, isTrue);
      expect(
        jambon.quantityOrdered,
        5,
        reason: 'rewriting the commande to what arrived would erase the '
            'evidence',
      );
      expect(lineShortfall(jambon), 5);

      // And it stops counting as on the way.
      expect(
        await orders.onOrderQuantity(StoreIds.sablon, ItemIds.jambonArdenne),
        0,
      );
    });
  });

  group('receiving', () {
    test('generates one stock movement per line and moves the stock', () async {
      final before = await quantityOf(ItemIds.poulet);
      final movementsBefore = await movementCount();

      final receipt = await orders.confirmReceipt(
        orderId: OrderIds.sentGrossiste,
        lines: const [
          ReceiptDraftLine(
            itemId: ItemIds.poulet,
            quantityOrdered: 15,
            quantityReceived: 15,
            orderedUnitPrice: 12.80,
            actualUnitPrice: 12.80,
          ),
        ],
      );

      expect(receipt, isNotNull);
      expect(await quantityOf(ItemIds.poulet), before + 15);
      expect(await movementCount(), movementsBefore + 1);

      final movement = await newestMovement();
      expect(movement.type, StockMovementType.stockIn);
      expect(movement.quantity, 15);
      // The trail: quantity -> movement -> receipt -> commande -> supplier.
      expect(movement.receiptId, receipt!.id);
      expect(movement.orderId, OrderIds.sentGrossiste);
      expect(movement.supplierId, SupplierIds.grossisteCentral);
    });

    test('a partly delivered commande stays open on the untouched lines',
        () async {
      await orders.confirmReceipt(
        orderId: OrderIds.sentGrossiste,
        lines: const [
          ReceiptDraftLine(
            itemId: ItemIds.poulet,
            quantityOrdered: 15,
            quantityReceived: 15,
            orderedUnitPrice: 12.80,
            actualUnitPrice: 12.80,
          ),
        ],
      );

      expect(
        (await orderOf(OrderIds.sentGrossiste)).status,
        PurchaseOrderStatus.partial,
      );
      expect(
        await orders.onOrderQuantity(StoreIds.sablon, ItemIds.poulet),
        0,
        reason: 'that line is complete',
      );
      expect(
        await orders.onOrderQuantity(StoreIds.sablon, ItemIds.riz),
        25,
        reason: 'the rice has not arrived',
      );
    });

    test('closing a line short settles it without inventing stock', () async {
      final before = await quantityOf(ItemIds.riz);

      await orders.confirmReceipt(
        orderId: OrderIds.sentGrossiste,
        lines: const [
          ReceiptDraftLine(
            itemId: ItemIds.riz,
            quantityOrdered: 25,
            quantityReceived: 10,
            orderedUnitPrice: 1.95,
            actualUnitPrice: 1.95,
            closeShort: true,
          ),
        ],
      );

      expect(await quantityOf(ItemIds.riz), before + 10);

      final line = (await orderOf(
        OrderIds.sentGrossiste,
      )).lines.firstWhere((l) => l.itemId == ItemIds.riz);
      expect(line.closedShort, isTrue);
      expect(lineShortfall(line), 15);
      expect(await orders.onOrderQuantity(StoreIds.sablon, ItemIds.riz), 0);
    });

    test('receiving every line closes the commande', () async {
      final order = await orderOf(OrderIds.sentGrossiste);

      await orders.confirmReceipt(
        orderId: order.id,
        lines: [
          for (final line in order.lines)
            ReceiptDraftLine(
              itemId: line.itemId,
              quantityOrdered: line.quantityOrdered,
              quantityReceived: line.quantityOrdered,
              orderedUnitPrice: line.unitPrice,
              actualUnitPrice: line.unitPrice,
            ),
        ],
      );

      final after = await orderOf(order.id);
      expect(after.status, PurchaseOrderStatus.received);
      expect(after.closedAt, isNotNull);
    });

    test('over-delivery is accepted and recorded', () async {
      final before = await quantityOf(ItemIds.mayonnaise);

      await orders.confirmReceipt(
        orderId: OrderIds.sentGrossiste,
        lines: const [
          ReceiptDraftLine(
            itemId: ItemIds.mayonnaise,
            quantityOrdered: 10,
            quantityReceived: 14,
            orderedUnitPrice: 4.15,
            actualUnitPrice: 4.15,
          ),
        ],
      );

      expect(await quantityOf(ItemIds.mayonnaise), before + 14);
      expect(
        outcomeOf(ordered: 10, received: 14, wasUnordered: false),
        ReceiptLineOutcome.over,
      );
    });

    test('an unordered line moves stock but never touches the commande lines',
        () async {
      final before = await quantityOf(ItemIds.sel);
      final orderedBefore = (await orderOf(OrderIds.sentGrossiste)).lines.length;

      final receipt = await orders.confirmReceipt(
        orderId: OrderIds.sentGrossiste,
        lines: const [
          ReceiptDraftLine(
            itemId: ItemIds.sel,
            quantityOrdered: 0,
            quantityReceived: 5,
            orderedUnitPrice: 0.70,
            actualUnitPrice: 0.70,
            wasUnordered: true,
          ),
        ],
      );

      expect(await quantityOf(ItemIds.sel), before + 5);
      expect(receipt!.lines.single.wasUnordered, isTrue);
      expect(
        (await orderOf(OrderIds.sentGrossiste)).lines.length,
        orderedBefore,
        reason: 'an unordered arrival does not rewrite what was ordered',
      );
    });

    test('a confirmed receipt is attached to its commande', () async {
      final receipt = (await orders.confirmReceipt(
        orderId: OrderIds.sentGrossiste,
        lines: const [
          ReceiptDraftLine(
            itemId: ItemIds.poulet,
            quantityOrdered: 15,
            quantityReceived: 15,
            orderedUnitPrice: 12.80,
            actualUnitPrice: 12.80,
          ),
        ],
      ))!;

      expect(
        (await orders.receiptsForOrder(OrderIds.sentGrossiste)).map((r) => r.id),
        contains(receipt.id),
      );
      expect((await orders.receipt(receipt.id))!.id, receipt.id);
    });

    test('a commande that cannot be received is refused, not asserted on',
        () async {
      // Phase 1 wrote `orderById(orderId)!` here, which was safe only because
      // the data was compiled in.
      expect(
        await orders.receiveBlockedBy('order-that-never-was'),
        ReceiptBlock.noSuchOrder,
      );
      expect(
        await orders.confirmReceipt(
          orderId: 'order-that-never-was',
          lines: const [],
        ),
        isNull,
      );

      expect(
        await orders.receiveBlockedBy(OrderIds.draftMaraicher),
        ReceiptBlock.notReceivable,
        reason: 'a draft has not been sent, so nothing can have arrived',
      );
      expect(
        await orders.confirmReceipt(
          orderId: OrderIds.draftMaraicher,
          lines: const [],
        ),
        isNull,
      );
    });

    test('a receipt that fails part way through leaves nothing behind',
        () async {
      // The acceptance criterion for confirmReceipt being one transaction.
      // Phase 1 could not half-fail, because five list edits in a row cannot be
      // interrupted; five statements against a database can.
      final pouletBefore = await quantityOf(ItemIds.poulet);
      final rizBefore = await quantityOf(ItemIds.riz);
      final statusBefore = (await orderOf(OrderIds.sentGrossiste)).status;
      final movementsBefore = await movementCount();
      final receiptsBefore =
          (await orders.receiptsForOrder(OrderIds.sentGrossiste)).length;
      final historyBefore = (await suppliers.priceHistoryFor(
        ItemIds.poulet,
        SupplierIds.grossisteCentral,
      )).length;

      await expectLater(
        orders.confirmReceipt(
          orderId: OrderIds.sentGrossiste,
          lines: const [
            ReceiptDraftLine(
              itemId: ItemIds.poulet,
              quantityOrdered: 15,
              quantityReceived: 15,
              orderedUnitPrice: 12.80,
              actualUnitPrice: 14.50,
            ),
            ReceiptDraftLine(
              itemId: ItemIds.riz,
              quantityOrdered: 25,
              quantityReceived: 25,
              orderedUnitPrice: 1.95,
              actualUnitPrice: 1.95,
            ),
            ReceiptDraftLine(
              itemId: 'item-that-never-was',
              quantityOrdered: 0,
              quantityReceived: 3,
              orderedUnitPrice: 0,
              actualUnitPrice: 2.00,
              wasUnordered: true,
            ),
          ],
        ),
        throwsA(isA<StateError>()),
      );

      expect(await quantityOf(ItemIds.poulet), pouletBefore);
      expect(await quantityOf(ItemIds.riz), rizBefore);
      expect((await orderOf(OrderIds.sentGrossiste)).status, statusBefore);
      expect(await movementCount(), movementsBefore);
      expect(
        (await orders.receiptsForOrder(OrderIds.sentGrossiste)).length,
        receiptsBefore,
      );
      expect(
        (await suppliers.priceHistoryFor(
          ItemIds.poulet,
          SupplierIds.grossisteCentral,
        )).length,
        historyBefore,
        reason: 'the first two lines had already updated a price when the '
            'third one failed',
      );
    });
  });

  group('what a delivery does to the value of the stock', () {
    // The bug this group exists for:
    //
    //   100 kg of chicken bought at 8,00 is worth 800. A van arrives with 50 kg
    //   at 10,00, which cost 500. The stock is worth 1 300.
    //
    // The app used to report 1 500 — quantity times the supplier's current
    // price — inventing 200 that nobody ever spent, on the one screen an owner
    // reads to find out what they are holding.

    test('the old stock keeps the price it was bought at', () async {
      // Set the article up as the scenario describes rather than leaning on the
      // seed, so the arithmetic is readable in the failure message.
      final item = (await items.item(ItemIds.poulet))!;
      await movements.recordAdjustment(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        systemQuantity: item.quantity,
        countedQuantity: 0,
      );
      await movements.recordStockIn(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        quantity: 100,
        unitPrice: 8.00,
      );

      final held = (await items.item(ItemIds.poulet))!;
      expect(held.quantity, 100);
      expect(held.averageCost, closeTo(8.00, 0.001));

      await orders.confirmReceipt(
        orderId: OrderIds.sentGrossiste,
        lines: const [
          ReceiptDraftLine(
            itemId: ItemIds.poulet,
            quantityOrdered: 15,
            quantityReceived: 50,
            orderedUnitPrice: 12.80,
            actualUnitPrice: 10.00,
          ),
        ],
      );

      final after = (await items.item(ItemIds.poulet))!;
      expect(after.quantity, 150);
      expect(after.averageCost, closeTo(8.6667, 0.001));
      expect(
        after.quantity * after.averageCost!,
        closeTo(1300, 0.01),
        reason: '1 300 was spent; 1 500 is the bug',
      );
    });

    test('the supplier price still updates to what was charged', () async {
      // The fix is not "stop updating the price". A price is what the *next*
      // unit will cost and it must follow the delivery note; a cost is what the
      // units on the shelf were paid for and must not.
      await orders.confirmReceipt(
        orderId: OrderIds.sentGrossiste,
        lines: const [
          ReceiptDraftLine(
            itemId: ItemIds.poulet,
            quantityOrdered: 15,
            quantityReceived: 15,
            orderedUnitPrice: 12.80,
            actualUnitPrice: 15.00,
          ),
        ],
      );

      expect(
        (await suppliers.priceFor(
          ItemIds.poulet,
          SupplierIds.grossisteCentral,
        ))!.pricePerUnit,
        closeTo(15.00, 0.001),
      );
      // And the cost sits below it, because only 15 of the kilos on hand were
      // bought at 15,00.
      expect((await items.item(ItemIds.poulet))!.averageCost, lessThan(15.00));
    });

    test('two deliveries at two prices average across all of it', () async {
      final item = (await items.item(ItemIds.poulet))!;
      await movements.recordAdjustment(
        storeId: StoreIds.sablon,
        itemId: ItemIds.poulet,
        systemQuantity: item.quantity,
        countedQuantity: 0,
      );

      for (final price in const [8.00, 12.00]) {
        await orders.confirmReceipt(
          orderId: OrderIds.sentGrossiste,
          lines: [
            ReceiptDraftLine(
              itemId: ItemIds.poulet,
              quantityOrdered: 15,
              quantityReceived: 50,
              orderedUnitPrice: 12.80,
              actualUnitPrice: price,
            ),
          ],
        );
      }

      // 400 + 600 spent on 100 kg.
      final after = (await items.item(ItemIds.poulet))!;
      expect(after.quantity, 100);
      expect(after.averageCost, closeTo(10.00, 0.001));
    });

    test('the receipt movement carries the cost it applied', () async {
      final receipt = (await orders.confirmReceipt(
        orderId: OrderIds.sentGrossiste,
        lines: const [
          ReceiptDraftLine(
            itemId: ItemIds.poulet,
            quantityOrdered: 15,
            quantityReceived: 15,
            orderedUnitPrice: 12.80,
            actualUnitPrice: 15.00,
          ),
        ],
      ))!;

      // Receiving goes through the same single writer as a manual stock-in, so
      // it produces the same audit trail rather than a second kind of movement.
      final movement = await newestMovement();
      expect(movement.receiptId, receipt.id);
      expect(movement.unitCost, closeTo(15.00, 0.001));
      expect(
        movement.averageCostAfter,
        closeTo((await items.item(ItemIds.poulet))!.averageCost!, 0.001),
      );
    });

    test('an unordered article with no price on file still gets a cost',
        () async {
      await orders.confirmReceipt(
        orderId: OrderIds.sentGrossiste,
        lines: const [
          ReceiptDraftLine(
            itemId: ItemIds.persil,
            quantityOrdered: 0,
            quantityReceived: 4,
            orderedUnitPrice: 0,
            actualUnitPrice: 1.50,
            wasUnordered: true,
          ),
        ],
      );

      final movement = await newestMovement();
      expect(movement.itemId, ItemIds.persil);
      expect(movement.unitCost, closeTo(1.50, 0.001));
      expect((await items.item(ItemIds.persil))!.averageCost, isNotNull);
    });
  });

  group('prices captured at receiving', () {
    test('a changed price updates the supplier price and writes history',
        () async {
      final before = (await suppliers.priceFor(
        ItemIds.poulet,
        SupplierIds.grossisteCentral,
      ))!.pricePerUnit;
      final historyBefore = (await suppliers.priceHistoryFor(
        ItemIds.poulet,
        SupplierIds.grossisteCentral,
      )).length;

      await orders.confirmReceipt(
        orderId: OrderIds.sentGrossiste,
        lines: const [
          ReceiptDraftLine(
            itemId: ItemIds.poulet,
            quantityOrdered: 15,
            quantityReceived: 15,
            orderedUnitPrice: 12.80,
            actualUnitPrice: 14.50,
          ),
        ],
      );

      expect(
        (await suppliers.priceFor(
          ItemIds.poulet,
          SupplierIds.grossisteCentral,
        ))!.pricePerUnit,
        14.50,
      );

      final history = await suppliers.priceHistoryFor(
        ItemIds.poulet,
        SupplierIds.grossisteCentral,
      );
      expect(history.length, historyBefore + 1);
      expect(history.first.oldPrice, before);
      expect(history.first.newPrice, 14.50);
    });

    test('an unchanged price writes nothing', () async {
      final historyBefore = (await suppliers.priceHistoryFor(
        ItemIds.poulet,
        SupplierIds.grossisteCentral,
      )).length;

      await orders.confirmReceipt(
        orderId: OrderIds.sentGrossiste,
        lines: const [
          ReceiptDraftLine(
            itemId: ItemIds.poulet,
            quantityOrdered: 15,
            quantityReceived: 15,
            orderedUnitPrice: 12.80,
            actualUnitPrice: 12.80,
          ),
        ],
      );

      expect(
        (await suppliers.priceHistoryFor(
          ItemIds.poulet,
          SupplierIds.grossisteCentral,
        )).length,
        historyBefore,
      );
    });

    test('the significant-change threshold is 15% and symmetric', () {
      expect(OrderRules.significantPriceChange, 0.15);

      expect(priceMovedSignificantly(10, 11), isFalse);
      expect(priceMovedSignificantly(10, 12), isTrue);
      expect(priceMovedSignificantly(10, 8), isTrue);

      // No baseline to move from: a first delivery must not be flagged.
      expect(priceMovedSignificantly(0, 20), isFalse);
    });
  });

  group('stale partial commandes', () {
    Future<void> setThreshold(int days) async {
      await (db.update(db.stores)
            ..where((s) => s.id.equals(StoreIds.sablon)))
          .write(StoresCompanion(stalePartialOrderDays: Value(days)));
    }

    test('the threshold defaults to seven days and drives the flag', () async {
      expect(OrderRules.defaultStalePartialDays, 7);
      expect(
        await StoreRepository(db).stalePartialOrderDays(StoreIds.sablon),
        7,
      );

      final stale = await orders.staleOrders(StoreIds.sablon, now: seedInstant);
      expect(
        stale.map((o) => o.id),
        contains(OrderIds.partialBoucherie),
        reason: 'sent nine days ago and still partial',
      );

      // Raising it past the age of the commande clears the flag. It is a column
      // on the establishment now, not a mutable global — two restaurants can
      // reasonably disagree about how long is too long.
      await setThreshold(60);
      expect(
        await orders.staleOrders(StoreIds.sablon, now: seedInstant),
        isEmpty,
      );
    });

    test('only partial commandes are ever stale', () async {
      await setThreshold(1);

      for (final order in await orders.staleOrders(
        StoreIds.sablon,
        now: seedInstant,
      )) {
        expect(order.status, PurchaseOrderStatus.partial);
      }
    });
  });

  group('the seeded dataset supports the walkthrough', () {
    test('covers every status', () async {
      final statuses = (await orders.orders(
        StoreIds.sablon,
      )).map((o) => o.status).toSet();

      expect(statuses, containsAll(PurchaseOrderStatus.values));
    });

    test('covers every receipt outcome', () async {
      final outcomes = <ReceiptLineOutcome>{};
      var closedShort = 0;
      var priceChanges = 0;

      for (final order in await orders.orders(StoreIds.sablon)) {
        for (final receipt in await orders.receiptsForOrder(order.id)) {
          for (final line in receipt.lines) {
            outcomes.add(
              outcomeOf(
                ordered: line.quantityOrdered,
                received: line.quantityReceived,
                wasUnordered: line.wasUnordered,
              ),
            );
            if (line.closedShort) closedShort++;

            final ordered = order.lines
                .where((l) => l.itemId == line.itemId)
                .firstOrNull;
            if (ordered != null &&
                (ordered.unitPrice - line.actualUnitPrice).abs() > 0.001) {
              priceChanges++;
            }
          }
        }
      }

      expect(outcomes, containsAll(ReceiptLineOutcome.values));
      expect(closedShort, greaterThan(0));
      expect(priceChanges, greaterThan(0));
    });

    test('every seeded commande line refers to an article its supplier supplies',
        () async {
      for (final order in await orders.orders(StoreIds.sablon)) {
        for (final line in order.lines) {
          expect(
            await suppliers.priceFor(line.itemId, order.supplierId),
            isNotNull,
            reason: '${order.reference} orders ${line.itemId} from a supplier '
                'with no price on file — the line builder could not have '
                'produced it',
          );
        }
      }
    });

    test('receipt-generated movements point at a real receipt and commande',
        () async {
      final generated = (await movements.movementsForStore(
        StoreIds.sablon,
      )).where((m) => m.receiptId != null);
      expect(generated, isNotEmpty);

      for (final movement in generated) {
        expect(await orders.receipt(movement.receiptId!), isNotNull);
        expect(await orders.order(movement.orderId!), isNotNull);
        expect(movement.type, StockMovementType.stockIn);
      }
    });

    test('the manual stock-in path still exists alongside it', () async {
      final manual = (await movements.movementsForStore(StoreIds.sablon)).where(
        (m) => m.type == StockMovementType.stockIn && m.receiptId == null,
      );

      expect(
        manual,
        isNotEmpty,
        reason: 'somebody buying 5 kg of tomatoes at the market with no '
            'commande behind it must still be recordable',
      );
    });
  });
}
