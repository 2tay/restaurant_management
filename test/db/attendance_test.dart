// The pointage state machine, against the database.
//
// Ported from `test/attendance_test.dart`. `AttendanceRepository` is the only
// file that writes an `Attendance` or a pause, and the machine worth pinning is
// the same: one row per employee per day, N breaks, every transition refusing
// the wrong prior state, and a day locked by payroll refusing every write. The
// `workedDuration` / `overtimeBy` / `hasLateBreak` arithmetic groups operate on
// an `Attendance` object built by hand and are unchanged.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/core/utils/attendance_status.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart'
    show AttendanceIds, EmployeeIds, StoreIds;
import 'package:stock_inventory/models/models.dart';

import '../support/db_fixture.dart';

// An employee with no row today in the seed.
const _fresh = EmployeeIds.noah;

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await openSeededDatabase();
  });

  AttendanceRepository repo() =>
      AttendanceRepository(db, clock: () => seedInstant);

  DateTime daysBefore(int n) => seedInstant.subtract(Duration(days: n));

  group('clocking in', () {
    test('creates a working row, and a second call while open is refused',
        () async {
      final first = await repo().clockIn(_fresh, StoreIds.sablon);
      expect(first, isNotNull);
      expect(first!.status, AttendanceStatus.working);
      expect(first.sessions, hasLength(1));
      expect(first.sessions.single.clockInAt, isNotNull);

      final second = await repo().clockIn(_fresh, StoreIds.sablon);
      expect(second, isNull);
      expect((await repo().today(_fresh))!.id, first.id);
    });

    test('two simultaneous first pauses append exactly one break', () async {
      final row = (await repo().clockIn(_fresh, StoreIds.sablon))!;

      // The double-tapped Pause button: genuinely concurrent futures. The
      // count-then-insert is inside the transaction, so one wins and the other
      // sees `onBreak` and refuses. (Swap the `_db.transaction` in `_mutate`
      // for `Future.sync` and both reads see count 0, both insert position 0,
      // and the `(attendanceId, position)` unique index throws — the teeth.)
      await Future.wait([
        repo().startPause(row.id),
        repo().startPause(row.id),
      ]);

      final after = (await repo().attendance(row.id))!;
      expect(after.sessions.single.pauses, hasLength(1));
      expect(after.status, AttendanceStatus.onBreak);
    });
  });

  group('the state machine has no back door', () {
    test('a break before clocking in is refused', () async {
      expect(await repo().startPause('no-such-row'), isNull);
    });

    test('ending a break before starting one is refused', () async {
      final row = (await repo().clockIn(_fresh, StoreIds.sablon))!;
      expect(await repo().endPause(row.id), isNull);
      expect((await repo().attendance(row.id))!.status,
          AttendanceStatus.working);
    });

    test('clocking out while on break is refused', () async {
      final row = (await repo().clockIn(_fresh, StoreIds.sablon))!;
      await repo().startPause(row.id);
      expect(await repo().clockOut(row.id), isNull);
      expect(
          (await repo().attendance(row.id))!.status, AttendanceStatus.onBreak);
    });
  });

  group('several breaks in one day', () {
    test('are all allowed, and totalBreak / workedDuration account for them',
        () async {
      final r = repo();
      final row = (await r.clockIn(
        _fresh,
        StoreIds.sablon,
        now: DateTime(2026, 1, 5, 8),
      ))!;

      await r.startPause(row.id, now: DateTime(2026, 1, 5, 10));
      await r.endPause(row.id, now: DateTime(2026, 1, 5, 10, 20));
      await r.startPause(row.id, now: DateTime(2026, 1, 5, 13));
      await r.endPause(row.id, now: DateTime(2026, 1, 5, 13, 30));
      final done = (await r.clockOut(row.id, now: DateTime(2026, 1, 5, 17)))!;

      expect(done.sessions.single.pauses, hasLength(2));
      expect(totalBreak(done), const Duration(minutes: 50));
      // 9h between in and out, minus 50 minutes of breaks.
      expect(workedDuration(done), const Duration(hours: 8, minutes: 10));
    });
  });

  group('multiple cycles in one day', () {
    test('clockIn after Fin de journée opens a second session', () async {
      final r = repo();
      final first = (await r.clockIn(
        _fresh,
        StoreIds.sablon,
        now: DateTime(2026, 1, 5, 8),
      ))!;
      final afterFirst = (await r.clockOut(
        first.id,
        now: DateTime(2026, 1, 5, 14),
      ))!;
      expect(afterFirst.status, AttendanceStatus.done);
      expect(afterFirst.sessions, hasLength(1));

      final reopened = (await r.clockIn(
        _fresh,
        StoreIds.sablon,
        now: DateTime(2026, 1, 5, 16),
      ))!;
      expect(reopened.id, first.id, reason: 'still the same day, same row');
      expect(reopened.status, AttendanceStatus.working);
      expect(reopened.sessions, hasLength(2));
      expect(reopened.sessions.first.clockOutAt, DateTime(2026, 1, 5, 14));
      expect(reopened.sessions.last.clockOutAt, isNull);

      final done = (await r.clockOut(
        reopened.id,
        now: DateTime(2026, 1, 5, 22),
      ))!;
      expect(done.status, AttendanceStatus.done);
      expect(done.sessions, hasLength(2));
      // 6h the first cycle + 6h the second.
      expect(workedDuration(done), const Duration(hours: 12));
    });

    test('clockIn while a cycle is still open is refused, even mid-break',
        () async {
      final r = repo();
      final row = (await r.clockIn(_fresh, StoreIds.sablon))!;
      expect(await r.clockIn(_fresh, StoreIds.sablon), isNull);

      await r.startPause(row.id);
      expect(await r.clockIn(_fresh, StoreIds.sablon), isNull);
    });

    test('pauses on a later cycle stay scoped to their own session',
        () async {
      final r = repo();
      final first = (await r.clockIn(
        _fresh,
        StoreIds.sablon,
        now: DateTime(2026, 1, 5, 8),
      ))!;
      await r.startPause(first.id, now: DateTime(2026, 1, 5, 10));
      await r.endPause(first.id, now: DateTime(2026, 1, 5, 10, 15));
      await r.clockOut(first.id, now: DateTime(2026, 1, 5, 14));

      await r.clockIn(_fresh, StoreIds.sablon, now: DateTime(2026, 1, 5, 16));
      await r.startPause(first.id, now: DateTime(2026, 1, 5, 18));
      final done = (await r.endPause(
        first.id,
        now: DateTime(2026, 1, 5, 18, 30),
      ))!;

      expect(done.sessions.first.pauses, hasLength(1));
      expect(done.sessions.last.pauses, hasLength(1));
      expect(totalPauseCount(done), 2);
    });
  });

  group('break overrun', () {
    test('flags a single segment that ran past the allowance, not the total',
        () {
      final shortBreaks = _withPauses([
        (const (12, 0), const (12, 20)),
        (const (15, 0), const (15, 20)),
      ]);
      expect(hasLateBreak(shortBreaks, 30), isFalse);

      final longBreak = _withPauses([
        (const (12, 0), const (12, 45)),
      ]);
      expect(hasLateBreak(longBreak, 30), isTrue);
      expect(
        breakOverrun(longBreak.sessions.single.pauses.first, 30),
        const Duration(minutes: 15),
      );
      expect(totalBreakOverrun(longBreak, 30), const Duration(minutes: 15));
    });

    test('a running break is never counted as an overrun', () {
      final open = _withPauses([(const (12, 0), null)]);
      expect(breakOverrun(open.sessions.single.pauses.first, 30), Duration.zero);
      expect(hasLateBreak(open, 30), isFalse);
    });
  });

  group('derived anomalies', () {
    List<AttendanceAnomaly> anomalies(Attendance a, {DateTime? now}) =>
        attendanceAnomalies(
          a,
          maxBreakMinutes: 30,
          now: now,
        );

    test('a clean finished day has none', () {
      final clean = _finished(clockIn: const (8, 0), clockOut: const (17, 0));
      expect(anomalies(clean), isEmpty);
    });

    test('a break past the allowance is pauseDepassee', () {
      final longBreak = _withPauses([(const (12, 0), const (13, 0))]);
      expect(anomalies(longBreak), contains(AttendanceAnomaly.pauseDepassee));
    });

    test('a past day still open is oubliDePointage', () {
      final open = Attendance(
        id: 't',
        storeId: StoreIds.sablon,
        employeeId: _fresh,
        date: DateTime(2026, 1, 5),
        status: AttendanceStatus.working,
        sessions: [AttendanceSession(clockInAt: DateTime(2026, 1, 5, 8))],
        paymentStatus: PaymentStatus.unpaid,
      );
      expect(
        anomalies(open, now: DateTime(2026, 1, 7)),
        contains(AttendanceAnomaly.oubliDePointage),
      );
    });

    test('today\'s still-open day is not oubliDePointage', () {
      final today = Attendance(
        id: 't',
        storeId: StoreIds.sablon,
        employeeId: _fresh,
        date: DateTime(2026, 1, 5),
        status: AttendanceStatus.working,
        sessions: [AttendanceSession(clockInAt: DateTime(2026, 1, 5, 8))],
        paymentStatus: PaymentStatus.unpaid,
      );
      expect(
        anomalies(today, now: DateTime(2026, 1, 5, 14)),
        isNot(contains(AttendanceAnomaly.oubliDePointage)),
      );
    });
  });

  group('the store log (Historique)', () {
    test('a from bound excludes an older day and keeps a recent one', () async {
      final since3 = await repo().page(
        StoreIds.sablon,
        from: daysBefore(3),
        pageSize: 100,
      );
      final ids = since3.rows.map((a) => a.id).toSet();
      expect(ids.contains(AttendanceIds.camille5), isFalse); // 5 days ago
      expect(ids.contains(AttendanceIds.karim1), isTrue); // yesterday
    });

    test('a to bound excludes a more recent day and keeps an older one',
        () async {
      final until3 = await repo().page(
        StoreIds.sablon,
        to: daysBefore(3),
        pageSize: 100,
      );
      final ids = until3.rows.map((a) => a.id).toSet();
      expect(ids.contains(AttendanceIds.karim1), isFalse); // yesterday
      expect(ids.contains(AttendanceIds.camille5), isTrue); // 5 days ago
    });

    test('the status filter alone keeps only matching rows', () async {
      final onBreak = await repo().page(
        StoreIds.sablon,
        status: AttendanceStatus.onBreak,
        pageSize: 100,
      );
      expect(onBreak.rows, isNotEmpty);
      expect(
        onBreak.rows.every((a) => a.status == AttendanceStatus.onBreak),
        isTrue,
      );
    });

    test('the employee filter narrows to a single employee', () async {
      final karim = await repo().page(
        StoreIds.sablon,
        employeeId: EmployeeIds.karim,
        pageSize: 100,
      );
      expect(karim.rows, isNotEmpty);
      expect(karim.rows.every((a) => a.employeeId == EmployeeIds.karim), isTrue);
    });

    test('filters combine with AND and rows sort most-recent-first', () async {
      final result = await repo().page(
        StoreIds.sablon,
        from: daysBefore(30),
        status: AttendanceStatus.done,
        employeeId: EmployeeIds.karim,
        pageSize: 100,
      );
      expect(result.rows, isNotEmpty);
      for (final a in result.rows) {
        expect(a.employeeId, EmployeeIds.karim);
        expect(a.status, AttendanceStatus.done);
      }
      for (var i = 0; i < result.rows.length - 1; i++) {
        expect(result.rows[i].date.isBefore(result.rows[i + 1].date), isFalse);
      }
    });

    test('pagination slices the rows and clamps an out-of-range page', () async {
      final all = await repo().page(StoreIds.sablon, pageSize: 100);
      final total = all.totalCount;
      expect(total, greaterThan(3));

      final firstPage =
          await repo().page(StoreIds.sablon, page: 0, pageSize: 3);
      expect(firstPage.rows, hasLength(3));
      expect(firstPage.pageCount, (total + 2) ~/ 3);

      final lastPage =
          await repo().page(StoreIds.sablon, page: 999, pageSize: 3);
      expect(lastPage.page, firstPage.pageCount - 1);
      expect(lastPage.rows, isNotEmpty);
      expect(
        firstPage.rows
            .map((a) => a.id)
            .toSet()
            .intersection(lastPage.rows.map((a) => a.id).toSet()),
        isEmpty,
      );
    });

    test('an empty result still reports one page', () async {
      final none = await repo().page(StoreIds.saintGilles);
      expect(none.rows, isEmpty);
      expect(none.totalCount, 0);
      expect(none.pageCount, 1);
    });

    test('the KPI stats are computed over the period, per resolved schedule',
        () async {
      final stats = await repo().stats(
        StoreIds.sablon,
        from: daysBefore(2),
      );
      expect(stats.days, greaterThan(0));
      expect(stats.worked, greaterThan(Duration.zero));
      expect(stats.lateBreaks, greaterThanOrEqualTo(0));
    });
  });

  group('the evaluation context is frozen at clock-in', () {
    DateTime todayAt(int hour, [int minute = 0]) => DateTime(
          seedInstant.year,
          seedInstant.month,
          seedInstant.day,
          hour,
          minute,
        );

    test('clockIn stamps the resolved break allowance', () async {
      final day = (await repo().clockIn(_fresh, StoreIds.sablon))!;
      // Noah has no personal override → the store's 45-minute break allowance.
      expect(day.maxBreakMinutes, 45);
    });

    test('a later store break-allowance change does not rewrite a past day',
        () async {
      final day = (await repo().clockIn(_fresh, StoreIds.sablon))!;
      await repo().startPause(day.id, now: todayAt(10));
      await repo().endPause(day.id, now: todayAt(10, 50));
      await repo().clockOut(day.id, now: todayAt(18));

      final before = await repo().stats(
        StoreIds.sablon,
        from: seedInstant,
        to: seedInstant,
        employeeId: _fresh,
      );
      expect(before.lateBreaks, 1);

      await StoreRepository(db).updateStoreSettings(
        StoreIds.sablon,
        maxBreakMinutes: 60,
      );

      final after = await repo().stats(
        StoreIds.sablon,
        from: seedInstant,
        to: seedInstant,
        employeeId: _fresh,
      );
      expect(
        after.lateBreaks,
        1,
        reason: 'measured against the 45-minute allowance frozen on the row, '
            'not the new 60-minute one',
      );
    });

    test('a row with no frozen context falls back to the live allowance',
        () async {
      final day = (await repo().clockIn(_fresh, StoreIds.sablon))!;
      await repo().startPause(day.id, now: todayAt(10));
      await repo().endPause(day.id, now: todayAt(10, 50));
      await repo().clockOut(day.id, now: todayAt(18));

      // A row from before schema v3, before the backfill ran.
      await (db.update(db.attendances)..where((a) => a.id.equals(day.id))).write(
        const AttendancesCompanion(maxBreakMinutes: Value(null)),
      );

      await StoreRepository(db).updateStoreSettings(
        StoreIds.sablon,
        maxBreakMinutes: 60,
      );

      final after = await repo().stats(
        StoreIds.sablon,
        from: seedInstant,
        to: seedInstant,
        employeeId: _fresh,
      );
      expect(
        after.lateBreaks,
        0,
        reason: 'no snapshot → judged against the current 60-minute allowance',
      );
    });
  });

  group('a payroll-locked day', () {
    test('refuses every write', () async {
      final paid = await (db.select(db.attendances)
            ..where((a) => a.payrollPeriodId.isNotNull())
            ..limit(1))
          .getSingle();

      expect(await repo().startPause(paid.id), isNull);
      expect(await repo().endPause(paid.id), isNull);
      expect(await repo().clockOut(paid.id), isNull);
    });
  });

  test('lockForPayroll refuses the whole call if any day is already locked',
      () async {
    final rows = await (db.select(db.attendances)
          ..where((a) => a.storeId.equals(StoreIds.sablon) &
              a.status.equalsValue(AttendanceStatus.done)))
        .get();
    final free = rows.firstWhere((r) => r.payrollPeriodId == null);
    final locked = rows.firstWhere((r) => r.payrollPeriodId != null);

    final ok = await repo().lockForPayroll(
      [free.id, locked.id],
      'payroll-seed-karim',
    );
    expect(ok, isFalse);
    expect(
      (await repo().attendance(free.id))!.paymentStatus,
      PaymentStatus.unpaid,
      reason: 'nothing is touched when the call is refused',
    );
  });

  test('the seed covers every state the walkthrough needs', () async {
    final sablon = await repo().page(StoreIds.sablon, pageSize: 100);
    final rows = sablon.rows;

    expect(rows.where((a) => totalPauseCount(a) >= 2), isNotEmpty);
    expect(
      rows.where(
        (a) => a.sessions.expand((s) => s.pauses).any((p) => p.endAt == null),
      ),
      isNotEmpty,
      reason: 'a break still running today',
    );
    expect(rows.where((a) => a.status == AttendanceStatus.done), isNotEmpty);
    expect(
      rows.where((a) => a.paymentStatus == PaymentStatus.paid),
      isNotEmpty,
    );
  });
}

/// A finished [Attendance] on 2026-01-05 with the given clock times, for the
/// derivation tests. No breaks.
Attendance _finished({
  required (int, int) clockIn,
  required (int, int) clockOut,
}) => Attendance(
  id: 'test',
  storeId: StoreIds.sablon,
  employeeId: _fresh,
  date: DateTime(2026, 1, 5),
  status: AttendanceStatus.done,
  sessions: [
    AttendanceSession(
      clockInAt: DateTime(2026, 1, 5, clockIn.$1, clockIn.$2),
      clockOutAt: DateTime(2026, 1, 5, clockOut.$1, clockOut.$2),
    ),
  ],
  paymentStatus: PaymentStatus.unpaid,
);

/// A working [Attendance] on 2026-01-05, one session, carrying the given
/// break windows — `(start, end?)` as `(h, m)` tuples, `end` null for a
/// running break.
Attendance _withPauses(List<((int, int), (int, int)?)> windows) => Attendance(
  id: 'test',
  storeId: StoreIds.sablon,
  employeeId: _fresh,
  date: DateTime(2026, 1, 5),
  status: AttendanceStatus.working,
  sessions: [
    AttendanceSession(
      clockInAt: DateTime(2026, 1, 5, 8),
      pauses: [
        for (final (start, end) in windows)
          AttendancePause(
            startAt: DateTime(2026, 1, 5, start.$1, start.$2),
            endAt: end == null ? null : DateTime(2026, 1, 5, end.$1, end.$2),
          ),
      ],
    ),
  ],
  paymentStatus: PaymentStatus.unpaid,
);
