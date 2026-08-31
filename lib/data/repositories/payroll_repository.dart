import 'package:drift/drift.dart';

import '../../core/utils/attendance_status.dart';
import '../../models/attendance.dart';
import '../../models/employee.dart';
import '../../models/payroll_period.dart';
import '../database/app_database.dart';
import '../mappers/mappers.dart';
import 'store_repository.dart';

/// One page of the store's payroll history.
typedef PayrollPage = ({
  List<PayrollPeriod> rows,
  int totalCount,
  int page,
  int pageCount,
});

/// The day-by-day paiement view: the finished days (paginated), the four KPI
/// figures above them, and the pager totals.
typedef PayrollDays = ({
  List<Attendance> rows,
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
/// Reads only in this stage: the runs list, one run by id, and [days] — the
/// day-by-day view that is *not* pure SQL (it folds `workedDuration` and
/// `overtimeBy` with the unchanged `attendance_status.dart`). `preview` and the
/// transactional `pay` land in stage 6.
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
      overtime +=
          overtimeBy(entry, schedules[entry.employeeId]!.endMinutes) ??
          Duration.zero;
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

    return (
      rows: filtered.sublist(start, end),
      paidDays: paid,
      unpaidDays: unpaid,
      worked: worked,
      overtime: overtime,
      totalCount: filtered.length,
      page: safePage,
      pageCount: pageCount,
    );
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
