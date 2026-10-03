import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

import '../../core/utils/attendance_status.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/payroll_math.dart';
import '../../models/attendance.dart';
import '../../models/employee.dart';
import '../../models/payroll_period.dart';
import '../database/app_database.dart';
import '../mappers/mappers.dart';
import 'attendance_assembler.dart';
import 'attendance_repository.dart';
import 'employee_repository.dart';
import 'new_id.dart';

/// Thrown inside [PayrollRepository.pay]'s transaction to roll the whole thing
/// back — a day was locked to another run between the read and the write.
class _PayrollAborted implements Exception {
  const _PayrollAborted();
}

/// Thrown by [PayrollRepository.pay] when the days payable no longer match
/// the [PayrollPreview] the payer confirmed — a day finished, corrected or
/// paid in between, or the rate changed. Nothing is written; the screen says
/// so and the payer looks at the new figure before confirming again.
class PayrollPreviewOutdated implements Exception {
  const PayrollPreviewOutdated();
}

/// What [PayrollRepository.preview] hands the screen — figured, never stored.
class PayrollPreview {
  const PayrollPreview({
    required this.days,
    required this.workedHours,
    required this.amount,
    required this.appliedRate,
  });

  /// The unpaid, finished days this run would cover, most recent first.
  final List<Attendance> days;
  final double workedHours;
  final double amount;
  final double appliedRate;

  bool get isEmpty => days.isEmpty;
}

/// The day-by-day paiement view: the finished days (paginated), the four KPI
/// figures above them, the pager totals, and the two lookups the table needs
/// per row so it does not query per row — the employee behind each day and,
/// for a paid day, the period that settled it (when, and at which frozen
/// rate).
typedef PayrollDays = ({
  List<Attendance> rows,
  Map<String, Employee> employeesById,
  Map<String, PayrollPeriod> periodsById,
  int paidDays,
  int unpaidDays,
  Duration worked,
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
/// [days] and [preview] fold `workedDuration` with the unchanged
/// `attendance_status.dart` / `payroll_math.dart` — SQL for the fetch, Dart for
/// the arithmetic, so that arithmetic stays one definition.
class PayrollRepository {
  const PayrollRepository(this._db);

  final AppDatabase _db;

  Future<PayrollPeriod?> period(String id) =>
      (_db.select(_db.payrollPeriods)
            ..where((p) => p.id.equals(id) & p.deletedAt.isNull()))
          .getSingleOrNull()
          .then((row) => row == null ? null : payrollPeriodFromRow(row));

  /// Finished (`done`) days for the Historique de paiement screen.
  ///
  /// [employeeId] null means every employee [watchPayableEmployees] lists —
  /// the active ones, and a retired one still owed finished days; a value
  /// scopes to one person (retired employees still resolve). [from] / [to] bound
  /// the range (inclusive calendar days), null meaning unbounded on that side;
  /// the lower bound is never earlier than each employee's own hire date.
  /// [status] filters the returned [rows] and the pager only — the paid /
  /// unpaid counts and the hour totals are always over every finished day in the
  /// range, so both KPI numbers stay visible whatever the table is filtered to.
  ///
  /// SQL fetches the `done` rows and their sessions; Dart folds the durations
  /// with the unchanged `attendance_status.dart`.
  Future<PayrollDays> days(
    String storeId, {
    String? employeeId,
    DateTime? from,
    DateTime? to,
    PaymentStatus? status,
    int page = 0,
    int pageSize = 25,
  }) async {
    // The employees in scope.
    final employeeRows = await _scopedEmployees(storeId, employeeId);
    final hireFloor = {for (final e in employeeRows) e.id: dayOf(e.hireDate)};
    final scopedIds = employeeRows.map((e) => e.id).toSet();

    final upper = to == null ? null : dayOf(to);
    final requestedLower = from == null ? null : dayOf(from);

    final rows =
        await (_db.select(_db.attendances)..where(
              (a) =>
                  a.storeId.equals(storeId) &
                  a.deletedAt.isNull() &
                  a.status.equalsValue(AttendanceStatus.done),
            ))
            .get();

    final matched = <Attendance>[];
    var worked = Duration.zero;

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

    // The period each shown paid day points at — one query, not one per row.
    final periodIds = pageRows
        .map((a) => a.payrollPeriodId)
        .whereType<String>()
        .toSet();
    final periods = periodIds.isEmpty
        ? const <PayrollPeriod>[]
        : _toPeriods(
            await (_db.select(_db.payrollPeriods)
                  ..where(
                    (p) => p.id.isIn(periodIds.toList()) & p.deletedAt.isNull(),
                  ))
                .get(),
          );

    return (
      rows: pageRows,
      employeesById: {for (final e in employeeRows) e.id: e},
      periodsById: {for (final p in periods) p.id: p},
      paidDays: paid,
      unpaidDays: unpaid,
      worked: worked,
      totalCount: filtered.length,
      page: safePage,
      pageCount: pageCount,
    );
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
        amount: 0,
        appliedRate: employee?.pay ?? 0,
      );
    }

    final totals = periodTotals(days);
    return PayrollPreview(
      days: days,
      workedHours: totals.workedHours,
      amount: periodAmount(days, employee),
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
  ///
  /// With [expected] — the preview the payer confirmed — it pays exactly that
  /// or nothing: when the payable days or the amount differ (a day finished,
  /// corrected or paid in between, a rate changed), it throws
  /// [PayrollPreviewOutdated] and writes nothing. Checked inside the
  /// transaction, so nothing can slip in between the check and the write.
  Future<PayrollPeriod?> pay(
    String employeeId,
    String storeId, {
    DateTime? from,
    DateTime? to,
    required String paidByEmployeeId,
    PayrollPreview? expected,
    DateTime? now,
  }) async {
    final employee = await EmployeeRepository(_db).employee(employeeId);
    if (employee == null) return null;
    final at = now ?? clock.now();

    try {
      return await _db.transaction(() async {
        final days = await _payableDays(
          employeeId,
          storeId,
          employee.hireDate,
          from: from,
          to: to,
        );
        final amount = periodAmount(days, employee);
        if (expected != null && !_sameRun(expected, days, amount)) {
          throw const PayrollPreviewOutdated();
        }
        if (days.isEmpty) return null;

        final totals = periodTotals(days);
        final dates = days.map((d) => d.date).toList()..sort();
        final period = PayrollPeriod(
          id: newId(),
          storeId: storeId,
          employeeId: employeeId,
          startDate: dates.first,
          endDate: dates.last,
          workedDays: totals.days,
          totalWorkedHours: totals.workedHours,
          appliedRate: employee.pay,
          computedAmount: amount,
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

  /// Whether [days] at [amount] is the run [expected] showed: the same days,
  /// and the same amount to the cent.
  static bool _sameRun(
    PayrollPreview expected,
    List<Attendance> days,
    double amount,
  ) {
    final shown = expected.days.map((d) => d.id).toSet();
    final now = days.map((d) => d.id).toSet();
    return shown.length == now.length &&
        shown.containsAll(now) &&
        (expected.amount - amount).abs() < 0.005;
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
                  a.deletedAt.isNull() &
                  a.status.equalsValue(AttendanceStatus.done) &
                  a.payrollPeriodId.isNull(),
            ))
            .get();

    var lower = from == null ? null : dayOf(from);
    if (hireDate != null) {
      final hire = dayOf(hireDate);
      if (lower == null || lower.isBefore(hire)) lower = hire;
    }
    final upper = to == null ? null : dayOf(to);

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
    if (employeeId == null) {
      return _payableEmployeesQuery(
        storeId,
      ).get().then((rows) => rows.map(employeeFromRow).toList());
    }
    final query = _db.select(_db.employees)
      ..where(
        (e) =>
            e.storeId.equals(storeId) &
            e.id.equals(employeeId) &
            e.deletedAt.isNull(),
      );
    return query.get().then((rows) => rows.map(employeeFromRow).toList());
  }

  /// The people the payroll screen lists: every active employee of the
  /// store, and a retired one who still has finished days to pay — they are
  /// owed, so they stay payable until they are paid, then drop off.
  Stream<List<Employee>> watchPayableEmployees(String storeId) =>
      _payableEmployeesQuery(
        storeId,
      ).watch().map((rows) => rows.map(employeeFromRow).toList());

  SimpleSelectStatement<$EmployeesTable, EmployeeRow> _payableEmployeesQuery(
    String storeId,
  ) {
    final a = _db.attendances;
    final owed = existsQuery(
      _db.selectOnly(a)
        ..addColumns([a.id])
        ..where(
          a.employeeId.equalsExp(_db.employees.id) &
              a.deletedAt.isNull() &
              a.status.equalsValue(AttendanceStatus.done) &
              a.payrollPeriodId.isNull(),
        ),
    );
    return _db.select(_db.employees)
      ..where(
        (e) =>
            e.storeId.equals(storeId) &
            e.deletedAt.isNull() &
            (e.archivedAt.isNull() | owed),
      );
  }

  /// See [assembleAttendances].
  Future<List<Attendance>> _assemble(List<AttendanceRow> rows) =>
      assembleAttendances(_db, rows);

  List<PayrollPeriod> _toPeriods(List<PayrollPeriodRow> rows) =>
      rows.map(payrollPeriodFromRow).toList();

}
