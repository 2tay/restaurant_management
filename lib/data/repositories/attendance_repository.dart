import 'package:drift/drift.dart';

import '../../core/utils/attendance_status.dart';
import '../../models/attendance.dart';
import '../../models/store_settings.dart';
import '../database/app_database.dart';
import '../mappers/mappers.dart';
import 'new_id.dart';
import 'store_repository.dart';

/// The KPI figures above the Historique de pointage table.
typedef AttendanceStats = ({
  int days,
  Duration worked,
  int lateArrivals,
  Duration overtime,
  int lateBreaks,
});

/// One page of the store's attendance log.
typedef AttendancePage = ({
  List<Attendance> rows,
  int totalCount,
  int page,
  int pageCount,
});

/// The pointage — attendance rows, their pauses, and the figures derived from
/// the two.
///
/// **The only file that writes `attendances` and `attendance_pauses`**, the same
/// single-writer discipline every other aggregate keeps; `ux_audit.py` enforces
/// it. `PayrollRepository.pay` reaches the `payrollPeriodId` lock through
/// [lockForPayroll] here rather than writing the column itself.
///
/// Every write refuses the wrong prior state (returns `null` / `false`) rather
/// than coercing it, and **refuses any write against a day a payroll run has
/// locked** — a paid day is immutable.
///
/// **The clock is injected.** "Today" is resolved when a query runs, and a test
/// pins it between two calls. [clock] defaults to `DateTime.now`; the provider
/// supplies that, `db_fixture.dart` supplies a fixed function, and the
/// today-scoped reads take an optional `now` override on top.
class AttendanceRepository {
  AttendanceRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  Future<Attendance?> attendance(String id) async {
    final row = await (_db.select(
      _db.attendances,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return (await _assemble([row])).first;
  }

  /// This employee's row for today, or null when they have neither clocked in
  /// nor been marked absent — a day with no row means
  /// [AttendanceStatus.notClockedIn].
  Future<Attendance?> today(String employeeId, {DateTime? now}) async {
    final row = await _todayQuery(employeeId, now).getSingleOrNull();
    if (row == null) return null;
    return (await _assemble([row])).first;
  }

  Stream<Attendance?> watchToday(String employeeId, {DateTime? now}) =>
      _todayQuery(employeeId, now).watchSingleOrNull().asyncMap((row) async {
        if (row == null) return null;
        return (await _assemble([row])).first;
      });

  /// Every today's-row for a store, keyed by employee id — the pointage board
  /// reads this once and joins it against the active roster, rather than
  /// opening a `watchToday` per card (8 cards × a stream each is the shape to
  /// avoid). An employee with no entry today is simply absent from the map.
  Stream<Map<String, Attendance>> watchTodayForStore(
    String storeId, {
    DateTime? now,
  }) {
    final day = _dayOf(now ?? _clock());
    return (_db.select(_db.attendances)
          ..where((a) => a.storeId.equals(storeId) & a.date.equals(day)))
        .watch()
        .asyncMap((rows) async {
          final assembled = await _assemble(rows);
          return {for (final a in assembled) a.employeeId: a};
        });
  }

  /// One employee's attendance, **most recent day first** — `date` descending,
  /// then `clockInAt` descending so several rows on one day keep a stable
  /// order.
  Stream<List<Attendance>> watchForEmployee(String employeeId) =>
      _forEmployeeQuery(employeeId).watch().asyncMap(_assemble);

  Future<List<Attendance>> forEmployee(String employeeId) =>
      _forEmployeeQuery(employeeId).get().then(_assemble);

  /// The store's attendance log for the Historique page — filtered on a
  /// [from]–[to] day range, a [status] and one [employeeId] (combined with
  /// AND), most-recent-day-first, sliced into a page.
  ///
  /// [from] / [to] are inclusive day bounds, each null meaning "no bound on that
  /// side". [page] is clamped into range.
  Future<AttendancePage> page(
    String storeId, {
    DateTime? from,
    DateTime? to,
    AttendanceStatus? status,
    String? employeeId,
    int page = 0,
    int pageSize = 25,
  }) async {
    final base = _logQuery(
      storeId,
      from: from,
      to: to,
      status: status,
      employeeId: employeeId,
    );

    final total = await base.get().then((rows) => rows.length);
    final pageCount = total == 0 ? 1 : (total + pageSize - 1) ~/ pageSize;
    final safePage = page.clamp(0, pageCount - 1);

    final pageQuery = _logQuery(
        storeId,
        from: from,
        to: to,
        status: status,
        employeeId: employeeId,
      )
      ..limit(pageSize, offset: safePage * pageSize);

    return (
      rows: await pageQuery.get().then(_assemble),
      totalCount: total,
      page: safePage,
      pageCount: pageCount,
    );
  }

  Stream<AttendancePage> watchPage(
    String storeId, {
    DateTime? from,
    DateTime? to,
    AttendanceStatus? status,
    String? employeeId,
    int page = 0,
    int pageSize = 25,
  }) {
    // The table is small and the page needs a total count anyway, so this
    // watches every matching row and paginates in Dart rather than running a
    // separate COUNT stream and keeping the two in step.
    return _logQuery(
      storeId,
      from: from,
      to: to,
      status: status,
      employeeId: employeeId,
    ).watch().asyncMap((rows) async {
      final total = rows.length;
      final pageCount = total == 0 ? 1 : (total + pageSize - 1) ~/ pageSize;
      final safePage = page.clamp(0, pageCount - 1);
      final start = (safePage * pageSize).clamp(0, total);
      final end = (start + pageSize).clamp(0, total);
      return (
        rows: await _assemble(rows.sublist(start, end)),
        totalCount: total,
        page: safePage,
        pageCount: pageCount,
      );
    });
  }

  /// The KPI figures above the Historique table — over the store log matching
  /// [from]–[to] and [employeeId], independent of the status / page filters
  /// below. Late arrivals and overtime are measured against each employee's
  /// resolved schedule.
  ///
  /// SQL fetches the rows and pauses in the range; the durations are folded in
  /// Dart with the **unchanged** `attendance_status.dart` functions. Not pure
  /// SQL — that arithmetic stays one definition.
  Future<AttendanceStats> stats(
    String storeId, {
    DateTime? from,
    DateTime? to,
    String? employeeId,
  }) async {
    final settings = await StoreRepository(_db).settings(storeId);
    final schedules = await _schedulesFor(storeId, settings);

    final rows = await _logQuery(
      storeId,
      from: from,
      to: to,
      employeeId: employeeId,
    ).get();
    final entries = await _assemble(rows);

    var worked = Duration.zero;
    var overtime = Duration.zero;
    var lateArrivals = 0;
    var lateBreaks = 0;

    for (final entry in entries) {
      final schedule = schedules[entry.employeeId];
      if (schedule == null) continue;
      worked += workedDuration(entry) ?? Duration.zero;
      overtime += overtimeBy(entry, schedule.endMinutes) ?? Duration.zero;
      if (isLate(entry, schedule.startMinutes)) lateArrivals++;
      if (hasLateBreak(entry, settings.maxBreakMinutes)) lateBreaks++;
    }

    return (
      days: entries.length,
      worked: worked,
      lateArrivals: lateArrivals,
      overtime: overtime,
      lateBreaks: lateBreaks,
    );
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// `Pointer`. Creates the day's `working` row. Refuses (returns null) if one
  /// already exists for this employee today — one row per employee per calendar
  /// day, which the `(employeeId, date)` unique index also enforces.
  Future<Attendance?> clockIn(
    String employeeId,
    String storeId, {
    DateTime? now,
  }) {
    final at = now ?? _clock();
    final day = _dayOf(at);

    return _db.transaction(() async {
      final existing = await (_db.select(_db.attendances)..where(
            (a) => a.employeeId.equals(employeeId) & a.date.equals(day),
          ))
          .getSingleOrNull();
      if (existing != null) return null;

      final entry = Attendance(
        id: newId(),
        storeId: storeId,
        employeeId: employeeId,
        date: day,
        status: AttendanceStatus.working,
        clockInAt: at,
        pauses: const [],
        paymentStatus: PaymentStatus.unpaid,
      );
      await _db.into(_db.attendances).insert(attendanceToRow(entry));
      return entry;
    });
  }

  /// `Pause`. Refuses unless the day is `working`. Appends a pause row at
  /// `position = count` and flips the day to `onBreak`. There is no cap — the
  /// button offers `Pause` again after every `Reprendre`.
  ///
  /// The count-then-insert runs inside the transaction, so two Pause taps
  /// racing each other resolve to exactly one appended break: drift serialises
  /// the write transactions, the second sees `onBreak` and refuses.
  Future<Attendance?> startPause(String attendanceId, {DateTime? now}) {
    return _mutate(attendanceId, (row) async {
      if (row.status != AttendanceStatus.working) return null;

      final count = await _pauseCount(attendanceId);
      await _db
          .into(_db.attendancePauses)
          .insert(
            pauseToRow(
              AttendancePause(startAt: now ?? _clock()),
              attendanceId: attendanceId,
              position: count,
              id: newId(),
            ),
          );
      return AttendanceStatus.onBreak;
    });
  }

  /// `Reprendre`. Refuses unless the day is `onBreak` with an open break.
  /// Closes that break and flips the day back to `working`.
  Future<Attendance?> endPause(String attendanceId, {DateTime? now}) {
    return _mutate(attendanceId, (row) async {
      if (row.status != AttendanceStatus.onBreak) return null;

      final open =
          await (_db.select(_db.attendancePauses)
                ..where(
                  (p) => p.attendanceId.equals(attendanceId) & p.endAt.isNull(),
                )
                ..orderBy([(p) => OrderingTerm(expression: p.position)]))
              .get();
      if (open.isEmpty) return null;

      await (_db.update(_db.attendancePauses)
            ..where((p) => p.id.equals(open.first.id)))
          .write(AttendancePausesCompanion(endAt: Value(now ?? _clock())));
      return AttendanceStatus.working;
    });
  }

  /// `Fin de journée`. Refuses unless the day is `working` — in particular it
  /// refuses while `onBreak`, so nobody clocks out mid-break.
  Future<Attendance?> clockOut(String attendanceId, {DateTime? now}) {
    return _mutate(attendanceId, (row) async {
      if (row.status != AttendanceStatus.working) return null;
      await (_db.update(_db.attendances)
            ..where((a) => a.id.equals(attendanceId)))
          .write(AttendancesCompanion(clockOutAt: Value(now ?? _clock())));
      return AttendanceStatus.done;
    });
  }

  /// Locks a set of finished days against a payroll run — stamps
  /// [payrollPeriodId] on each. **Called only by `PayrollRepository.pay`**,
  /// inside its transaction, so the attendance rows still have exactly one
  /// writer.
  ///
  /// Refuses the whole call (returns false, touches nothing) if any id is
  /// missing or already points at a period. `paymentStatus` is derived from the
  /// FK, so there is nothing else to flip.
  Future<bool> lockForPayroll(
    Iterable<String> attendanceIds,
    String payrollPeriodId,
  ) {
    final ids = attendanceIds.toList();
    return _db.transaction(() async {
      final rows = await (_db.select(
        _db.attendances,
      )..where((a) => a.id.isIn(ids))).get();

      if (rows.length != ids.length) return false;
      if (rows.any((r) => r.payrollPeriodId != null)) return false;

      await (_db.update(_db.attendances)..where((a) => a.id.isIn(ids))).write(
        AttendancesCompanion(payrollPeriodId: Value(payrollPeriodId)),
      );
      return true;
    });
  }

  /// Applies [transition] to the row and writes the resulting status, or returns
  /// null when the row is missing, locked by payroll, or [transition] itself
  /// refuses (wrong prior state — it returns null). [transition] does its own
  /// child writes (the pause insert / close) and hands back the new status.
  Future<Attendance?> _mutate(
    String attendanceId,
    Future<AttendanceStatus?> Function(AttendanceRow row) transition,
  ) {
    return _db.transaction(() async {
      final row = await (_db.select(
        _db.attendances,
      )..where((a) => a.id.equals(attendanceId))).getSingleOrNull();
      if (row == null) return null;
      if (row.payrollPeriodId != null) return null;

      final status = await transition(row);
      if (status == null) return null;

      if (status != row.status) {
        await (_db.update(_db.attendances)
              ..where((a) => a.id.equals(attendanceId)))
            .write(AttendancesCompanion(status: Value(status)));
      }
      return attendance(attendanceId);
    });
  }

  Future<int> _pauseCount(String attendanceId) async {
    final count = _db.attendancePauses.id.count();
    final query = _db.selectOnly(_db.attendancePauses)
      ..addColumns([count])
      ..where(_db.attendancePauses.attendanceId.equals(attendanceId));
    return (await query.getSingle()).read(count) ?? 0;
  }

  // ---------------------------------------------------------------------------

  /// Every active-or-archived employee's resolved schedule, keyed by id — the
  /// stats and payroll folds look one up per row rather than a query per row.
  Future<Map<String, ({int startMinutes, int endMinutes})>> _schedulesFor(
    String storeId,
    StoreSettings settings,
  ) async {
    final employees = await (_db.select(
      _db.employees,
    )..where((e) => e.storeId.equals(storeId))).get();
    return {
      for (final row in employees)
        row.id: resolvedSchedule(
          employeeFromRow(row),
          storeOpenMinutes: settings.openMinutes,
          storeCloseMinutes: settings.closeMinutes,
        ),
    };
  }

  SimpleSelectStatement<$AttendancesTable, AttendanceRow> _todayQuery(
    String employeeId,
    DateTime? now,
  ) {
    final day = _dayOf(now ?? _clock());
    return _db.select(_db.attendances)
      ..where((a) => a.employeeId.equals(employeeId) & a.date.equals(day));
  }

  SimpleSelectStatement<$AttendancesTable, AttendanceRow> _forEmployeeQuery(
    String employeeId,
  ) =>
      _db.select(_db.attendances)
        ..where((a) => a.employeeId.equals(employeeId))
        ..orderBy([
          (a) => OrderingTerm(expression: a.date, mode: OrderingMode.desc),
          (a) =>
              OrderingTerm(expression: a.clockInAt, mode: OrderingMode.desc),
        ]);

  SimpleSelectStatement<$AttendancesTable, AttendanceRow> _logQuery(
    String storeId, {
    DateTime? from,
    DateTime? to,
    AttendanceStatus? status,
    String? employeeId,
  }) {
    final query = _db.select(_db.attendances)
      ..where((a) => a.storeId.equals(storeId))
      ..orderBy([
        (a) => OrderingTerm(expression: a.date, mode: OrderingMode.desc),
        (a) => OrderingTerm(expression: a.clockInAt, mode: OrderingMode.desc),
      ]);

    if (from != null) {
      final lower = _dayOf(from);
      query.where((a) => a.date.isBiggerOrEqualValue(lower));
    }
    if (to != null) {
      final upper = _dayOf(to);
      query.where((a) => a.date.isSmallerOrEqualValue(upper));
    }
    if (status != null) {
      query.where((a) => a.status.equalsValue(status));
    }
    if (employeeId != null) {
      query.where((a) => a.employeeId.equals(employeeId));
    }
    return query;
  }

  /// Rebuilds `Attendance` objects for a set of rows, in the same order,
  /// attaching each one's pauses. One extra query for the pauses, not one per
  /// row.
  Future<List<Attendance>> _assemble(List<AttendanceRow> rows) async {
    if (rows.isEmpty) return const <Attendance>[];

    final ids = rows.map((r) => r.id).toList();
    final pauseRows = await (_db.select(
      _db.attendancePauses,
    )..where((p) => p.attendanceId.isIn(ids))).get();

    final byAttendance = <String, List<AttendancePauseRow>>{};
    for (final pause in pauseRows) {
      (byAttendance[pause.attendanceId] ??= <AttendancePauseRow>[]).add(pause);
    }

    return [
      for (final row in rows)
        attendanceFromRows(row, byAttendance[row.id] ?? const []),
    ];
  }

  static DateTime _dayOf(DateTime v) => DateTime(v.year, v.month, v.day);
}
