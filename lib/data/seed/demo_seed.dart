import 'package:drift/drift.dart';

import '../../mock_data/mock_data.dart';
import '../database/app_database.dart';
import '../database/meta_keys.dart';
import '../mappers/mappers.dart';

/// Writes the demo dataset into an empty database.
///
/// This is what a first launch runs, and what *Réinitialiser la démonstration*
/// runs again. A fresh install therefore looks exactly like the Phase 1 demo
/// did, which is the point: the dataset was built to make every screen say
/// something true — three stock statuses in the flagship store, an article with
/// three competing suppliers, another whose default supplier is not the
/// cheapest, and one establishment that is genuinely empty so the empty states
/// can be shown rather than described.
///
/// Everything goes in one batch, which drift runs as a single transaction. A
/// half-written demo is not a state worth having recovery code for.
///
/// The source is still `lib/mock_data/`. That import is the only thing keeping
/// the mock layer alive from here on, and stage 10 moves the dataset under this
/// folder — at which point it stops being an app layer and becomes what it
/// always was, a fixture.
///
/// [at] is the instant the dataset should read as having been written. Every
/// date in `mock_data/` is an offset from `mockNow`, frozen when that library
/// loaded, so shifting by the difference re-anchors the whole timeline: the
/// order sent three days ago is still three days ago, relative to [at]. It
/// defaults to now, which is what the app wants; tests pass a fixed instant and
/// get a dataset they can assert dates against — something the list version was
/// never able to offer.
Future<void> seedDemoData(AppDatabase db, {DateTime? at}) async {
  final DateTime seededAt = at ?? DateTime.now();
  final Duration shift = seededAt.difference(mockNow);

  DateTime moved(DateTime original) => original.add(shift);
  Value<DateTime?> movedValue(DateTime? original) =>
      Value(original == null ? null : moved(original));

  await db.batch((Batch batch) {
    // Insertion order is foreign-key order. With `PRAGMA foreign_keys = ON` the
    // constraints are immediate, not deferred, so a category inserted after the
    // items that use it is a failure and not a detail.
    batch.insertAll(db.stores, [
      for (final store in mockStores)
        storeToRow(store).copyWith(createdAt: Value(moved(store.createdAt))),
    ]);
    batch.insertAll(db.categories, mockCategories.map(categoryToRow));
    batch.insertAll(db.units, mockUnits.map(unitToRow));
    batch.insertAll(db.suppliers, mockSuppliers.map(supplierToRow));

    batch.insertAll(db.items, [
      for (final item in mockItems)
        itemToRow(item).copyWith(updatedAt: Value(moved(item.updatedAt))),
    ]);
    batch.insertAll(db.supplierPrices, [
      for (final price in mockSupplierPrices)
        supplierPriceToRow(
          price,
        ).copyWith(effectiveDate: Value(moved(price.effectiveDate))),
    ]);
    batch.insertAll(db.priceHistory, [
      for (final entry in mockPriceHistory)
        priceHistoryToRow(
          entry,
        ).copyWith(changedAt: Value(moved(entry.changedAt))),
    ]);
    batch.insertAll(db.stockMovements, [
      for (final movement in mockStockMovements)
        movementToRow(
          movement,
        ).copyWith(occurredAt: Value(moved(movement.occurredAt))),
    ]);

    batch.insertAll(db.purchaseOrders, [
      for (final order in mockPurchaseOrders)
        orderToRow(order).copyWith(
          createdAt: Value(moved(order.createdAt)),
          sentAt: movedValue(order.sentAt),
          closedAt: movedValue(order.closedAt),
        ),
    ]);
    batch.insertAll(db.purchaseOrderLines, [
      for (final order in mockPurchaseOrders)
        for (final line in order.lines) orderLineToRow(line, orderId: order.id),
    ]);

    batch.insertAll(db.goodsReceipts, [
      for (final receipt in mockGoodsReceipts)
        receiptToRow(
          receipt,
        ).copyWith(receivedAt: Value(moved(receipt.receivedAt))),
    ]);
    batch.insertAll(db.goodsReceiptLines, [
      for (final receipt in mockGoodsReceipts)
        for (final line in receipt.lines)
          receiptLineToRow(line, receiptId: receipt.id),
    ]);

    batch.insertAll(db.teamMembers, [
      for (final member in mockTeam)
        teamMemberToRow(member).copyWith(
          invitedAt: Value(moved(member.invitedAt)),
          lastActiveAt: movedValue(member.lastActiveAt),
        ),
    ]);
    batch.insertAll(db.teamMemberStores, [
      for (final member in mockTeam)
        for (final storeId in member.storeIds)
          teamMemberStoreToRow(memberId: member.id, storeId: storeId),
    ]);

    batch.insertAll(db.notifications, [
      for (final notification in mockNotifications)
        notificationToRow(
          notification,
        ).copyWith(createdAt: Value(moved(notification.createdAt))),
    ]);

    batch.insert(
      db.meta,
      MetaCompanion.insert(
        key: MetaKeys.seededAt,
        value: seededAt.toIso8601String(),
      ),
    );
  });
}

/// Empties every table, in reverse foreign-key order.
///
/// Used by *Réinitialiser la démonstration* before re-seeding. Reverse order
/// rather than `PRAGMA foreign_keys = OFF`: switching the constraints off to do
/// a delete is a habit that eventually gets used somewhere it hides a real bug,
/// and this is fifteen lines.
Future<void> clearAllData(AppDatabase db) async {
  await db.batch((Batch batch) {
    batch.deleteAll(db.meta);
    batch.deleteAll(db.notifications);
    batch.deleteAll(db.teamMemberStores);
    batch.deleteAll(db.teamMembers);
    batch.deleteAll(db.goodsReceiptLines);
    batch.deleteAll(db.goodsReceipts);
    batch.deleteAll(db.purchaseOrderLines);
    batch.deleteAll(db.purchaseOrders);
    batch.deleteAll(db.stockMovements);
    batch.deleteAll(db.priceHistory);
    batch.deleteAll(db.supplierPrices);
    batch.deleteAll(db.items);
    batch.deleteAll(db.suppliers);
    batch.deleteAll(db.units);
    batch.deleteAll(db.categories);
    batch.deleteAll(db.stores);
  });
}
