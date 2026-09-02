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
    test('creates a working row, and a second call the same day is refused',
        () async {
      final first = await repo().clockIn(_fresh, StoreIds.sablon);
      expect(first, isNotNull);
      expect(first!.status, AttendanceStatus.working);
      expect(first.clockInAt, isNotNull);

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
      expect(after.pauses, hasLength(1));
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

      expect(done.pauses, hasLength(2));
      expect(totalBreak(done), const Duration(minutes: 50));
      // 9h between in and out, minus 50 minutes of breaks.
      expect(workedDuration(done), const Duration(hours: 8, minutes: 10));
    });
  });

  group('late and overtime, against the resolved schedule', () {
    test('late is flagged past the grace window, not within it', () {
      final onTime = _finished(clockIn: const (8, 3), clockOut: const (17, 0));
      final late = _finished(clockIn: const (8, 20), clockOut: const (17, 0));

      expect(isLate(onTime, 8 * 60), isFalse);
      expect(isLate(late, 8 * 60), isTrue);
      expect(lateBy(late, 8 * 60), const Duration(minutes: 15));
    });

    test('overtime is time clocked out past the scheduled end, floored at 0',
        () {
      final over = _finished(clockIn: const (8, 0), clockOut: const (18, 30));
      final early = _finished(clockIn: const (8, 0), clockOut: const (16, 0));

      expect(overtimeBy(over, 17 * 60), const Duration(hours: 1, minutes: 30));
      expect(overtimeBy(early, 17 * 60), Duration.zero);
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
        breakOverrun(longBreak.pauses.first, 30),
        const Duration(minutes: 15),
      );
      expect(totalBreakOverrun(longBreak, 30), const Duration(minutes: 15));
    });

    test('a running break is never counted as an overrun', () {
      final open = _withPauses([(const (12, 0), null)]);
      expect(breakOverrun(open.pauses.first, 30), Duration.zero);
      expect(hasLateBreak(open, 30), isFalse);
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
      expect(stats.lateArrivals, greaterThanOrEqualTo(0));
      expect(stats.overtime, greaterThanOrEqualTo(Duration.zero));
    });
  });

  group('the evaluation context is frozen at clock-in', () {
    DateTime todayAt(int hour) => DateTime(
          seedInstant.year,
          seedInstant.month,
          seedInstant.day,
          hour,
        );

    test('clockIn stamps the resolved schedule and break allowance', () async {
      final day = (await repo().clockIn(_fresh, StoreIds.sablon))!;
      // Noah has no personal schedule → the store's 08:00–17:00, 45-min break.
      expect(day.scheduledStartMinutes, 8 * 60);
      expect(day.scheduledEndMinutes, 17 * 60);
      expect(day.maxBreakMinutes, 45);
    });

    test('a later store-hours change does not rewrite a past day', () async {
      final day = (await repo().clockIn(_fresh, StoreIds.sablon))!;
      await repo().clockOut(day.id, now: todayAt(18));

      final before = await repo().stats(
        StoreIds.sablon,
        from: seedInstant,
        to: seedInstant,
        employeeId: _fresh,
      );
      expect(before.overtime, const Duration(hours: 1));

      await StoreRepository(db).updateStoreSettings(
        StoreIds.sablon,
        closeMinutes: 22 * 60,
      );

      final after = await repo().stats(
        StoreIds.sablon,
        from: seedInstant,
        to: seedInstant,
        employeeId: _fresh,
      );
      expect(
        after.overtime,
        const Duration(hours: 1),
        reason: 'measured against the 17:00 close frozen on the row, not the '
            'new 22:00 one',
      );
    });

    test('a row with no frozen context falls back to the live schedule',
        () async {
      final day = (await repo().clockIn(_fresh, StoreIds.sablon))!;
      await repo().clockOut(day.id, now: todayAt(18));

      // A row from before schema v3, before the backfill ran.
      await (db.update(db.attendances)..where((a) => a.id.equals(day.id))).write(
        const AttendancesCompanion(
          scheduledStartMinutes: Value(null),
          scheduledEndMinutes: Value(null),
          maxBreakMinutes: Value(null),
        ),
      );

      await StoreRepository(db).updateStoreSettings(
        StoreIds.sablon,
        closeMinutes: 22 * 60,
      );

      final after = await repo().stats(
        StoreIds.sablon,
        from: seedInstant,
        to: seedInstant,
        employeeId: _fresh,
      );
      expect(
        after.overtime,
        Duration.zero,
        reason: 'no snapshot → judged against the current 22:00 close',
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

    expect(rows.where((a) => a.pauses.length >= 2), isNotEmpty);
    expect(
      rows.where((a) => a.pauses.any((p) => p.endAt == null)),
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
  clockInAt: DateTime(2026, 1, 5, clockIn.$1, clockIn.$2),
  clockOutAt: DateTime(2026, 1, 5, clockOut.$1, clockOut.$2),
  pauses: const [],
  paymentStatus: PaymentStatus.unpaid,
);

/// A working [Attendance] on 2026-01-05 carrying the given break windows —
/// `(start, end?)` as `(h, m)` tuples, `end` null for a running break.
Attendance _withPauses(List<((int, int), (int, int)?)> windows) => Attendance(
  id: 'test',
  storeId: StoreIds.sablon,
  employeeId: _fresh,
  date: DateTime(2026, 1, 5),
  status: AttendanceStatus.working,
  clockInAt: DateTime(2026, 1, 5, 8),
  pauses: [
    for (final (start, end) in windows)
      AttendancePause(
        startAt: DateTime(2026, 1, 5, start.$1, start.$2),
        endAt: end == null ? null : DateTime(2026, 1, 5, end.$1, end.$2),
      ),
  ],
  paymentStatus: PaymentStatus.unpaid,
);
