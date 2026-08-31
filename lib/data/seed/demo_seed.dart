import 'package:drift/drift.dart';

import '../../core/utils/employee_status.dart';
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
/// The source is still `lib/mock_data/` — both for the stock dataset written
/// here and for the employee module, which has not been ported to the database
/// at all. Stage 10 moves the stock fixture under this folder.
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

  // The employee module is **date-anchored**, not instant-anchored: a pointage
  // row belongs to a work day, "Karim clocked in at 07:45" has to stay 07:45 on
  // the re-anchored day, and `attendanceForToday` compares against `dayOnly` of
  // a wall clock. So its timestamps shift by a **whole number of days** — the
  // gap between the two midnights — which moves every date onto the seed
  // instant's calendar while leaving every time of day exactly where it was.
  DateTime midnight(DateTime d) => DateTime(d.year, d.month, d.day);
  final Duration dayShift = midnight(seededAt).difference(midnight(mockNow));
  DateTime movedByDays(DateTime original) => original.add(dayShift);
  Value<DateTime?> movedByDaysValue(DateTime? original) =>
      Value(original == null ? null : movedByDays(original));
  DateTime movedDay(DateTime original) => midnight(movedByDays(original));

  await db.batch((Batch batch) {
    // Insertion order is foreign-key order. With `PRAGMA foreign_keys = ON` the
    // constraints are immediate, not deferred, so a category inserted after the
    // items that use it is a failure and not a detail.
    batch.insertAll(db.stores, [
      for (final store in mockStores)
        storeToRow(
          store,
          storeSettingsOrDefault(store.id),
        ).copyWith(createdAt: Value(moved(store.createdAt))),
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
        for (final (int index, line) in order.lines.indexed)
          orderLineToRow(line, orderId: order.id, position: index),
    ]);

    batch.insertAll(db.goodsReceipts, [
      for (final receipt in mockGoodsReceipts)
        receiptToRow(
          receipt,
        ).copyWith(receivedAt: Value(moved(receipt.receivedAt))),
    ]);
    batch.insertAll(db.goodsReceiptLines, [
      for (final receipt in mockGoodsReceipts)
        for (final (int index, line) in receipt.lines.indexed)
          receiptLineToRow(line, receiptId: receipt.id, position: index),
    ]);

    // --- Gestion Employée (Phase 2 employé) --------------------------------
    //
    // Foreign-key order: an employee before its credential and its attendance,
    // a payroll period before the attendance rows it locks (`payrollPeriodId`
    // is `RESTRICT`), a pause after its day.
    batch.insertAll(db.employees, [
      for (final employee in mockEmployees)
        employeeToRow(employee).copyWith(
          hireDate: Value(movedByDays(employee.hireDate)),
          createdAt: Value(movedByDays(employee.createdAt)),
          archivedAt: movedByDaysValue(employee.archivedAt),
        ),
    ]);
    batch.insertAll(db.employeeCredentials, mockCredentials.map(credentialToRow));
    batch.insertAll(db.payrollPeriods, [
      for (final period in mockPayrollPeriods)
        payrollPeriodToRow(period).copyWith(
          startDate: Value(movedDay(period.startDate)),
          endDate: Value(movedDay(period.endDate)),
          paidAt: movedByDaysValue(period.paidAt),
          createdAt: Value(movedByDays(period.createdAt)),
        ),
    ]);
    batch.insertAll(db.attendances, [
      for (final attendance in mockAttendances)
        attendanceToRow(attendance).copyWith(
          date: Value(movedDay(attendance.clockInAt ?? attendance.date)),
          clockInAt: movedByDaysValue(attendance.clockInAt),
          clockOutAt: movedByDaysValue(attendance.clockOutAt),
        ),
    ]);
    batch.insertAll(db.attendancePauses, [
      for (final attendance in mockAttendances)
        for (final (int index, pause) in attendance.pauses.indexed)
          pauseToRow(
            pause,
            attendanceId: attendance.id,
            position: index,
          ).copyWith(
            startAt: Value(movedByDays(pause.startAt)),
            endAt: movedByDaysValue(pause.endAt),
          ),
    ]);

    batch.insertAll(db.notifications, [
      for (final notification in mockNotifications)
        notificationToRow(
          notification,
        ).copyWith(createdAt: Value(moved(notification.createdAt))),
    ]);

    batch.insertAll(db.meta, [
      MetaCompanion.insert(
        key: MetaKeys.seededAt,
        value: seededAt.toIso8601String(),
      ),
      // The name every movement and price change is stamped with. The employee
      // module runs on `lib/mock_data/`, so this is that module's current user
      // frozen into a string — good enough until the two layers meet.
      MetaCompanion.insert(
        key: MetaKeys.currentUserName,
        value: employeeDisplayName(mockCurrentEmployee),
      ),
    ]);
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

    // Gestion Employée, reverse foreign-key order: a pause before its day, the
    // attendance rows before the payroll period they point at, a credential
    // before its employee.
    batch.deleteAll(db.attendancePauses);
    batch.deleteAll(db.attendances);
    batch.deleteAll(db.payrollPeriods);
    batch.deleteAll(db.employeeCredentials);
    batch.deleteAll(db.employees);

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
