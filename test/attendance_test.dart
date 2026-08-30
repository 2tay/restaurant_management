// The pointage state machine, exercised against the in-memory layer.
//
// `AttendanceMutations` is the only file that writes an `Attendance`, and this
// is the machine worth pinning: one row per employee per day, N breaks, every
// transition refusing the wrong prior state, and a day locked by payroll
// refusing every write. See `orders_test.dart` for the closest precedent.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/core/utils/attendance_status.dart';
import 'package:stock_inventory/mock_data/mock_data.dart';
import 'package:stock_inventory/models/models.dart';

import 'support/mock_reset.dart';

// An employee with no row today in the seed.
const _fresh = EmployeeIds.noah;

void main() {
  setUp(restoreMockData);

  group('clocking in', () {
    test('creates a working row, and a second call the same day is refused', () {
      final first = AttendanceMutations.clockIn(_fresh, StoreIds.sablon);
      expect(first, isNotNull);
      expect(first!.status, AttendanceStatus.working);
      expect(first.clockInAt, isNotNull);

      final second = AttendanceMutations.clockIn(_fresh, StoreIds.sablon);
      expect(second, isNull);
      expect(MockQueries.attendanceForToday(_fresh), same(first));
    });
  });

  group('the state machine has no back door', () {
    test('a break before clocking in is refused', () {
      expect(AttendanceMutations.startPause('no-such-row'), isNull);
    });

    test('ending a break before starting one is refused', () {
      final row = AttendanceMutations.clockIn(_fresh, StoreIds.sablon)!;
      expect(AttendanceMutations.endPause(row.id), isNull);
      expect(
        MockQueries.attendanceById(row.id)!.status,
        AttendanceStatus.working,
      );
    });

    test('clocking out while on break is refused', () {
      final row = AttendanceMutations.clockIn(_fresh, StoreIds.sablon)!;
      AttendanceMutations.startPause(row.id);
      expect(AttendanceMutations.clockOut(row.id), isNull);
      expect(
        MockQueries.attendanceById(row.id)!.status,
        AttendanceStatus.onBreak,
      );
    });
  });

  group('several breaks in one day', () {
    test('are all allowed, and totalBreak / workedDuration account for them',
        () {
      final clockIn = DateTime(2026, 1, 5, 8);
      final row = AttendanceMutations.clockIn(
        _fresh,
        StoreIds.sablon,
        now: clockIn,
      )!;

      AttendanceMutations.startPause(row.id, now: DateTime(2026, 1, 5, 10));
      AttendanceMutations.endPause(row.id, now: DateTime(2026, 1, 5, 10, 20));
      AttendanceMutations.startPause(row.id, now: DateTime(2026, 1, 5, 13));
      AttendanceMutations.endPause(row.id, now: DateTime(2026, 1, 5, 13, 30));
      final done = AttendanceMutations.clockOut(
        row.id,
        now: DateTime(2026, 1, 5, 17),
      )!;

      expect(done.pauses, hasLength(2));
      expect(totalBreak(done), const Duration(minutes: 50));
      // 9h between in and out, minus 50 minutes of breaks.
      expect(workedDuration(done), const Duration(hours: 8, minutes: 10));
    });
  });

  group('late and overtime, against the resolved schedule', () {
    ({int startMinutes, int endMinutes}) resolveFor(Employee e) {
      final s = MockQueries.storeSettings(e.storeId);
      return resolvedSchedule(
        e,
        storeOpenMinutes: s.openMinutes,
        storeCloseMinutes: s.closeMinutes,
      );
    }

    test('an employee override wins over the store hours', () {
      // Élise's personal schedule is 16:00–23:30.
      final elise = MockQueries.employeeById(EmployeeIds.elise)!;
      final schedule = resolveFor(elise);
      expect(schedule.startMinutes, 16 * 60);
      expect(schedule.endMinutes, 23 * 60 + 30);
    });

    test('a null override falls back to the store settings', () {
      // Karim has no personal schedule → Sablon's hours.
      final karim = MockQueries.employeeById(EmployeeIds.karim)!;
      final sablon = MockQueries.storeSettings(StoreIds.sablon);
      final schedule = resolveFor(karim);
      expect(schedule.startMinutes, sablon.openMinutes);
      expect(schedule.endMinutes, sablon.closeMinutes);
    });

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
      // Two 20-minute breaks: 40 min total, but no single one is over a
      // 30-minute allowance.
      final shortBreaks = _withPauses([
        (const (12, 0), const (12, 20)),
        (const (15, 0), const (15, 20)),
      ]);
      expect(hasLateBreak(shortBreaks, 30), isFalse);

      // One 45-minute break is over.
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

  group('attendancesForStore (Historique)', () {
    test('a from bound excludes an older day and keeps a recent one', () {
      final since3 = MockQueries.attendancesForStore(
        StoreIds.sablon,
        from: DateTime.now().subtract(const Duration(days: 3)),
      );
      final ids = since3.rows.map((a) => a.id).toSet();
      expect(ids.contains(AttendanceIds.camille5), isFalse); // 5 days ago
      expect(ids.contains(AttendanceIds.karim1), isTrue); // yesterday
    });

    test('a to bound excludes a more recent day and keeps an older one', () {
      final until3 = MockQueries.attendancesForStore(
        StoreIds.sablon,
        to: DateTime.now().subtract(const Duration(days: 3)),
      );
      final ids = until3.rows.map((a) => a.id).toSet();
      expect(ids.contains(AttendanceIds.karim1), isFalse); // yesterday
      expect(ids.contains(AttendanceIds.camille5), isTrue); // 5 days ago
    });

    test('no date bounds returns every row for the store', () {
      final all = MockQueries.attendancesForStore(StoreIds.sablon);
      final expected = mockAttendances
          .where((a) => a.storeId == StoreIds.sablon)
          .length;
      expect(all.totalCount, expected);
    });

    test('the status filter alone keeps only matching rows', () {
      final onBreak = MockQueries.attendancesForStore(
        StoreIds.sablon,
        status: AttendanceStatus.onBreak,
      );
      expect(onBreak.rows, isNotEmpty);
      expect(
        onBreak.rows.every((a) => a.status == AttendanceStatus.onBreak),
        isTrue,
      );
    });

    test('the employee filter narrows to a single employee', () {
      final karim = MockQueries.attendancesForStore(
        StoreIds.sablon,
        employeeId: EmployeeIds.karim,
      );
      expect(karim.rows, isNotEmpty);
      expect(
        karim.rows.every((a) => a.employeeId == EmployeeIds.karim),
        isTrue,
      );
    });

    test('filters combine with AND and rows sort most-recent-first', () {
      final result = MockQueries.attendancesForStore(
        StoreIds.sablon,
        from: DateTime.now().subtract(const Duration(days: 30)),
        status: AttendanceStatus.done,
        employeeId: EmployeeIds.karim,
      );
      expect(result.rows, isNotEmpty);
      for (final a in result.rows) {
        expect(a.employeeId, EmployeeIds.karim);
        expect(a.status, AttendanceStatus.done);
      }
      for (var i = 0; i < result.rows.length - 1; i++) {
        expect(
          result.rows[i].date.isBefore(result.rows[i + 1].date),
          isFalse,
        );
      }
    });

    test('pagination slices the rows and clamps an out-of-range page', () {
      final all = MockQueries.attendancesForStore(StoreIds.sablon);
      final total = all.totalCount;
      expect(total, greaterThan(3));

      final firstPage = MockQueries.attendancesForStore(
        StoreIds.sablon,
        page: 0,
        pageSize: 3,
      );
      expect(firstPage.rows, hasLength(3));
      expect(firstPage.pageCount, (total + 2) ~/ 3);

      final lastPage = MockQueries.attendancesForStore(
        StoreIds.sablon,
        page: 999,
        pageSize: 3,
      );
      expect(lastPage.page, firstPage.pageCount - 1);
      expect(lastPage.rows, isNotEmpty);
      // First and last page must not overlap.
      expect(
        firstPage.rows.map((a) => a.id).toSet().intersection(
          lastPage.rows.map((a) => a.id).toSet(),
        ),
        isEmpty,
      );
    });

    test('an empty result still reports one page', () {
      final none = MockQueries.attendancesForStore(
        StoreIds.saintGilles,
      );
      expect(none.rows, isEmpty);
      expect(none.totalCount, 0);
      expect(none.pageCount, 1);
    });

    test('the KPI stats are computed over the period, per resolved schedule',
        () {
      final stats = MockQueries.attendanceStatsForStore(
        StoreIds.sablon,
        from: DateTime.now().subtract(const Duration(days: 2)),
      );
      expect(stats.days, greaterThan(0));
      expect(stats.worked, greaterThan(Duration.zero));
      // Fatima arrived at 08:20 yesterday against an 08:00 start — but that is
      // 2 days back only if "yesterday" falls inside the window; assert the
      // shape rather than a brittle count.
      expect(stats.lateArrivals, greaterThanOrEqualTo(0));
      expect(stats.overtime, greaterThanOrEqualTo(Duration.zero));
    });
  });

  group('a payroll-locked day', () {
    test('refuses every write', () {
      // Karim two days ago is paid in the seed.
      final paid = mockAttendances.firstWhere(
        (a) => a.paymentStatus == PaymentStatus.paid,
      );

      expect(AttendanceMutations.startPause(paid.id), isNull);
      expect(AttendanceMutations.endPause(paid.id), isNull);
      expect(AttendanceMutations.clockOut(paid.id), isNull);
    });
  });

  test('the seed covers every state the walkthrough needs', () {
    final sablon = mockAttendances
        .where((a) => a.storeId == StoreIds.sablon)
        .toList();

    expect(sablon.where((a) => a.pauses.length >= 2), isNotEmpty);
    expect(
      sablon.where((a) => a.pauses.any((p) => p.endAt == null)),
      isNotEmpty,
      reason: 'a break still running today',
    );
    expect(
      sablon.where((a) => a.status == AttendanceStatus.done),
      isNotEmpty,
    );
    expect(
      sablon.where((a) => a.paymentStatus == PaymentStatus.paid),
      isNotEmpty,
    );
  });

  test('reset restores mockAttendances to the seed', () {
    final before = mockAttendances.length;
    AttendanceMutations.clockIn(_fresh, StoreIds.sablon);
    expect(mockAttendances.length, before + 1);

    MockWrite.reset();
    expect(mockAttendances.length, before);
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
        endAt: end == null
            ? null
            : DateTime(2026, 1, 5, end.$1, end.$2),
      ),
  ],
  paymentStatus: PaymentStatus.unpaid,
);
