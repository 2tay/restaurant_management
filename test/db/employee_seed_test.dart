// Referential integrity and demo coverage for the Gestion Employée dataset,
// against a seeded database.
//
// The database-side counterpart to the employee assertions in
// `mock_data_test.dart`. The dataset is still hand-written across
// `mock_employees.dart`, `mock_credentials.dart`, `mock_attendances.dart` and
// `mock_payroll_periods.dart` and still relates everything by string id, so a
// typo still produces a dash or a blank card on a screen nobody opened during
// the demo. The schema (see `schema_test.dart`) turns the hard invariants —
// unique CIN, one row per employee per day, the credential FK — into
// constraints; this suite checks the rest, and that the seed actually inserted
// what the demo path relies on.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/mappers/mappers.dart';
import 'package:stock_inventory/mock_data/mock_data.dart';
import 'package:stock_inventory/models/models.dart';

import '../support/db_fixture.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await openSeededDatabase();
  });

  Future<List<Employee>> employees() async =>
      (await db.select(db.employees).get()).map(employeeFromRow).toList();

  Future<List<Attendance>> attendances() async {
    final rows = await db.select(db.attendances).get();
    final pauses = await db.select(db.attendancePauses).get();
    return rows
        .map(
          (row) => attendanceFromRows(
            row,
            pauses.where((p) => p.attendanceId == row.id).toList(),
          ),
        )
        .toList();
  }

  Future<List<Employee>> employeesForStore(String storeId) async =>
      (await employees()).where((e) => e.storeId == storeId).toList();

  group('referential integrity', () {
    test('every employee points at a real establishment', () async {
      final storeIds = (await db.select(db.stores).get()).map((s) => s.id).toSet();
      for (final employee in await employees()) {
        expect(
          storeIds,
          contains(employee.storeId),
          reason: '${employee.firstName} ${employee.lastName}',
        );
      }
    });

    test('CIN and email are unique across the whole roster', () async {
      final roster = await employees();
      final cins = roster.map((e) => e.cin.toLowerCase()).toList();
      final emails = roster.map((e) => e.email.toLowerCase()).toList();
      expect(cins.toSet(), hasLength(cins.length), reason: 'duplicate CIN');
      expect(emails.toSet(), hasLength(emails.length), reason: 'duplicate email');
    });

    test('every credential points at a real employee, one per employee',
        () async {
      final employeeIds = (await employees()).map((e) => e.id).toSet();
      final credentials = (await db.select(db.employeeCredentials).get())
          .map(credentialFromRow)
          .toList();

      final seen = <String>{};
      for (final credential in credentials) {
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

    test('every owner and manager can sign in', () async {
      final withCredential = (await db.select(db.employeeCredentials).get())
          .map((c) => c.employeeId)
          .toSet();

      for (final employee in await employees()) {
        if (employee.role == EmployeeRole.staff) continue;
        expect(
          withCredential,
          contains(employee.id),
          reason: '${employee.firstName} ${employee.lastName} has no PIN',
        );
      }
    });

    test('every attendance points at a real employee and store', () async {
      final storeIds = (await db.select(db.stores).get()).map((s) => s.id).toSet();
      final employeeIds = (await employees()).map((e) => e.id).toSet();
      for (final entry in await attendances()) {
        expect(employeeIds, contains(entry.employeeId), reason: entry.id);
        expect(storeIds, contains(entry.storeId), reason: entry.id);
      }
    });

    test('at most one attendance row per employee per day', () async {
      final seen = <String>{};
      for (final entry in await attendances()) {
        final key = '${entry.employeeId}@${entry.date.toIso8601String()}';
        expect(seen.add(key), isTrue, reason: 'duplicate: $key');
      }
    });

    test('a paid day names a payroll period that exists, and vice versa',
        () async {
      final periodIds =
          (await db.select(db.payrollPeriods).get()).map((p) => p.id).toSet();

      for (final entry in await attendances()) {
        if (entry.paymentStatus == PaymentStatus.paid) {
          expect(entry.payrollPeriodId, isNotNull, reason: entry.id);
          expect(
            periodIds,
            contains(entry.payrollPeriodId),
            reason: '${entry.id} points at a missing period',
          );
        }
      }
    });

    test('every payroll period points at a real store and employee, and all '
        'its covered days are paid', () async {
      final storeIds = (await db.select(db.stores).get()).map((s) => s.id).toSet();
      final employeeIds = (await employees()).map((e) => e.id).toSet();
      final days = await attendances();

      for (final period in await db.select(db.payrollPeriods).get()) {
        expect(storeIds, contains(period.storeId), reason: period.id);
        expect(employeeIds, contains(period.employeeId), reason: period.id);

        final covered =
            days.where((a) => a.payrollPeriodId == period.id).toList();
        expect(covered, isNotEmpty, reason: '${period.id} covers no day');
        expect(
          covered.every((a) => a.paymentStatus == PaymentStatus.paid),
          isTrue,
          reason: '${period.id} has an unpaid covered day',
        );
      }
    });
  });

  group('the dataset demos what it needs to', () {
    test('the new establishment seeds no staff, so its empty state is real',
        () async {
      expect(await employeesForStore(StoreIds.saintGilles), isEmpty);
    });

    test('the flagship roster covers every role, both contracts, an archived '
        'record and a custom schedule', () async {
      final sablon = await employeesForStore(StoreIds.sablon);

      expect(sablon.map((e) => e.role).toSet(), containsAll(EmployeeRole.values));
      expect(
        sablon.map((e) => e.contractType).toSet(),
        containsAll(ContractType.values),
      );
      expect(
        sablon.where((e) => e.archivedAt != null),
        isNotEmpty,
        reason: 'needs a retired record to demo the "retiré" state',
      );
      expect(
        sablon.where((e) => e.scheduledStartMinutes != null),
        isNotEmpty,
        reason: 'needs a custom-schedule employee to demo lateness',
      );
    });

    test('the attendance seed covers pauses and every in-progress status',
        () async {
      final sablon = (await attendances())
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

    test('the pauses of a day come back oldest first', () async {
      // Fatima today: one ended pause then one running.
      final fatimaToday = (await attendances()).firstWhere(
        (a) => a.pauses.length >= 2 && a.pauses.any((p) => p.endAt == null),
      );
      final starts = fatimaToday.pauses.map((p) => p.startAt).toList();
      expect(starts, orderedEquals([...starts]..sort()));
      expect(fatimaToday.pauses.last.endAt, isNull);
    });

    test('TestCalcul has its two people and a July history, part paid', () async {
      final people = await employeesForStore(StoreIds.testCalcul);
      expect(people.map((e) => e.id).toSet(), {
        EmployeeIds.ayoub,
        EmployeeIds.hakim,
      });

      final history = (await attendances())
          .where((a) => a.storeId == StoreIds.testCalcul)
          .toList();
      for (final id in [EmployeeIds.ayoub, EmployeeIds.hakim]) {
        final own = history.where((a) => a.employeeId == id).toList();
        expect(own, isNotEmpty, reason: '$id has no attendance');
        expect(
          own.any((a) => a.paymentStatus == PaymentStatus.paid),
          isTrue,
          reason: '$id should have paid days',
        );
        expect(
          own.any((a) => a.paymentStatus == PaymentStatus.unpaid),
          isTrue,
          reason: '$id should have days still to pay',
        );
      }
    });

    test('per-store pointage settings survive a seed', () async {
      Future<StoreRow> row(String id) => (db.select(
            db.stores,
          )..where((s) => s.id.equals(id))).getSingle();

      final sablon = await row(StoreIds.sablon);
      expect(sablon.maxBreakMinutes, 45);
      expect(sablon.overtimeMultiplier, 1.5);

      final testCalcul = await row(StoreIds.testCalcul);
      expect(testCalcul.openMinutes, 8 * 60);
      expect(testCalcul.closeMinutes, 22 * 60);
      expect(testCalcul.maxBreakMinutes, 60);

      final liege = await row(StoreIds.liege);
      expect(liege.maxBreakMinutes, 30, reason: 'takes the default');
    });
  });

  group('the seed matches the dataset it was built from', () {
    test('every employee-module list is fully inserted', () async {
      expect(await db.select(db.employees).get(), hasLength(mockEmployees.length));
      expect(
        await db.select(db.employeeCredentials).get(),
        hasLength(mockCredentials.length),
      );
      expect(
        await db.select(db.payrollPeriods).get(),
        hasLength(mockPayrollPeriods.length),
      );
      expect(
        await db.select(db.attendances).get(),
        hasLength(mockAttendances.length),
      );
      expect(
        await db.select(db.attendancePauses).get(),
        hasLength(
          mockAttendances.fold<int>(0, (n, a) => n + a.pauses.length),
        ),
      );
    });
  });
}
