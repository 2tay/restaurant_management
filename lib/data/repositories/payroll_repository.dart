import 'package:drift/drift.dart';

import '../../core/utils/attendance_status.dart';
import '../../core/utils/payroll_math.dart';
import '../../models/attendance.dart';
import '../../models/employee.dart';
import '../../models/payroll_period.dart';
import '../database/app_database.dart';
import '../mappers/mappers.dart';
import 'attendance_repository.dart';
import 'employee_repository.dart';
import 'new_id.dart';
import 'store_repository.dart';

/// Thrown inside [PayrollRepository.pay]'s transaction to roll the whole thing
/// back — a day was locked to another run between the read and the write.
class _PayrollAborted implements Exception {
  const _PayrollAborted();
}

/// What [PayrollRepository.preview] hands the screen — figured, never stored.
class PayrollPreview {
  const PayrollPreview({
    required this.days,
    required this.workedHours,
    required this.overtimeHours,
    required this.amount,
    required this.appliedRate,
  });

  /// The unpaid, finished days this run would cover, most recent first.
  final List<Attendance> days;
  final double workedHours;
  final double overtimeHours;
  final double amount;
  final double appliedRate;

  bool get isEmpty => days.isEmpty;
}

/// One page of the store's payroll history.
typedef PayrollPage = ({
  List<PayrollPeriod> rows,
  int totalCount,
  int page,
  int pageCount,
});

/// The day-by-day paiement view: the finished days (paginated), the four KPI
/// figures above them, the pager totals, and the two lookups the table needs
/// per row so it does not query per row — the employee behind each day and,
/// for a paid day, when its period was settled.
typedef PayrollDays = ({
  List<Attendance> rows,
  Map<String, Employee> employeesById,
  Map<String, DateTime> paidAtByPeriod,
  int paidDays,
  int unpaidDays,
  Duration worked,
  Duration overtime,
  int totalCount,
  int page,
  int pageCount,
});

/// The paie.
///
/// **The only file that writes a `PayrollPeriod`, and the only path that ever
/// locks an `Attendance` to a run** — through
/// [AttendanceRepository.lockForPayroll], called inside [pay]'s transaction so
/// the attendance rows still have exactly one writer. Same permanence as a
/// confirmed goods receipt: a paid period is never edited or deleted,
/// [PayrollPeriod.appliedRate] freezes the rate at pay time, and the days it
/// covers can no longer be touched.
///
/// [days] and [preview] fold `workedDuration` / `overtimeBy` with the unchanged
/// `attendance_status.dart` / `payroll_math.dart` — SQL for the fetch, Dart for
/// the arithmetic, so that arithmetic stays one definition.
class PayrollRepository {
  const PayrollRepository(this._db);

  final AppDatabase _db;

  Future<PayrollPeriod?> period(String id) =>
      (_db.select(_db.payrollPeriods)..where((p) => p.id.equals(id)))
          .getSingleOrNull()
          .then((row) => row == null ? null : payrollPeriodFromRow(row));

  /// One employee's payroll runs, **most recent `paidAt` first**, `id` as the
  /// tiebreak (several runs can be paid in one sitting).
  Stream<List<PayrollPeriod>> watchForEmployee(String employeeId) =>
      _forEmployeeQuery(employeeId).watch().map(_toPeriods);

  Future<List<PayrollPeriod>> forEmployee(String employeeId) =>
      _forEmployeeQuery(employeeId).get().then(_toPeriods);

  /// The store's payroll history for the Historique de paiement page — an
  /// employee-name search and a rolling [withinDays] window, most-recent first,
  /// sliced into a page.
  ///
  /// [now] is injected so the rolling window is testable.
  Future<PayrollPage> page(
    String storeId, {
    int? withinDays,
    String? employeeQuery,
    DateTime? now,
    int page = 0,
    int pageSize = 25,
  }) async {
    final all = await _pageMatches(
      storeId,
      withinDays: withinDays,
      employeeQuery: employeeQuery,
      now: now,
    );

    final pageCount = all.isEmpty ? 1 : (all.length + pageSize - 1) ~/ pageSize;
    final safePage = page.clamp(0, pageCount - 1);
    final start = (safePage * pageSize).clamp(0, all.length);
    final end = (start + pageSize).clamp(0, all.length);

    return (
      rows: all.sublist(start, end),
      totalCount: all.length,
      page: safePage,
      pageCount: pageCount,
    );
  }

  /// Finished (`done`) days for the Historique de paiement screen.
  ///
  /// [employeeId] null means every **active** employee of the store; a value
  /// scopes to one person (retired employees still resolve). [from] / [to] bound
  /// the range (inclusive calendar days), null meaning unbounded on that side;
  /// the lower bound is never earlier than each employee's own hire date.
  /// [status] filters the returned [rows] and the pager only — the paid /
  /// unpaid counts and the hour totals are always over every finished day in the
  /// range, so both KPI numbers stay visible whatever the table is filtered to.
  ///
  /// SQL fetches the `done` rows and their pauses; Dart resolves each schedule
  /// and folds the durations with the unchanged `attendance_status.dart`. This
  /// is the single hardest read in the phase.
  Future<PayrollDays> days(
    String storeId, {
    String? employeeId,
    DateTime? from,
    DateTime? to,
    PaymentStatus? status,
    int page = 0,
    int pageSize = 25,
  }) async {
    final settings = await StoreRepository(_db).settings(storeId);

    // The employees in scope, and their schedules.
    final employeeRows = await _scopedEmployees(storeId, employeeId);
    final schedules = {
      for (final e in employeeRows)
        e.id: resolvedSchedule(
          e,
          storeOpenMinutes: settings.openMinutes,
          storeCloseMinutes: settings.closeMinutes,
        ),
    };
    final hireFloor = {for (final e in employeeRows) e.id: _dayOf(e.hireDate)};
    final scopedIds = employeeRows.map((e) => e.id).toSet();

    final upper = to == null ? null : _dayOf(to);
    final requestedLower = from == null ? null : _dayOf(from);

    final rows =
        await (_db.select(_db.attendances)..where(
              (a) =>
                  a.storeId.equals(storeId) &
                  a.status.equalsValue(AttendanceStatus.done),
            ))
            .get();

    final matched = <Attendance>[];
    var worked = Duration.zero;
    var overtime = Duration.zero;

    final entries = await _assemble(
      rows.where((r) => scopedIds.contains(r.employeeId)).toList(),
    );

    for (final entry in entries) {
      final hire = hireFloor[entry.employeeId]!;
      var lower = requestedLower;
      if (lower == null || lower.isBefore(hire)) lower = hire;

      if (entry.date.isBefore(lower)) continue;
      if (upper != null && entry.date.isAfter(upper)) continue;

      matched.add(entry);
      worked += workedDuration(entry) ?? Duration.zero;
      final endMinutes =
          entry.scheduledEndMinutes ??
          schedules[entry.employeeId]?.endMinutes ??
          settings.closeMinutes;
      overtime += overtimeBy(entry, endMinutes) ?? Duration.zero;
    }

    matched.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return a.employeeId.compareTo(b.employeeId);
    });

    final paid = matched
        .where((a) => a.paymentStatus == PaymentStatus.paid)
        .length;
    final unpaid = matched.length - paid;

    final filtered = status == null
        ? matched
        : matched.where((a) => a.paymentStatus == status).toList();

    final pageCount = filtered.isEmpty
        ? 1
        : (filtered.length + pageSize - 1) ~/ pageSize;
    final safePage = page.clamp(0, pageCount - 1);
    final start = (safePage * pageSize).clamp(0, filtered.length);
    final end = (start + pageSize).clamp(0, filtered.length);
    final pageRows = filtered.sublist(start, end);

    // The paid-at date for each period a shown day points at — one query, not
    // one per row.
    final periodIds = pageRows
        .map((a) => a.payrollPeriodId)
        .whereType<String>()
        .toSet();
    final periods = periodIds.isEmpty
        ? const <PayrollPeriod>[]
        : _toPeriods(
            await (_db.select(_db.payrollPeriods)
                  ..where((p) => p.id.isIn(periodIds.toList())))
                .get(),
          );

    return (
      rows: pageRows,
      employeesById: {for (final e in employeeRows) e.id: e},
      paidAtByPeriod: {
        for (final p in periods)
          if (p.paidAt != null) p.id: p.paidAt!,
      },
      paidDays: paid,
      unpaidDays: unpaid,
      worked: worked,
      overtime: overtime,
      totalCount: filtered.length,
      page: safePage,
      pageCount: pageCount,
    );
  }

  /// How many finished (`done`) days at [storeId] are not yet locked to a
  /// payroll run. The store-settings screen warns with this before a change
  /// that would retroactively re-figure those days — see `evaluationContext`.
  Future<int> unpaidFinishedDayCount(String storeId) async {
    final count = _db.attendances.id.count();
    final query = _db.selectOnly(_db.attendances)
      ..addColumns([count])
      ..where(
        _db.attendances.storeId.equals(storeId) &
            _db.attendances.status.equalsValue(AttendanceStatus.done) &
            _db.attendances.payrollPeriodId.isNull(),
      );
    return (await query.getSingle()).read(count) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Everything owed to [employeeId] at [storeId] right now for the [from]–[to]
  /// range: their unpaid, finished days and what those come to. Persists
  /// nothing — the "before you confirm" view.
  ///
  /// A day outside the range stays owed until the range is widened; a day
  /// before the employee's hire date is never included, whatever [from] says.
  Future<PayrollPreview> preview(
    String employeeId,
    String storeId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final employee = await EmployeeRepository(_db).employee(employeeId);
    final settings = await StoreRepository(_db).settings(storeId);
    final days = await _payableDays(
      employeeId,
      storeId,
      employee?.hireDate,
      from: from,
      to: to,
    );

    if (employee == null || days.isEmpty) {
      return PayrollPreview(
        days: days,
        workedHours: 0,
        overtimeHours: 0,
        amount: 0,
        appliedRate: employee?.pay ?? 0,
      );
    }

    final totals = periodTotals(days, employee, settings);
    return PayrollPreview(
      days: days,
      workedHours: totals.workedHours,
      overtimeHours: totals.overtimeHours,
      amount: periodAmount(days, employee, settings),
      appliedRate: employee.pay,
    );
  }

  /// Pays everything [preview] would show for the same [from] / [to] range —
  /// creates the [PayrollPeriod] and locks its days, **all in one transaction**.
  ///
  /// Returns null when there is nothing to pay, the employee is missing, or a
  /// day slipped into `paid` between the preview and here: in that last case the
  /// period insert is rolled back with it, so `pay` never leaves a run whose
  /// days are not all locked to it.
  Future<PayrollPeriod?> pay(
    String employeeId,
    String storeId, {
    DateTime? from,
    DateTime? to,
    required String paidByEmployeeId,
    DateTime? now,
  }) async {
    final employee = await EmployeeRepository(_db).employee(employeeId);
    if (employee == null) return null;
    final settings = await StoreRepository(_db).settings(storeId);
    final at = now ?? DateTime.now();

    try {
      return await _db.transaction(() async {
        final days = await _payableDays(
          employeeId,
          storeId,
          employee.hireDate,
          from: from,
          to: to,
        );
        if (days.isEmpty) return null;

        final totals = periodTotals(days, employee, settings);
        final dates = days.map((d) => d.date).toList()..sort();
        final period = PayrollPeriod(
          id: newId(),
          storeId: storeId,
          employeeId: employeeId,
          startDate: dates.first,
          endDate: dates.last,
          workedDays: totals.days,
          totalWorkedHours: totals.workedHours,
          totalOvertimeHours: totals.overtimeHours,
          appliedRate: employee.pay,
          computedAmount: periodAmount(days, employee, settings),
          status: PayrollStatus.paid,
          paidByEmployeeId: paidByEmployeeId,
          paidAt: at,
          createdAt: at,
        );

        // The period row first — `attendances.payrollPeriodId` is a RESTRICT FK
        // into it, so the lock cannot stamp an id that does not yet exist.
        await _db
            .into(_db.payrollPeriods)
            .insert(payrollPeriodToRow(period));

        final locked = await AttendanceRepository(_db).lockForPayroll(
          days.map((d) => d.id),
          period.id,
        );
        if (!locked) throw const _PayrollAborted();

        return period;
      });
    } on _PayrollAborted {
      return null;
    }
  }

  /// Unpaid, finished days for this employee at this store — most recent first.
  /// A day that is not `done` is not payable yet; a day already stamped with a
  /// `payrollPeriodId` is gone. [from] / [to] bound the range (inclusive
  /// calendar days); the lower bound is never earlier than [hireDate].
  Future<List<Attendance>> _payableDays(
    String employeeId,
    String storeId,
    DateTime? hireDate, {
    DateTime? from,
    DateTime? to,
  }) async {
    final rows =
        await (_db.select(_db.attendances)..where(
              (a) =>
                  a.employeeId.equals(employeeId) &
                  a.storeId.equals(storeId) &
                  a.status.equalsValue(AttendanceStatus.done) &
                  a.payrollPeriodId.isNull(),
            ))
            .get();

    var lower = from == null ? null : _dayOf(from);
    if (hireDate != null) {
      final hire = _dayOf(hireDate);
      if (lower == null || lower.isBefore(hire)) lower = hire;
    }
    final upper = to == null ? null : _dayOf(to);

    final entries = await _assemble(rows);
    final days = [
      for (final entry in entries)
        if ((lower == null || !entry.date.isBefore(lower)) &&
            (upper == null || !entry.date.isAfter(upper)))
          entry,
    ]..sort((a, b) => b.date.compareTo(a.date));
    return days;
  }

  // ---------------------------------------------------------------------------

  Future<List<Employee>> _scopedEmployees(
    String storeId,
    String? employeeId,
  ) async {
    final query = _db.select(_db.employees)
      ..where((e) => e.storeId.equals(storeId));
    if (employeeId != null) {
      query.where((e) => e.id.equals(employeeId));
    } else {
      query.where((e) => e.archivedAt.isNull());
    }
    return query.get().then((rows) => rows.map(employeeFromRow).toList());
  }

  Future<List<PayrollPeriod>> _pageMatches(
    String storeId, {
    int? withinDays,
    String? employeeQuery,
    DateTime? now,
  }) async {
    final cutoff = withinDays == null
        ? null
        : (now ?? DateTime.now()).subtract(Duration(days: withinDays));
    final needle = (employeeQuery ?? '').trim().toLowerCase();

    final rows = await (_db.select(_db.payrollPeriods)
          ..where((p) => p.storeId.equals(storeId))
          ..orderBy([
            (p) => OrderingTerm(
              expression: coalesce([p.paidAt, p.createdAt]),
              mode: OrderingMode.desc,
            ),
            (p) => OrderingTerm(expression: p.id, mode: OrderingMode.desc),
          ]))
        .get();

    final names = needle.isEmpty
        ? const <String, String>{}
        : {
            for (final e in await (_db.select(
              _db.employees,
            )..where((e) => e.storeId.equals(storeId))).get())
              e.id: '${e.firstName} ${e.lastName}'.toLowerCase(),
          };

    return [
      for (final row in rows)
        if (_pagePasses(row, cutoff, needle, names)) payrollPeriodFromRow(row),
    ];
  }

  bool _pagePasses(
    PayrollPeriodRow row,
    DateTime? cutoff,
    String needle,
    Map<String, String> names,
  ) {
    if (cutoff != null && (row.paidAt ?? row.createdAt).isBefore(cutoff)) {
      return false;
    }
    if (needle.isNotEmpty && !(names[row.employeeId] ?? '').contains(needle)) {
      return false;
    }
    return true;
  }

  SimpleSelectStatement<$PayrollPeriodsTable, PayrollPeriodRow>
  _forEmployeeQuery(String employeeId) =>
      _db.select(_db.payrollPeriods)
        ..where((p) => p.employeeId.equals(employeeId))
        ..orderBy([
          (p) => OrderingTerm(
            expression: coalesce([p.paidAt, p.createdAt]),
            mode: OrderingMode.desc,
          ),
          (p) => OrderingTerm(expression: p.id, mode: OrderingMode.desc),
        ]);

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

  List<PayrollPeriod> _toPeriods(List<PayrollPeriodRow> rows) =>
      rows.map(payrollPeriodFromRow).toList();

  static DateTime _dayOf(DateTime v) => DateTime(v.year, v.month, v.day);
}
