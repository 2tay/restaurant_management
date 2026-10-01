import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

import '../../core/utils/attendance_status.dart';
import '../../core/utils/dates.dart';
import '../../models/attendance.dart';
import '../../models/business_day.dart';
import '../database/app_database.dart';
import '../mappers/mappers.dart';
import 'attendance_repository.dart';
import 'new_id.dart';
import 'store_repository.dart';

/// The app-wide clock (`package:clock`), read afresh on every call so a test
/// running under `withClock` is seen. A function of its own because the
/// constructor's `clock` parameter hides the package's getter.
DateTime _systemNow() => clock.now();

/// What the pointage board works on: the [date] its cards read, and the
/// journée behind it — the open one; else today's, already closed; else none
/// yet (the first Pointer opens it).
typedef BoardDay = ({DateTime date, BusinessDay? businessDay});

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

  /// The board's day, re-emitted whenever a journée opens or closes. [today]
  /// is the calendar day the caller is on — used only when no journée is
  /// open, so a journée running past midnight keeps the board on its date.
  Stream<BoardDay> watchBoardDay(String storeId, DateTime today) {
    final day = dayOf(today);
    return (_db.select(_db.businessDays)..where(
          (d) =>
              d.storeId.equals(storeId) &
              (d.closedAt.isNull() | d.date.equals(day)),
        ))
        .watch()
        .map((rows) {
          final chosen =
              rows.where((r) => r.closedAt == null).firstOrNull ??
              rows.firstOrNull;
          return (
            date: chosen?.date ?? day,
            businessDay: chosen == null ? null : businessDayFromRow(chosen),
          );
        });
  }

  /// The journée a Pointer lands in: the open one, else a new one opened by
  /// [openedByEmployeeId]. Null when today's journée was already closed — one
  /// journée per date, and a closed one is not reopened — and, with none
  /// open, before the store's `businessDayAutoOpenMinutes`: a punch in the
  /// night does not open the next day's journée by accident.
  Future<BusinessDay?> currentOrOpen(
    String storeId, {
    String? openedByEmployeeId,
    DateTime? now,
  }) {
    final at = now ?? _clock();
    return _db.transaction(() async {
      final open = await current(storeId);
      if (open != null) return open;
      final settings = await StoreRepository(_db).settings(storeId);
      final opensAt = businessDayAutoOpenAt(
        at,
        settings.businessDayAutoOpenMinutes,
      );
      if (at.isBefore(opensAt)) return null;
      return this.open(storeId, openedByEmployeeId: openedByEmployeeId, now: at);
    });
  }

  /// Opens a journée dated today (by [now]). Refuses while another journée of
  /// the store is open, and when the store already had a journée on today's
  /// date — one date, one journée, since attendance rows join on it.
  Future<BusinessDay?> open(
    String storeId, {
    String? openedByEmployeeId,
    DateTime? now,
  }) {
    final at = now ?? _clock();
    final day = dayOf(at);

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

  /// Closes the journée — **all or nothing**. [exits] gives the exit time of
  /// each shift still open on it (attendance id → time): each is ended there
  /// (`AttendanceRepository.endShift`), then the journée is stamped closed.
  ///
  /// Refuses, writing nothing, when the journée is missing or already closed,
  /// when an exit names a row outside the journée or an impossible time
  /// (future, before the clock-in or the running break), or when a shift would
  /// still be open afterwards — a closed journée never hides an open shift.
  Future<BusinessDay?> close(
    String businessDayId, {
    required String closedByEmployeeId,
    Map<String, DateTime> exits = const {},
    DateTime? now,
  }) async {
    try {
      return await _db.transaction(() async {
        final row = await (_db.select(
          _db.businessDays,
        )..where((d) => d.id.equals(businessDayId))).getSingleOrNull();
        if (row == null || row.closedAt != null) return null;

        final attendance = AttendanceRepository(_db, clock: _clock);
        for (final MapEntry(key: id, value: at) in exits.entries) {
          final entry = await attendance.attendance(id);
          if (entry == null ||
              entry.storeId != row.storeId ||
              entry.date != row.date) {
            throw const _CloseRefused();
          }
          if (await attendance.endShift(
                id,
                at,
                setByEmployeeId: closedByEmployeeId,
              ) ==
              null) {
            throw const _CloseRefused();
          }
        }

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
        if (stillIn.isNotEmpty) throw const _CloseRefused();

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
    } on _CloseRefused {
      // Thrown rather than returned so the transaction rolls back the exits
      // already written.
      return null;
    }
  }

  // ---------------------------------------------------------------------------

  SimpleSelectStatement<$BusinessDaysTable, BusinessDayRow> _openQuery(
    String storeId,
  ) => _db.select(_db.businessDays)
    ..where((d) => d.storeId.equals(storeId) & d.closedAt.isNull());

}

/// A close refused after some of its writes — thrown to roll them back.
class _CloseRefused implements Exception {
  const _CloseRefused();
}
