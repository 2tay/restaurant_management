// The journée de service, against the database.
//
// `BusinessDayRepository` is the only file that writes `business_days`. The
// machine worth pinning: at most one open journée per store, one journée per
// date, a journée that stays current past midnight, and a close that refuses
// while anybody is still in service on it.
//
// The tests run a month after the seed so the seeded attendance rows (which
// sit on and before `seedInstant`) never share a date with the journées here.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart'
    show AttendanceIds, EmployeeIds, StoreIds;
import 'package:stock_inventory/models/models.dart';

import '../support/db_fixture.dart';

const _store = StoreIds.sablon;
const _manager = EmployeeIds.marc;
const _staff = EmployeeIds.noah;

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await openSeededDatabase();
  });

  // 18:00, a month after the seed — an evening service about to start.
  final evening = DateTime(2026, 9, 29, 18);
  final afterMidnight = DateTime(2026, 9, 30, 0, 30);
  final nextEvening = DateTime(2026, 9, 30, 18);

  BusinessDayRepository repo([DateTime? at]) =>
      BusinessDayRepository(db, clock: () => at ?? evening);

  group('opening', () {
    test('creates an open journée dated today, which becomes current',
        () async {
      final day = await repo().open(_store, openedByEmployeeId: _manager);

      expect(day, isNotNull);
      expect(day!.date, DateTime(2026, 9, 29));
      expect(day.openedAt, evening);
      expect(day.openedByEmployeeId, _manager);
      expect(day.closedAt, isNull);
      expect((await repo().current(_store))!.id, day.id);
    });

    test('is refused while another journée of the store is open', () async {
      final first = await repo().open(_store);
      final second = await repo(afterMidnight).open(_store);

      expect(first, isNotNull);
      expect(second, isNull);
      expect((await repo().current(_store))!.id, first!.id);
    });

    test('is refused on a date that already had a journée', () async {
      final day = (await repo().open(_store))!;
      await repo().close(day.id, closedByEmployeeId: _manager);

      expect(await repo(DateTime(2026, 9, 29, 22)).open(_store), isNull);
    });

    test('does not involve the other stores', () async {
      final sablon = await repo().open(_store);
      final liege = await repo().open(StoreIds.liege);

      expect(sablon, isNotNull);
      expect(liege, isNotNull);
      expect((await repo().current(StoreIds.liege))!.id, liege!.id);
    });
  });

  group('past midnight', () {
    test('the journée opened yesterday evening is still the current one',
        () async {
      final day = (await repo().open(_store))!;

      final current = await repo(afterMidnight).current(_store);
      expect(current!.id, day.id);
      expect(current.date, DateTime(2026, 9, 29));
    });
  });

  group('closing', () {
    test('stamps who and when, and leaves no current journée', () async {
      final day = (await repo().open(_store))!;
      final closed = await repo(
        afterMidnight,
      ).close(day.id, closedByEmployeeId: _manager);

      expect(closed!.closedAt, afterMidnight);
      expect(closed.closedByEmployeeId, _manager);
      expect(await repo().current(_store), isNull);
    });

    test('is refused the second time', () async {
      final day = (await repo().open(_store))!;
      await repo().close(day.id, closedByEmployeeId: _manager);

      expect(
        await repo().close(day.id, closedByEmployeeId: _manager),
        isNull,
      );
    });

    test('is refused for an unknown journée', () async {
      expect(
        await repo().close('nope', closedByEmployeeId: _manager),
        isNull,
      );
    });

    test('is refused while somebody is working or on a break on its date',
        () async {
      final day = (await repo().open(_store))!;
      final attendance = AttendanceRepository(db, clock: () => evening);
      final row = (await attendance.clockIn(_staff, _store))!;

      expect(
        await repo().close(day.id, closedByEmployeeId: _manager),
        isNull,
      );

      await attendance.startPause(row.id);
      expect(
        await repo().close(day.id, closedByEmployeeId: _manager),
        isNull,
      );

      await attendance.endPause(row.id);
      await attendance.clockOut(row.id);
      expect(
        await repo().close(day.id, closedByEmployeeId: _manager),
        isNotNull,
      );
    });

    group('with exit times for the shifts still open', () {
      late AttendanceRepository attendance;
      late BusinessDay day;

      setUp(() async {
        attendance = AttendanceRepository(db, clock: () => afterMidnight);
        day = (await repo().open(_store))!;
      });

      Future<String> clockIn(String employeeId) async =>
          (await attendance.clockIn(employeeId, _store, now: evening))!.id;

      test('ends each shift at its exit, a running break with it, then closes',
          () async {
        final working = await clockIn(_staff);
        final onBreak = await clockIn(EmployeeIds.amelie);
        await attendance.startPause(
          onBreak,
          now: DateTime(2026, 9, 29, 23),
        );

        final exit = DateTime(2026, 9, 29, 23, 30);
        final closed = await repo(afterMidnight).close(
          day.id,
          closedByEmployeeId: _manager,
          exits: {working: exit, onBreak: exit},
        );

        expect(closed!.closedAt, afterMidnight);
        final a = (await attendance.attendance(working))!;
        expect(a.status, AttendanceStatus.done);
        expect(a.sessions.single.clockOutAt, exit);
        final b = (await attendance.attendance(onBreak))!;
        expect(b.status, AttendanceStatus.done);
        expect(b.sessions.single.pauses.single.endAt, exit);
        expect(b.sessions.single.clockOutAt, exit);
      });

      test('an exit before the clock-in writes nothing', () async {
        final id = await clockIn(_staff);

        final closed = await repo(afterMidnight).close(
          day.id,
          closedByEmployeeId: _manager,
          exits: {id: DateTime(2026, 9, 29, 17)},
        );

        expect(closed, isNull);
        expect(
          (await attendance.attendance(id))!.status,
          AttendanceStatus.working,
        );
        expect((await repo().current(_store))!.id, day.id);
      });

      test('an exit in the future is refused', () async {
        final id = await clockIn(_staff);
        expect(
          await repo(afterMidnight).close(
            day.id,
            closedByEmployeeId: _manager,
            exits: {id: DateTime(2026, 9, 30, 2)},
          ),
          isNull,
        );
      });

      test('a shift left without an exit rolls the others back', () async {
        final first = await clockIn(_staff);
        await clockIn(EmployeeIds.amelie);

        final closed = await repo(afterMidnight).close(
          day.id,
          closedByEmployeeId: _manager,
          exits: {first: DateTime(2026, 9, 29, 23)},
        );

        expect(closed, isNull);
        expect(
          (await attendance.attendance(first))!.status,
          AttendanceStatus.working,
          reason: 'the exit already written is rolled back',
        );
      });

      test('an exit for a row outside the journée is refused', () async {
        await clockIn(_staff);
        expect(
          await repo(afterMidnight).close(
            day.id,
            closedByEmployeeId: _manager,
            exits: {AttendanceIds.karimToday: DateTime(2026, 9, 29, 23)},
          ),
          isNull,
        );
      });
    });

    test('lets the next day open its own journée', () async {
      final day = (await repo().open(_store))!;
      await repo(afterMidnight).close(day.id, closedByEmployeeId: _manager);

      final next = await repo(nextEvening).open(_store);
      expect(next!.date, DateTime(2026, 9, 30));
      expect(next.id, isNot(day.id));
    });
  });

  group('the board day', () {
    Future<BoardDay> boardDay(DateTime today) =>
        repo().watchBoardDay(_store, today).first;

    test('with no journée yet is today, with nothing behind it', () async {
      final day = await boardDay(afterMidnight);
      expect(day.date, DateTime(2026, 9, 30));
      expect(day.businessDay, isNull);
    });

    test('stays on the open journée past midnight', () async {
      final open = (await repo().open(_store))!;

      final day = await boardDay(afterMidnight);
      expect(day.date, DateTime(2026, 9, 29));
      expect(day.businessDay!.id, open.id);
    });

    test('shows today\'s journée once closed, and moves on the next day',
        () async {
      final open = (await repo().open(_store))!;
      await repo().close(open.id, closedByEmployeeId: _manager);

      final sameDay = await boardDay(DateTime(2026, 9, 29, 23));
      expect(sameDay.date, DateTime(2026, 9, 29));
      expect(sameDay.businessDay!.closedAt, isNotNull);

      final nextDay = await boardDay(afterMidnight);
      expect(nextDay.date, DateTime(2026, 9, 30));
      expect(nextDay.businessDay, isNull);
    });
  });

  group('currentOrOpen', () {
    test('returns the open journée rather than opening another', () async {
      final open = (await repo().open(_store))!;
      final again = await repo(afterMidnight).currentOrOpen(_store);
      expect(again!.id, open.id);
    });

    test('opens today\'s when none is open', () async {
      final opened = await repo().currentOrOpen(
        _store,
        openedByEmployeeId: _staff,
      );
      expect(opened!.date, DateTime(2026, 9, 29));
      expect(opened.openedByEmployeeId, _staff);
    });

    test('does not open a journée by itself before 05:00', () async {
      final night = DateTime(2026, 9, 30, 1, 10);
      expect(await repo(night).currentOrOpen(_store), isNull);
      expect(await repo().current(_store), isNull);

      final dawn = await repo(DateTime(2026, 9, 30, 5)).currentOrOpen(_store);
      expect(dawn!.date, DateTime(2026, 9, 30));
    });

    test('before 05:00, still returns the journée already open', () async {
      final open = (await repo().open(_store))!;
      expect((await repo(afterMidnight).currentOrOpen(_store))!.id, open.id);
    });

    test('follows the store\'s auto-open time', () async {
      final settings = StoreRepository(db);
      final sixAm = DateTime(2026, 9, 30, 6);

      await settings.updateStoreSettings(
        _store,
        businessDayAutoOpenMinutes: 7 * 60,
      );
      expect(await repo(sixAm).currentOrOpen(_store), isNull);

      // 00:00: any time — the night rule is off.
      await settings.updateStoreSettings(_store, businessDayAutoOpenMinutes: 0);
      final night = await repo(
        DateTime(2026, 9, 30, 1, 10),
      ).currentOrOpen(_store);
      expect(night!.date, DateTime(2026, 9, 30));
    });

    test('at night, opening by hand still works', () async {
      final night = DateTime(2026, 9, 30, 1, 10);
      final opened = await repo(
        night,
      ).open(_store, openedByEmployeeId: _manager);
      expect(opened!.date, DateTime(2026, 9, 30));
    });

    test('is null once today\'s journée is closed', () async {
      final open = (await repo().open(_store))!;
      await repo().close(open.id, closedByEmployeeId: _manager);
      expect(
        await repo(DateTime(2026, 9, 29, 23)).currentOrOpen(_store),
        isNull,
      );
    });
  });

  test('watchCurrent follows an open and a close', () async {
    final seen = <String?>[];
    final subscription = repo()
        .watchCurrent(_store)
        .listen((day) => seen.add(day?.id));

    await pumpEventQueue();
    final day = (await repo().open(_store))!;
    await pumpEventQueue();
    await repo().close(day.id, closedByEmployeeId: _manager);
    await pumpEventQueue();
    await subscription.cancel();

    expect(seen, <String?>[null, day.id, null]);
  });
}
