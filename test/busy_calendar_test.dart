// The busy-day calendar's rules: which days are busy, how they group into a
// period, and when the reminder for a period is on.
//
// 28 September 2026 is a Monday, so in these tests Friday is 2 October and the
// default weekend runs 2–4 October.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/core/utils/busy_calendar.dart';
import 'package:stock_inventory/models/models.dart';

BusyCalendar _calendar({
  Set<int> weekdays = BusyCalendarRules.defaultWeekdays,
  Set<DateTime> dates = const {},
  int reminderDays = 1,
}) => BusyCalendar(
  storeId: 'store',
  weekdays: weekdays,
  dates: dates,
  reminderDays: reminderDays,
);

DateTime _day(int month, int day, [int year = 2026]) =>
    DateTime(year, month, day);

Item _item({
  required double quantity,
  required double minimum,
  double? busyMinimum,
  double maxStock = 0,
}) => Item(
  id: 'item',
  storeId: 'store',
  name: 'Item',
  categoryId: 'cat',
  unitId: 'unit',
  quantity: quantity,
  lowStockThreshold: minimum,
  holidayLowStockThreshold: busyMinimum,
  maxStock: maxStock,
  updatedAt: _day(1, 1),
);

void main() {
  group('isBusyDay', () {
    test('Friday to Sunday are busy by default, the rest of the week is not', () {
      final calendar = _calendar();
      expect(isBusyDay(_day(10, 2), calendar), isTrue); // Friday
      expect(isBusyDay(_day(10, 4), calendar), isTrue); // Sunday
      expect(isBusyDay(_day(10, 5), calendar), isFalse); // Monday
    });

    test('a marked date is busy whatever its weekday, at any time of day', () {
      final calendar = _calendar(dates: {_day(9, 30)});
      expect(isBusyDay(DateTime(2026, 9, 30, 18, 45), calendar), isTrue);
    });
  });

  group('nextBusyPeriod', () {
    test('a weekend is one period, not three days', () {
      final period = nextBusyPeriod(_day(9, 30), _calendar());
      expect(period, (start: _day(10, 2), end: _day(10, 4)));
    });

    test('a holiday the day before the weekend joins it', () {
      final period = nextBusyPeriod(
        _day(9, 30),
        _calendar(dates: {_day(10, 1)}),
      );
      expect(period, (start: _day(10, 1), end: _day(10, 4)));
    });

    test('inside a period, it is that period, from its real first day', () {
      final period = nextBusyPeriod(_day(10, 3), _calendar());
      expect(period, (start: _day(10, 2), end: _day(10, 4)));
    });

    test('nothing ticked and nothing marked means no period at all', () {
      expect(nextBusyPeriod(_day(9, 30), _calendar(weekdays: {})), isNull);
    });

    test('a period can run across a month and a year', () {
      final period = nextBusyPeriod(
        _day(12, 20),
        _calendar(weekdays: {}, dates: {_day(12, 31), _day(1, 1, 2027)}),
      );
      expect(period, (start: _day(12, 31), end: _day(1, 1, 2027)));
    });

    test('every weekday ticked still gives a period that ends', () {
      final period = nextBusyPeriod(
        _day(9, 30),
        _calendar(weekdays: {1, 2, 3, 4, 5, 6, 7}),
      );
      expect(period, isNotNull);
    });
  });

  group('activeBusyWarning', () {
    test('one day before: on the Thursday, not on the Wednesday', () {
      final calendar = _calendar();
      expect(activeBusyWarning(_day(9, 30), calendar), isNull);
      expect(activeBusyWarning(_day(10, 1), calendar), isNotNull);
    });

    test('three days before: on from the Tuesday', () {
      final calendar = _calendar(reminderDays: 3);
      expect(activeBusyWarning(_day(9, 28), calendar), isNull);
      expect(activeBusyWarning(_day(9, 29), calendar), isNotNull);
    });

    test('stays on while the period is running', () {
      final warning = activeBusyWarning(_day(10, 4), _calendar());
      expect(warning, (start: _day(10, 2), end: _day(10, 4)));
    });

    test('off the day after it ends', () {
      expect(activeBusyWarning(_day(10, 5), _calendar()), isNull);
    });
  });

  group('reminderStartOf', () {
    test('is reminderDays before the first busy day', () {
      final calendar = _calendar(reminderDays: 2);
      final period = nextBusyPeriod(_day(9, 28), calendar)!;
      expect(reminderStartOf(period, calendar), _day(9, 30));
    });

    // A seven-day reminder on a weekly weekend would reach back into the
    // weekend before; it starts the Monday after it instead.
    test('never reaches back into the previous period', () {
      final calendar = _calendar(reminderDays: 7);
      final period = nextBusyPeriod(_day(10, 5), calendar)!;
      expect(period.start, _day(10, 9));
      expect(reminderStartOf(period, calendar), _day(10, 5));
    });
  });

  group('busy-day shortfall', () {
    test('an empty busy-day minimum means twice the ordinary one', () {
      final item = _item(quantity: 15, minimum: 10);
      expect(busyShortfallOf(item), 5);
      expect(isBelowBusyMinimum(item), isTrue);
    });

    test('an explicit busy-day minimum wins', () {
      final item = _item(quantity: 15, minimum: 10, busyMinimum: 12);
      expect(busyShortfallOf(item), 0);
      expect(isBelowBusyMinimum(item), isFalse);
    });

    test('ordering ahead reaches the busy minimum even past the maximum', () {
      // Maximum 18 would top up by 3; the busy minimum of 30 needs 15.
      final item = _item(quantity: 15, minimum: 10, busyMinimum: 30, maxStock: 18);
      expect(busyTopUpQuantity(item), 15);
    });
  });
}
