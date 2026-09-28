// The busy-day calendar against the database: what it saves, the list the
// alerts screen reads, and the reminder it files into the notification feed.

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stock_inventory/core/utils/busy_calendar.dart';
import 'package:stock_inventory/core/utils/formatters.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/notifications/notification_engine.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart' show StoreIds;
import 'package:stock_inventory/models/models.dart';

import '../support/db_fixture.dart';

void main() {
  late AppDatabase db;
  late CalendarRepository calendars;
  late AccountRepository account;

  const store = StoreIds.sablon;

  // The reminder's text names the dates in French, as the app does after
  // `main()` loads the locale.
  setUpAll(() => initializeDateFormatting(Formatters.locale));

  setUp(() async {
    db = await openSeededDatabase();
    calendars = CalendarRepository(db);
    account = AccountRepository(db);
  });

  Future<List<NotificationItem>> busyNotifications() async => [
    for (final n in await account.notifications(store))
      if (n.kind == NotificationKind.busyDays) n,
  ];

  group('saving', () {
    test('a store starts on Friday to Sunday with a one-day reminder', () async {
      final calendar = await calendars.calendar(store);
      expect(calendar.weekdays, BusyCalendarRules.defaultWeekdays);
      expect(calendar.reminderDays, 1);
      expect(calendar.dates, isEmpty);
    });

    test('weekdays, dates and the reminder round-trip', () async {
      await calendars.toggleWeekday(store, DateTime.friday);
      await calendars.toggleWeekday(store, DateTime.monday);
      await calendars.toggleDate(store, DateTime(2026, 12, 25, 15));
      await calendars.setReminderDays(store, 3);

      final calendar = await calendars.calendar(store);
      expect(calendar.weekdays, {DateTime.monday, DateTime.saturday, DateTime.sunday});
      expect(calendar.dates, {DateTime(2026, 12, 25)});
      expect(calendar.reminderDays, 3);
    });

    test('tapping a marked date again unmarks it', () async {
      await calendars.toggleDate(store, DateTime(2026, 12, 25));
      await calendars.toggleDate(store, DateTime(2026, 12, 25));
      expect((await calendars.calendar(store)).dates, isEmpty);
    });

    test('a reminder under one day is refused', () async {
      expect(await calendars.setReminderDays(store, 0), isFalse);
      expect((await calendars.calendar(store)).reminderDays, 1);
    });

    test('the stream follows a change to either table', () async {
      final stream = calendars.watch(store);
      final seen = <BusyCalendar>[];
      final sub = stream.listen(seen.add);
      await pumpEventQueue();

      await calendars.toggleDate(store, DateTime(2026, 12, 25));
      await pumpEventQueue();

      expect(seen.last.dates, {DateTime(2026, 12, 25)});
      await sub.cancel();
    });
  });

  test('the busy list is every product under its busy-day minimum', () async {
    final items = await ItemRepository(db).items(store);
    final rows = await ItemRepository(
      db,
    ).watchLowStockAlerts(store, belowBusyMinimum: true).first;

    expect(
      rows.map((r) => r.row.item.id).toSet(),
      items.where(isBelowBusyMinimum).map((i) => i.id).toSet(),
    );
    // It is a longer list than the ordinary alerts: everything low on an
    // ordinary day is also short for a busy one.
    final low = await ItemRepository(db).watchLowStockAlerts(store).first;
    expect(
      rows.map((r) => r.row.item.id),
      containsAll(low.map((r) => r.row.item.id)),
    );
  });

  group('the reminder', () {
    // Only one busy day, on Friday 25 December, so the dates are easy to read.
    setUp(() async {
      for (final weekday in BusyCalendarRules.defaultWeekdays) {
        await calendars.toggleWeekday(store, weekday);
      }
      await calendars.toggleDate(store, DateTime(2026, 12, 25));
      final items = await ItemRepository(db).items(store);
      expect(items.where(isBelowBusyMinimum), isNotEmpty);
    });

    Future<void> check(DateTime now) =>
        NotificationEngine(db).busyDaysApproaching(store, now: now);

    test('says nothing before the reminder day', () async {
      await check(DateTime(2026, 12, 23, 9));
      expect(await busyNotifications(), isEmpty);
    });

    test('says it once on the reminder day, however often it is asked', () async {
      await check(DateTime(2026, 12, 24, 9));
      await check(DateTime(2026, 12, 24, 10));
      await check(DateTime(2026, 12, 25, 8));

      final filed = await busyNotifications();
      expect(filed, hasLength(1));
      expect(filed.single.title, 'Jours chargés demain');
      expect(filed.single.body, contains('25 décembre'));
      expect(filed.single.isRead, isFalse);
    });

    test('says it again for the next period', () async {
      await calendars.toggleDate(store, DateTime(2026, 12, 31));
      await check(DateTime(2026, 12, 24, 9));
      await check(DateTime(2026, 12, 30, 9));

      expect(await busyNotifications(), hasLength(2));
    });

    test('says nothing when the preference is off', () async {
      await StoreRepository(db).setNotificationPreference(store, busyDays: false);
      await check(DateTime(2026, 12, 24, 9));
      expect(await busyNotifications(), isEmpty);
    });
  });
}
