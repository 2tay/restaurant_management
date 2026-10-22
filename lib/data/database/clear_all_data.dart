import 'package:drift/drift.dart';

import 'app_database.dart';
import 'meta_keys.dart';

/// Empties every table, in reverse foreign-key order.
///
/// Used by an account sign-out, which wipes the device. Reverse order rather
/// than `PRAGMA foreign_keys = OFF`: switching the constraints off to do a
/// delete is a habit that eventually gets used somewhere it hides a real bug,
/// and this is fifteen lines.
///
/// These are real deletes, not the soft deletes every repository uses: a wiped
/// device is meant to keep nothing. The one row kept is the device's id, which
/// belongs to the installation, not to the restaurant.
Future<void> clearAllData(AppDatabase db) async {
  await db.batch((Batch batch) {
    batch.deleteWhere(db.meta, (m) => m.key.equals(MetaKeys.deviceId).not());
    batch.deleteAll(db.photoUploads);
    batch.deleteAll(db.notifications);
    batch.deleteAll(db.busyDates);

    // Gestion Employée, reverse foreign-key order: a pause before its
    // session, a session before its day, the attendance rows before the
    // payroll period they point at, a
    // journée before the employees who opened and closed it.
    batch.deleteAll(db.businessDays);
    batch.deleteAll(db.attendancePauses);
    batch.deleteAll(db.attendanceSessions);
    batch.deleteAll(db.attendances);
    batch.deleteAll(db.payrollPeriods);
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
