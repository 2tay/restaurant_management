import 'package:drift/drift.dart';

import '../../core/utils/busy_calendar.dart';
import '../../models/busy_calendar.dart';
import '../database/app_database.dart';
import '../notifications/notification_engine.dart';
import 'soft_delete.dart';

/// The busy-day calendar: which weekdays are busy every week, which dates are
/// busy on their own, and how early to be reminded.
///
/// The weekly half and the reminder live on the establishment row, the dates
/// in `busy_dates`. Every write is one field, like the notification
/// preferences, so a calendar left open on another tablet cannot revert a
/// change it never saw.
class CalendarRepository {
  const CalendarRepository(this._db);

  final AppDatabase _db;

  /// The calendar, re-read whenever either of its two tables changes.
  ///
  /// A query that selects nothing but declares both tables: drift re-runs a
  /// watched query when a table it reads from is written, which is exactly the
  /// trigger wanted, and the two real reads happen in [calendar].
  Stream<BusyCalendar> watch(String storeId) => _db
      .customSelect('SELECT 1', readsFrom: {_db.stores, _db.busyDates})
      .watch()
      .asyncMap((_) => calendar(storeId));

  Future<BusyCalendar> calendar(String storeId) async {
    final store = await (_db.select(
      _db.stores,
    )..where((s) => s.id.equals(storeId) & s.deletedAt.isNull())).getSingleOrNull();
    final dates = await (_db.select(
      _db.busyDates,
    )..where((d) => d.storeId.equals(storeId) & d.deletedAt.isNull())).get();

    return BusyCalendar(
      storeId: storeId,
      weekdays: store == null
          ? BusyCalendarRules.defaultWeekdays
          : _parseWeekdays(store.busyWeekdays),
      dates: {for (final row in dates) ?_parseDay(row.day)},
      reminderDays:
          store?.busyReminderDays ?? BusyCalendarRules.defaultReminderDays,
    );
  }

  /// Ticks or unticks one weekday.
  Future<void> toggleWeekday(String storeId, int weekday) async {
    if (weekday < DateTime.monday || weekday > DateTime.sunday) return;
    final current = (await calendar(storeId)).weekdays;
    final next = {...current};
    next.contains(weekday) ? next.remove(weekday) : next.add(weekday);

    await (_db.update(_db.stores)..where((s) => s.id.equals(storeId))).write(
      StoresCompanion(busyWeekdays: Value(_formatWeekdays(next))),
    );
  }

  /// Marks [day] as busy, or unmarks it when it already is.
  ///
  /// Unmarking only marks the row deleted (see [SoftDelete]), so marking the
  /// same day again brings that row back: the store and the day are its key.
  Future<void> toggleDate(String storeId, DateTime day) async {
    final key = _formatDay(day);
    await _db.transaction(() async {
      final unmarked = await SoftDelete(_db).busyDate(storeId, key);
      if (unmarked > 0) return;

      await _db
          .into(_db.busyDates)
          .insertOnConflictUpdate(
            BusyDatesCompanion.insert(
              storeId: storeId,
              day: key,
              deletedAt: const Value(null),
            ),
          );
    });
  }

  /// Refuses anything under one day: a reminder on the day itself is the
  /// busy period's own warning, not a reminder.
  Future<bool> setReminderDays(String storeId, int days) async {
    if (days < 1) return false;
    final changed =
        await (_db.update(_db.stores)..where((s) => s.id.equals(storeId)))
            .write(StoresCompanion(busyReminderDays: Value(days)));
    return changed > 0;
  }

  /// Files the busy-period reminder if one is due — see
  /// [NotificationEngine.busyDaysApproaching]. Safe to call as often as the
  /// shell likes; it says each period once.
  Future<void> checkReminder(String storeId) =>
      NotificationEngine(_db).busyDaysApproaching(storeId);

  static Set<int> _parseWeekdays(String value) => value
      .split(',')
      .map((part) => int.tryParse(part.trim()))
      .whereType<int>()
      .where((n) => n >= DateTime.monday && n <= DateTime.sunday)
      .toSet();

  static String _formatWeekdays(Set<int> weekdays) =>
      (weekdays.toList()..sort()).join(',');

  static String _formatDay(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDay(String value) {
    final parsed = DateTime.tryParse(value);
    return parsed == null ? null : dayOf(parsed);
  }
}
