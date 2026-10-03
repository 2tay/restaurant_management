// A day sync merged from two tablets (SYNC_PERSONNEL_PLAN.md, step 6):
// two open arrivals, a break left open by the other tablet. One exit ends
// everything (P1), the status comes from the times (P3), and a manager can
// remove the arrival in excess.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/core/utils/attendance_status.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart'
    show EmployeeIds, PayrollPeriodIds, StoreIds;
import 'package:stock_inventory/models/models.dart';

import '../support/db_fixture.dart';

const _fresh = EmployeeIds.noah;

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await openSeededDatabase();
  });

  AttendanceRepository repo() =>
      AttendanceRepository(db, clock: () => seedInstant);


  group('a day merged from two tablets', () {
    /// Noah clocked in here, and — as sync would merge it — a second open
    /// arrival from another tablet, ten minutes earlier.
    Future<Attendance> twoArrivals({bool pauseOnOther = false}) async {
      final day = (await repo().clockIn(
        _fresh,
        StoreIds.sablon,
        now: seedInstant.subtract(const Duration(hours: 2)),
      ))!;
      await db.into(db.attendanceSessions).insert(
        AttendanceSessionsCompanion.insert(
          id: 'other-tablet',
          storeId: StoreIds.sablon,
          attendanceId: day.id,
          position: 1000,
          clockInAt: seedInstant.subtract(
            const Duration(hours: 2, minutes: 10),
          ),
        ),
      );
      if (pauseOnOther) {
        await db.into(db.attendancePauses).insert(
          AttendancePausesCompanion.insert(
            id: 'other-pause',
            storeId: StoreIds.sablon,
            sessionId: 'other-tablet',
            position: 0,
            startAt: seedInstant.subtract(const Duration(hours: 1)),
          ),
        );
      }
      await repo().refreshStatus(day.id);
      return (await repo().attendance(day.id))!;
    }

    test('one Fin de journée ends both arrivals (P1)', () async {
      final day = await twoArrivals();

      final done = (await repo().clockOut(day.id))!;

      expect(done.status, AttendanceStatus.done);
      expect(done.sessions, hasLength(2));
      expect(done.sessions.every((s) => s.clockOutAt == seedInstant), isTrue);
    });

    test('closing the journée ends both, signed by the manager (P1)',
        () async {
      final day = await twoArrivals();

      final done = (await repo().endShift(
        day.id,
        seedInstant,
        setByEmployeeId: EmployeeIds.amelie,
      ))!;

      expect(done.sessions.map((s) => s.exitSetByEmployeeId).toSet(), {
        EmployeeIds.amelie,
      });
    });

    test('an exit before either arrival is refused', () async {
      final day = await twoArrivals();

      final refused = await repo().endShift(
        day.id,
        seedInstant.subtract(const Duration(hours: 2, minutes: 5)),
        setByEmployeeId: EmployeeIds.amelie,
      );

      expect(refused, isNull);
    });

    test('the status comes from the times, not from the row (P3)', () async {
      final day = await twoArrivals(pauseOnOther: true);
      expect(day.status, AttendanceStatus.onBreak);

      await (db.update(db.attendancePauses)
            ..where((p) => p.id.equals('other-pause')))
          .write(AttendancePausesCompanion(endAt: Value(seedInstant)));
      await repo().refreshStatus(day.id);

      expect(
        (await repo().attendance(day.id))!.status,
        AttendanceStatus.working,
      );
    });

    test('a break never ended stops at the exit (P3)', () async {
      final day = await twoArrivals(pauseOnOther: true);
      // The other tablet's exit reaches this one, its break still open.
      await (db.update(db.attendanceSessions)
            ..where((s) => s.id.equals('other-tablet')))
          .write(AttendanceSessionsCompanion(clockOutAt: Value(seedInstant)));
      final entry = (await repo().attendance(day.id))!;
      final other = entry.sessions.singleWhere((s) => s.id == 'other-tablet');

      expect(pausesOf(other).single.endAt, seedInstant);
      // 2h10 on the clock, the last hour on a break.
      expect(
        workedDuration(
          Attendance(
            id: entry.id,
            storeId: entry.storeId,
            employeeId: entry.employeeId,
            date: entry.date,
            status: AttendanceStatus.done,
            sessions: [other],
            paymentStatus: PaymentStatus.unpaid,
          ),
        ),
        const Duration(hours: 1, minutes: 10),
      );
    });

    test('« Supprimer ce pointage en double » removes one arrival', () async {
      final day = await twoArrivals(pauseOnOther: true);

      final kept = (await repo().deleteDuplicateSession(
        day.id,
        'other-tablet',
      ))!;

      expect(kept.sessions, hasLength(1));
      expect(kept.status, AttendanceStatus.working);
      final pause = await (db.select(
        db.attendancePauses,
      )..where((p) => p.id.equals('other-pause'))).getSingle();
      expect(pause.deletedAt, isNotNull);
    });

    test('the last arrival of a day cannot be removed', () async {
      final day = await twoArrivals();
      final first = day.sessions.firstWhere((s) => s.id != 'other-tablet');

      await repo().deleteDuplicateSession(day.id, 'other-tablet');

      expect(await repo().deleteDuplicateSession(day.id, first.id!), isNull);
    });

    test('a paid day is never touched', () async {
      final day = await twoArrivals();
      await repo().clockOut(day.id);
      await (db.update(db.attendances)..where((a) => a.id.equals(day.id)))
          .write(
            const AttendancesCompanion(
              payrollPeriodId: Value(PayrollPeriodIds.karimSeed),
            ),
          );

      expect(
        await repo().deleteDuplicateSession(day.id, 'other-tablet'),
        isNull,
      );
    });
  });
}
