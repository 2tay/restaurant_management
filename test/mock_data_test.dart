// Referential integrity checks over the mock dataset.
//
// The data is hand-written across a dozen files and relates items to
// categories, units, suppliers and prices by string id. A typo in any of those
// produces a dash, a blank row, or a crash on some screen nobody opened during
// the demo. These tests find it now instead.
//
// Dates are anchored to DateTime.now() via mock_reference.dart, so nothing here
// asserts on them.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/core/utils/stock_status.dart';
import 'package:stock_inventory/mock_data/mock_data.dart';
import 'package:stock_inventory/models/models.dart';

void main() {
  group('referential integrity', () {
    test('every item points at a real store, category and unit', () {
      final storeIds = mockStores.map((s) => s.id).toSet();
      final categoryIds = mockCategories.map((c) => c.id).toSet();
      final unitIds = mockUnits.map((u) => u.id).toSet();

      for (final item in mockItems) {
        expect(storeIds, contains(item.storeId), reason: '${item.name} store');
        expect(
          categoryIds,
          contains(item.categoryId),
          reason: '${item.name} category',
        );
        expect(unitIds, contains(item.unitId), reason: '${item.name} unit');
      }
    });

    test('item categories and units belong to the same store as the item', () {
      for (final item in mockItems) {
        expect(
          MockQueries.categoryById(item.categoryId)!.storeId,
          item.storeId,
          reason: '${item.name} uses another store\'s category',
        );
        expect(
          MockQueries.unitById(item.unitId)!.storeId,
          item.storeId,
          reason: '${item.name} uses another store\'s unit',
        );
      }
    });

    test('every supplier price points at a real item and supplier', () {
      final itemIds = mockItems.map((i) => i.id).toSet();
      final supplierIds = mockSuppliers.map((s) => s.id).toSet();

      for (final price in mockSupplierPrices) {
        expect(itemIds, contains(price.itemId), reason: price.id);
        expect(supplierIds, contains(price.supplierId), reason: price.id);
      }
    });

    test(
      'every price history entry matches an existing item-supplier link',
      () {
        for (final entry in mockPriceHistory) {
          expect(
            MockQueries.priceFor(entry.itemId, entry.supplierId),
            isNotNull,
            reason: '${entry.id} has history but no current price',
          );
        }
      },
    );

    test(
      'every movement points at a real item, and deliveries at a supplier',
      () {
        final itemIds = mockItems.map((i) => i.id).toSet();
        final supplierIds = mockSuppliers.map((s) => s.id).toSet();

        for (final movement in mockStockMovements) {
          expect(itemIds, contains(movement.itemId), reason: movement.id);

          if (movement.type == StockMovementType.stockIn) {
            expect(
              supplierIds,
              contains(movement.supplierId),
              reason: '${movement.id} is a delivery with no valid supplier',
            );
          }
        }
      },
    );

    test('notifications point at real stores', () {
      final storeIds = mockStores.map((s) => s.id).toSet();

      for (final notification in mockNotifications) {
        expect(storeIds, contains(notification.storeId));
      }
    });

    test('every employee points at a real store', () {
      final storeIds = mockStores.map((s) => s.id).toSet();
      for (final employee in mockEmployees) {
        expect(
          storeIds,
          contains(employee.storeId),
          reason: '${employee.firstName} ${employee.lastName}',
        );
      }
    });

    test('CIN and email are unique across the whole roster', () {
      final cins = mockEmployees.map((e) => e.cin.toLowerCase()).toList();
      final emails = mockEmployees.map((e) => e.email.toLowerCase()).toList();
      expect(cins.toSet().length, cins.length, reason: 'duplicate CIN');
      expect(emails.toSet().length, emails.length, reason: 'duplicate email');
    });

    test('mockCurrentEmployee is an owner on the roster', () {
      expect(mockCurrentEmployee.role, EmployeeRole.owner);
      expect(
        mockEmployees.any((e) => e.id == mockCurrentEmployee.id),
        isTrue,
      );
    });

    test('every store has exactly one settings row with sane values', () {
      for (final store in mockStores) {
        final rows = mockStoreSettings.where((s) => s.storeId == store.id);
        expect(rows, hasLength(1), reason: store.name);
        final s = rows.first;
        expect(s.openMinutes, inInclusiveRange(0, 24 * 60 - 1));
        expect(s.closeMinutes, greaterThan(s.openMinutes));
        expect(s.maxBreakMinutes, greaterThan(0));
        expect(s.overtimeMultiplier, greaterThanOrEqualTo(1));
        expect(s.workingDaysPerMonth, greaterThan(0));
        expect(s.stalePartialOrderDays, greaterThan(0));
      }
    });

    test('every payroll period points at a real store and employee, and its '
        'covered days are all paid', () {
      final storeIds = mockStores.map((s) => s.id).toSet();
      final employeeIds = mockEmployees.map((e) => e.id).toSet();
      for (final period in mockPayrollPeriods) {
        expect(storeIds, contains(period.storeId), reason: period.id);
        expect(employeeIds, contains(period.employeeId), reason: period.id);

        final covered = mockAttendances.where(
          (a) => a.payrollPeriodId == period.id,
        );
        expect(covered, isNotEmpty, reason: '${period.id} covers no day');
        expect(
          covered.every((a) => a.paymentStatus == PaymentStatus.paid),
          isTrue,
          reason: '${period.id} has an unpaid covered day',
        );
      }
    });

    test('every attendance points at a real employee and store', () {
      final storeIds = mockStores.map((s) => s.id).toSet();
      final employeeIds = mockEmployees.map((e) => e.id).toSet();
      for (final entry in mockAttendances) {
        expect(storeIds, contains(entry.storeId), reason: entry.id);
        expect(employeeIds, contains(entry.employeeId), reason: entry.id);
      }
    });

    test('a paid attendance day carries its payroll period id', () {
      for (final entry in mockAttendances) {
        if (entry.paymentStatus == PaymentStatus.paid) {
          expect(entry.payrollPeriodId, isNotNull, reason: entry.id);
        }
      }
    });

    test('every login credential points at a real employee', () {
      final employeeIds = mockEmployees.map((e) => e.id).toSet();
      final seen = <String>{};
      for (final credential in mockCredentials) {
        expect(
          employeeIds,
          contains(credential.employeeId),
          reason: credential.id,
        );
        expect(
          seen.add(credential.employeeId),
          isTrue,
          reason: 'two credentials for ${credential.employeeId}',
        );
      }
    });

    test('every owner and manager can sign in', () {
      for (final employee in mockEmployees) {
        if (employee.role == EmployeeRole.staff) continue;
        expect(
          MockQueries.credentialForEmployee(employee.id),
          isNotNull,
          reason: '${employee.firstName} ${employee.lastName} has no PIN',
        );
      }
    });

    test('at most one attendance row per employee per day', () {
      final seen = <String>{};
      for (final entry in mockAttendances) {
        final key = '${entry.employeeId}@${entry.date.toIso8601String()}';
        expect(seen.add(key), isTrue, reason: 'duplicate: $key');
      }
    });

    test('every item is priced by at least one supplier', () {
      for (final item in mockItems) {
        expect(
          MockQueries.pricesForItem(item.id),
          isNotEmpty,
          reason: '${item.name} has no supplier price, so it cannot be valued',
        );
      }
    });

    test('an item has at most one default supplier', () {
      for (final item in mockItems) {
        final defaults = MockQueries.pricesForItem(
          item.id,
        ).where((p) => p.isDefault).length;
        expect(defaults, lessThanOrEqualTo(1), reason: item.name);
      }
    });
  });

  group('movement field usage matches its type', () {
    test('deliveries carry a price, usage carries a reason', () {
      for (final movement in mockStockMovements) {
        switch (movement.type) {
          case StockMovementType.stockIn:
            expect(movement.unitPrice, isNotNull, reason: movement.id);
            expect(movement.quantity, greaterThan(0), reason: movement.id);
          case StockMovementType.stockOut:
            expect(movement.reason, isNotNull, reason: movement.id);
            expect(movement.quantity, lessThan(0), reason: movement.id);
          case StockMovementType.adjustment:
            expect(movement.systemQuantity, isNotNull, reason: movement.id);
            expect(movement.countedQuantity, isNotNull, reason: movement.id);
        }
      }
    });
  });

  group('the dataset demos what it needs to', () {
    test('all three stock statuses appear in the flagship store', () {
      final statuses = MockQueries.itemsForStore(
        StoreIds.sablon,
      ).map(stockStatusOf).toSet();

      expect(statuses, containsAll(StockStatus.values));
    });

    test('the new store is empty, so empty states can be demoed', () {
      expect(MockQueries.itemsForStore(StoreIds.saintGilles), isEmpty);
      expect(MockQueries.employeesForStore(StoreIds.saintGilles), isEmpty);
    });

    test('the roster covers every role, both contracts, and an archived '
        'record', () {
      final sablon = MockQueries.employeesForStore(StoreIds.sablon);

      expect(
        sablon.map((e) => e.role).toSet(),
        containsAll(EmployeeRole.values),
      );
      expect(
        sablon.map((e) => e.contractType).toSet(),
        containsAll(ContractType.values),
      );
      expect(sablon.where((e) => e.archivedAt != null), isNotEmpty);
      expect(
        sablon.where((e) => e.scheduledStartMinutes != null),
        isNotEmpty,
        reason: 'needs a custom-schedule employee to demo lateness',
      );
    });

    test('the attendance seed covers pauses and every in-progress status', () {
      final sablon = mockAttendances
          .where((a) => a.storeId == StoreIds.sablon)
          .toList();

      expect(
        sablon.where((a) => a.pauses.length >= 2),
        isNotEmpty,
        reason: 'several pauses in one day',
      );
      expect(
        sablon.where((a) => a.pauses.any((p) => p.endAt == null)),
        isNotEmpty,
        reason: 'a break still running (today)',
      );
      expect(
        sablon.map((a) => a.status).toSet(),
        containsAll([
          AttendanceStatus.working,
          AttendanceStatus.onBreak,
          AttendanceStatus.done,
        ]),
      );
    });

    test('at least one item has three competing suppliers', () {
      final multiSupplier = mockItems.where(
        (item) => MockQueries.pricesForItem(item.id).length >= 3,
      );

      expect(multiSupplier, isNotEmpty);
    });

    test('at least one item is on a default supplier that is not cheapest', () {
      // Without this the price comparison report opens on nothing to say, and
      // it is the feature the app is sold on.
      final overpaying = mockItems.where(
        (item) => MockQueries.overpayPerUnit(item.id) > 0,
      );

      expect(overpaying, isNotEmpty);
    });

    test('stores hold different inventories, proving scoping is visible', () {
      final sablon = MockQueries.itemsForStore(StoreIds.sablon);
      final liege = MockQueries.itemsForStore(StoreIds.liege);

      expect(sablon, isNotEmpty);
      expect(liege, isNotEmpty);
      expect(sablon.length, isNot(liege.length));
    });
  });
}
