// The Stage 2 pointage rules, exercised against the in-memory layer.
//
// `TimeclockMutations` is the only file that writes a `TimeEntry`, and this
// is the state machine worth pinning: one entry per employee per day, one
// break per day, and every transition refusing the wrong prior state rather
// than coercing it. See `orders_test.dart` for the closest precedent — same
// idea, applied to the pointage board instead of the order lifecycle.
//
// The mock lists are global and mutable, so every test restores them — see
// test/support/mock_reset.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/core/utils/timeclock_status.dart';
import 'package:stock_inventory/mock_data/mock_data.dart';
import 'package:stock_inventory/models/models.dart';

import 'support/mock_reset.dart';

void main() {
  setUp(restoreMockData);

  group('clocking in', () {
    test('twice the same day for the same employee is refused', () {
      final first = TimeclockMutations.clockIn(
        EmployeeIds.noah,
        StoreIds.sablon,
      );
      expect(first, isNotNull);

      final second = TimeclockMutations.clockIn(
        EmployeeIds.noah,
        StoreIds.sablon,
      );
      expect(second, isNull);

      // The first entry is untouched — no partial overwrite from the refused
      // second call.
      expect(MockQueries.timeEntryForToday(EmployeeIds.noah), same(first));
    });

    test('creates an onShift entry for a fresh employee', () {
      final entry = TimeclockMutations.clockIn(
        EmployeeIds.julien,
        StoreIds.sablon,
      );

      expect(entry, isNotNull);
      expect(entry!.status, TimeEntryStatus.onShift);
      expect(entry.clockInAt, isNotNull);
      expect(entry.breakStartAt, isNull);
      expect(entry.clockOutAt, isNull);
    });
  });

  group('the state machine has no back door', () {
    test('starting a break before clocking in is refused', () {
      // No entry exists yet for this id, which is what "before clocking in"
      // means here — there is nothing to act on.
      expect(TimeclockMutations.startBreak('no-such-entry'), isNull);
    });

    test('ending a break before starting one is refused', () {
      final entry = TimeclockMutations.clockIn(
        EmployeeIds.noah,
        StoreIds.sablon,
      )!;

      expect(TimeclockMutations.endBreak(entry.id), isNull);
      expect(
        MockQueries.timeEntryForToday(EmployeeIds.noah)!.status,
        TimeEntryStatus.onShift,
      );
    });

    test('clocking out while on break is refused', () {
      final entry = TimeclockMutations.clockIn(
        EmployeeIds.noah,
        StoreIds.sablon,
      )!;
      TimeclockMutations.startBreak(entry.id);

      expect(TimeclockMutations.clockOut(entry.id), isNull);
      expect(
        MockQueries.timeEntryForToday(EmployeeIds.noah)!.status,
        TimeEntryStatus.onBreak,
      );
    });

    test('a second break the same day is refused', () {
      final entry = TimeclockMutations.clockIn(
        EmployeeIds.julien,
        StoreIds.sablon,
      )!;
      TimeclockMutations.startBreak(entry.id);
      final afterBreak = TimeclockMutations.endBreak(entry.id)!;
      expect(afterBreak.status, TimeEntryStatus.onShift);
      expect(afterBreak.breakEndAt, isNotNull);

      // Back on shift after a break, but a second Pause is not on offer —
      // only Fin de journée remains, per the brief's one-break-per-day rule.
      expect(TimeclockMutations.startBreak(entry.id), isNull);
      expect(
        MockQueries.timeEntryForToday(EmployeeIds.julien)!.breakStartAt,
        afterBreak.breakStartAt,
        reason: 'the refused call must not have touched the break window',
      );
    });
  });

  group('a late break', () {
    test('longer than the threshold sets isLate', () {
      final start = DateTime(2026, 1, 5, 12);
      final entry = TimeclockMutations.clockIn(
        EmployeeIds.noah,
        StoreIds.sablon,
        now: DateTime(2026, 1, 5, 8),
      )!;
      TimeclockMutations.startBreak(entry.id, now: start);

      final resumed = TimeclockMutations.endBreak(
        entry.id,
        now: start.add(
          PointageRules.maxBreakDuration + const Duration(minutes: 1),
        ),
      )!;

      expect(resumed.isLate, isTrue);
      expect(resumed.status, TimeEntryStatus.onShift);
    });

    test('shorter than the threshold does not set isLate', () {
      final start = DateTime(2026, 1, 5, 12);
      final entry = TimeclockMutations.clockIn(
        EmployeeIds.julien,
        StoreIds.sablon,
        now: DateTime(2026, 1, 5, 8),
      )!;
      TimeclockMutations.startBreak(entry.id, now: start);

      final resumed = TimeclockMutations.endBreak(
        entry.id,
        now: start.add(const Duration(minutes: 15)),
      )!;

      expect(resumed.isLate, isFalse);
    });
  });

  group('overtime', () {
    test('is zero for an 8h shift', () {
      final clockIn = DateTime(2026, 1, 5, 8);
      final entry = TimeclockMutations.clockIn(
        EmployeeIds.noah,
        StoreIds.sablon,
        now: clockIn,
      )!;

      final closed = TimeclockMutations.clockOut(
        entry.id,
        now: clockIn.add(const Duration(hours: 8)),
      )!;

      expect(workedDuration(closed), const Duration(hours: 8));
      expect(overtime(closed), Duration.zero);
    });

    test('is positive for a longer shift', () {
      final clockIn = DateTime(2026, 1, 5, 8);
      final entry = TimeclockMutations.clockIn(
        EmployeeIds.julien,
        StoreIds.sablon,
        now: clockIn,
      )!;

      final closed = TimeclockMutations.clockOut(
        entry.id,
        now: clockIn.add(const Duration(hours: 9, minutes: 30)),
      )!;

      expect(workedDuration(closed), const Duration(hours: 9, minutes: 30));
      expect(overtime(closed), const Duration(hours: 1, minutes: 30));
    });
  });

  group('timeEntriesForStore (Historique tab)', () {
    test('a period cutoff excludes an entry outside the window and keeps '
        'one inside it', () {
      final entries = MockQueries.timeEntriesForStore(
        StoreIds.sablon,
        withinDays: 3,
      );
      final ids = entries.map((e) => e.id).toSet();

      // 5 days ago — outside a 3-day window.
      expect(ids.contains(TimeEntryIds.camille5), isFalse);
      // Yesterday — well inside a 3-day window.
      expect(ids.contains(TimeEntryIds.fatimaYesterday), isTrue);
    });

    test('withinDays: null returns every entry for the store', () {
      final all = MockQueries.timeEntriesForStore(StoreIds.sablon);
      final expectedCount = mockTimeEntries
          .where((e) => e.storeId == StoreIds.sablon)
          .length;

      expect(all.length, expectedCount);
    });

    test('a status filter alone keeps only matching entries', () {
      final entries = MockQueries.timeEntriesForStore(
        StoreIds.sablon,
        status: TimeEntryStatus.onBreak,
      );

      expect(entries.map((e) => e.id), [TimeEntryIds.eliseToday]);
    });

    test('an employee-name filter alone matches case-insensitively and on '
        'a partial name', () {
      final entries = MockQueries.timeEntriesForStore(
        StoreIds.sablon,
        employeeQuery: 'ADDOUCH', // part of "Haddouch", upper-cased
      );

      expect(entries.map((e) => e.id).toSet(), {
        TimeEntryIds.karimToday,
        TimeEntryIds.karimYesterday,
        TimeEntryIds.karim3,
      });
    });

    test('period, status and employee filters combine with AND', () {
      final entries = MockQueries.timeEntriesForStore(
        StoreIds.sablon,
        withinDays: 30,
        status: TimeEntryStatus.clockedOut,
        employeeQuery: 'fatima',
      );

      expect(entries.map((e) => e.id), [
        // Most recent day first.
        TimeEntryIds.fatimaYesterday,
        TimeEntryIds.fatima3,
      ]);
    });

    test('results sort most-recent-day-first', () {
      final entries = MockQueries.timeEntriesForStore(StoreIds.sablon);

      for (var i = 0; i < entries.length - 1; i++) {
        expect(
          entries[i].date.isBefore(entries[i + 1].date),
          isFalse,
          reason:
              'entry $i (${entries[i].date}) should not precede '
              'entry ${i + 1} (${entries[i + 1].date})',
        );
      }
    });
  });

  test('the seed data covers a late break and real overtime', () {
    // Demo-critical: both states need to be shown without manipulation, the
    // same property orders_test.dart pins for every order status.
    expect(mockTimeEntries.any((e) => e.isLate), isTrue);
    expect(
      mockTimeEntries.any(
        (e) => (overtime(e) ?? Duration.zero) > Duration.zero,
      ),
      isTrue,
    );
  });

  test('reset restores mockTimeEntries to the seed', () {
    final before = List<TimeEntry>.of(mockTimeEntries);

    TimeclockMutations.clockIn(EmployeeIds.noah, StoreIds.sablon);
    expect(mockTimeEntries.length, before.length + 1);

    MockWrite.reset();

    expect(mockTimeEntries.length, before.length);
    expect(mockTimeEntries.map((e) => e.id), before.map((e) => e.id));
  });
}
