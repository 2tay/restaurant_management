import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

import '../../models/attendance.dart';
import '../../models/business_day.dart';
import '../database/app_database.dart';
import '../mappers/mappers.dart';
import 'new_id.dart';

/// The app-wide clock (`package:clock`), read afresh on every call so a test
/// running under `withClock` is seen. A function of its own because the
/// constructor's `clock` parameter hides the package's getter.
DateTime _systemNow() => clock.now();

/// The journées de service — opening one, closing it, and reading the one that
/// is open.
///
/// **The only file that writes `business_days`**; `ux_audit.py` enforces it.
///
/// Every write refuses the wrong prior state (returns `null`) rather than
/// coercing it: a second journée while one is open, a second journée on a date
/// that already had one, closing a journée twice, or closing one while somebody
/// is still in service on it.
///
/// **The clock is injected**, as in `AttendanceRepository`: [clock] defaults to
/// `clock.now()`, and each write takes an optional `now` override on top.
class BusinessDayRepository {
  BusinessDayRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? _systemNow;

  final AppDatabase _db;
  final DateTime Function() _clock;

  Future<BusinessDay?> businessDay(String id) async {
    final row = await (_db.select(
      _db.businessDays,
    )..where((d) => d.id.equals(id))).getSingleOrNull();
    return row == null ? null : businessDayFromRow(row);
  }

  /// The store's open journée, or null when none is open. Does not depend on
  /// the clock: a journée opened yesterday evening is still the current one at
  /// 00:30.
  Future<BusinessDay?> current(String storeId) async {
    final row = await _openQuery(storeId).getSingleOrNull();
    return row == null ? null : businessDayFromRow(row);
  }

  Stream<BusinessDay?> watchCurrent(String storeId) => _openQuery(
    storeId,
  ).watchSingleOrNull().map((row) => row == null ? null : businessDayFromRow(row));

  /// Opens a journée dated today (by [now]). Refuses while another journée of
  /// the store is open, and when the store already had a journée on today's
  /// date — one date, one journée, since attendance rows join on it.
  Future<BusinessDay?> open(
    String storeId, {
    String? openedByEmployeeId,
    DateTime? now,
  }) {
    final at = now ?? _clock();
    final day = _dayOf(at);

    return _db.transaction(() async {
      if (await _openQuery(storeId).getSingleOrNull() != null) return null;

      final sameDate = await (_db.select(_db.businessDays)..where(
            (d) => d.storeId.equals(storeId) & d.date.equals(day),
          ))
          .getSingleOrNull();
      if (sameDate != null) return null;

      final entry = BusinessDay(
        id: newId(),
        storeId: storeId,
        date: day,
        openedAt: at,
        openedByEmployeeId: openedByEmployeeId,
      );
      await _db.into(_db.businessDays).insert(businessDayToRow(entry));
      return entry;
    });
  }

  /// Closes the journée. Refuses when it is already closed, or while any
  /// attendance on its date is still `working` / `onBreak` — those shifts get
  /// their exit time first, so a closed journée never hides an open shift.
  Future<BusinessDay?> close(
    String businessDayId, {
    required String closedByEmployeeId,
    DateTime? now,
  }) {
    return _db.transaction(() async {
      final row = await (_db.select(
        _db.businessDays,
      )..where((d) => d.id.equals(businessDayId))).getSingleOrNull();
      if (row == null || row.closedAt != null) return null;

      final stillIn = await (_db.select(_db.attendances)..where(
            (a) =>
                a.storeId.equals(row.storeId) &
                a.date.equals(row.date) &
                a.status.isInValues(const [
                  AttendanceStatus.working,
                  AttendanceStatus.onBreak,
                ]),
          ))
          .get();
      if (stillIn.isNotEmpty) return null;

      await (_db.update(
        _db.businessDays,
      )..where((d) => d.id.equals(businessDayId))).write(
        BusinessDaysCompanion(
          closedAt: Value(now ?? _clock()),
          closedByEmployeeId: Value(closedByEmployeeId),
        ),
      );
      return businessDay(businessDayId);
    });
  }

  // ---------------------------------------------------------------------------

  SimpleSelectStatement<$BusinessDaysTable, BusinessDayRow> _openQuery(
    String storeId,
  ) => _db.select(_db.businessDays)
    ..where((d) => d.storeId.equals(storeId) & d.closedAt.isNull());

  static DateTime _dayOf(DateTime v) => DateTime(v.year, v.month, v.day);
}
