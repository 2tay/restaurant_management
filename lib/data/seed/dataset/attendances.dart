import '../../../models/attendance.dart';
import 'employees.dart';
import 'reference.dart';
import 'stores.dart';

abstract final class AttendanceIds {
  static const String karimToday = 'att-karim-0';
  static const String fatimaToday = 'att-fatima-0';
  static const String amelieToday = 'att-amelie-0';
  static const String karim1 = 'att-karim-1';
  static const String amelie1 = 'att-amelie-1';
  static const String fatima1 = 'att-fatima-1';
  static const String elise1 = 'att-elise-1';
  static const String karim2 = 'att-karim-2';
  static const String noah2 = 'att-noah-2';
  static const String karim3 = 'att-karim-3';
  static const String fatima3 = 'att-fatima-3';
  static const String camille5 = 'att-camille-5';
}

/// The `PayrollPeriod` that locks Karim's two-days-ago and three-days-ago
/// rows. The period row itself is seeded in Phase 5 with this exact id — see
/// `.claude/phase_gestion_employee.md`.
const String _seededPayrollPeriodId = 'payroll-seed-karim';

/// The two paid runs on the TestCalcul store — must match
/// `PayrollPeriodIds.testCalculAyoub` / `.testCalculHakim`. Kept as literals
/// here for the same reason as [_seededPayrollPeriodId]: to avoid an import
/// cycle with `mock_payroll_periods.dart`.
const String _testCalculAyoubPeriodId = 'payroll-testcalcul-ayoub';
const String _testCalculHakimPeriodId = 'payroll-testcalcul-hakim';

/// Attendance spanning several distinct days.
///
/// Only *today*'s rows are left mid-day (`working` / `onBreak`); every earlier
/// day is finished, because a day in the past cannot still be in progress. A
/// day with no row at all means "not clocked in yet" and is simply absent —
/// Noah and Marc have no row today. Most days are a single session; the
/// several-cycles case (more than one Pointer → Fin de journée in a day) is
/// yesterday on TestCalcul — see [_testCalculMultiSessionDays].
///
/// Covers every state the walkthrough needs, without manipulation:
/// - **several pauses in one day** — Fatima today (one ended, one running)
/// - **not clocked in** — Noah and Marc today have no row
/// - **a late arrival** — Fatima yesterday (08:20 against an 08:00 start)
/// - **real overtime** — Amélie yesterday (left 18:30 against a 17:00 end)
/// - **a paid day** — Karim, two and three days ago, locked by a payroll run
final List<Attendance> mockAttendances = [
  // --- Today — in progress ------------------------------------------------
  Attendance(
    id: AttendanceIds.karimToday,
    storeId: StoreIds.sablon,
    employeeId: EmployeeIds.karim,
    date: dayOnly(0),
    status: AttendanceStatus.working,
    sessions: [AttendanceSession(clockInAt: timeOnDay(0, 7, 45))],
    paymentStatus: PaymentStatus.unpaid,
  ),
  Attendance(
    id: AttendanceIds.amelieToday,
    storeId: StoreIds.sablon,
    employeeId: EmployeeIds.amelie,
    date: dayOnly(0),
    status: AttendanceStatus.working,
    sessions: [
      AttendanceSession(
        clockInAt: timeOnDay(0, 8, 30),
        pauses: [
          AttendancePause(
            startAt: timeOnDay(0, 10, 30),
            endAt: timeOnDay(0, 10, 45),
          ),
        ],
      ),
    ],
    paymentStatus: PaymentStatus.unpaid,
  ),
  Attendance(
    id: AttendanceIds.fatimaToday,
    storeId: StoreIds.sablon,
    employeeId: EmployeeIds.fatima,
    date: dayOnly(0),
    status: AttendanceStatus.onBreak,
    sessions: [
      AttendanceSession(
        clockInAt: timeOnDay(0, 8, 0),
        pauses: [
          AttendancePause(
            startAt: timeOnDay(0, 12, 0),
            endAt: timeOnDay(0, 12, 20),
          ),
          AttendancePause(startAt: timeOnDay(0, 15, 0)),
        ],
      ),
    ],
    paymentStatus: PaymentStatus.unpaid,
  ),
  // Noah, Julien and Marc have no row today → "Non pointé".

  // --- Yesterday — finished ---------------------------------------------------
  Attendance(
    id: AttendanceIds.karim1,
    storeId: StoreIds.sablon,
    employeeId: EmployeeIds.karim,
    date: dayOnly(1),
    status: AttendanceStatus.done,
    sessions: [
      AttendanceSession(
        clockInAt: timeOnDay(1, 8, 0),
        clockOutAt: timeOnDay(1, 17, 0),
        pauses: [
          AttendancePause(
            startAt: timeOnDay(1, 12, 0),
            endAt: timeOnDay(1, 12, 30),
          ),
        ],
      ),
    ],
    paymentStatus: PaymentStatus.unpaid,
  ),
  Attendance(
    id: AttendanceIds.amelie1,
    storeId: StoreIds.sablon,
    employeeId: EmployeeIds.amelie,
    date: dayOnly(1),
    status: AttendanceStatus.done,
    sessions: [
      AttendanceSession(
        clockInAt: timeOnDay(1, 8, 0),
        clockOutAt: timeOnDay(1, 18, 30),
        pauses: [
          AttendancePause(
            startAt: timeOnDay(1, 12, 30),
            endAt: timeOnDay(1, 13, 0),
          ),
        ],
      ),
    ],
    paymentStatus: PaymentStatus.unpaid,
  ),
  Attendance(
    id: AttendanceIds.fatima1,
    storeId: StoreIds.sablon,
    employeeId: EmployeeIds.fatima,
    date: dayOnly(1),
    status: AttendanceStatus.done,
    sessions: [
      AttendanceSession(
        clockInAt: timeOnDay(1, 8, 20),
        clockOutAt: timeOnDay(1, 16, 20),
        pauses: [
          AttendancePause(
            startAt: timeOnDay(1, 12, 0),
            endAt: timeOnDay(1, 12, 15),
          ),
        ],
      ),
    ],
    paymentStatus: PaymentStatus.unpaid,
  ),
  Attendance(
    id: AttendanceIds.elise1,
    storeId: StoreIds.sablon,
    employeeId: EmployeeIds.elise,
    date: dayOnly(1),
    status: AttendanceStatus.done,
    sessions: [
      AttendanceSession(
        clockInAt: timeOnDay(1, 16, 0),
        clockOutAt: timeOnDay(1, 23, 30),
        pauses: [
          AttendancePause(
            startAt: timeOnDay(1, 19, 0),
            endAt: timeOnDay(1, 19, 20),
          ),
        ],
      ),
    ],
    paymentStatus: PaymentStatus.unpaid,
  ),

  // --- 2 & 3 days ago — Karim's days, already paid --------------------------
  Attendance(
    id: AttendanceIds.karim2,
    storeId: StoreIds.sablon,
    employeeId: EmployeeIds.karim,
    date: dayOnly(2),
    status: AttendanceStatus.done,
    sessions: [
      AttendanceSession(
        clockInAt: timeOnDay(2, 8, 0),
        clockOutAt: timeOnDay(2, 17, 0),
        pauses: [
          AttendancePause(
            startAt: timeOnDay(2, 12, 0),
            endAt: timeOnDay(2, 12, 30),
          ),
        ],
      ),
    ],
    paymentStatus: PaymentStatus.paid,
    payrollPeriodId: _seededPayrollPeriodId,
  ),
  Attendance(
    id: AttendanceIds.noah2,
    storeId: StoreIds.sablon,
    employeeId: EmployeeIds.noah,
    date: dayOnly(2),
    status: AttendanceStatus.done,
    sessions: [
      AttendanceSession(
        clockInAt: timeOnDay(2, 9, 0),
        clockOutAt: timeOnDay(2, 15, 0),
      ),
    ],
    paymentStatus: PaymentStatus.unpaid,
  ),
  Attendance(
    id: AttendanceIds.karim3,
    storeId: StoreIds.sablon,
    employeeId: EmployeeIds.karim,
    date: dayOnly(3),
    status: AttendanceStatus.done,
    sessions: [
      AttendanceSession(
        clockInAt: timeOnDay(3, 8, 0),
        clockOutAt: timeOnDay(3, 17, 15),
        pauses: [
          AttendancePause(
            startAt: timeOnDay(3, 12, 0),
            endAt: timeOnDay(3, 12, 30),
          ),
        ],
      ),
    ],
    paymentStatus: PaymentStatus.paid,
    payrollPeriodId: _seededPayrollPeriodId,
  ),
  Attendance(
    id: AttendanceIds.fatima3,
    storeId: StoreIds.sablon,
    employeeId: EmployeeIds.fatima,
    date: dayOnly(3),
    status: AttendanceStatus.done,
    sessions: [
      AttendanceSession(
        clockInAt: timeOnDay(3, 8, 0),
        clockOutAt: timeOnDay(3, 16, 0),
      ),
    ],
    paymentStatus: PaymentStatus.unpaid,
  ),

  // --- 5 days ago — an archived employee's history, kept as-is --------------
  Attendance(
    id: AttendanceIds.camille5,
    storeId: StoreIds.sablon,
    employeeId: EmployeeIds.camille,
    date: dayOnly(5),
    status: AttendanceStatus.done,
    sessions: [
      AttendanceSession(
        clockInAt: timeOnDay(5, 8, 0),
        clockOutAt: timeOnDay(5, 16, 0),
        pauses: [
          AttendancePause(
            startAt: timeOnDay(5, 12, 0),
            endAt: timeOnDay(5, 12, 30),
          ),
        ],
      ),
    ],
    paymentStatus: PaymentStatus.unpaid,
  ),

  // --- TestCalcul — a full month of finished days for the salaire check -----
  ..._testCalculAttendances(),
  // --- TestCalcul — yesterday, split into several sessions ------------------
  ..._testCalculMultiSessionDays(),
];

/// Attendance for the TestCalcul store: every working day (Mon–Sat) from
/// **1 July to 1 August 2026** for Ayoub and Hakim, all `done`.
///
/// Unlike the rest of this file the dates are calendar literals rather than
/// offsets from `mockNow` — the walkthrough is about verifying specific figures
/// over a fixed range, not about staying "current".
///
/// Days on or before **15 July** carry `paid` + a `payrollPeriodId`; the rest
/// stay `unpaid`, so the paiement screen shows "des jours payés et d'autres
/// pas encore".
///
/// - **Ayoub** (50 €/h, 1 h lunch): 08:00–22:00 (13 h worked). Every 5th
///   working day he stays to 23:30; his 2nd working day starts at 08:35.
/// - **Hakim** (70 €/h, 30 min break): 10:00–20:00 (9 h 30 worked). Every 4th
///   working day he stays to 22:00.
List<Attendance> _testCalculAttendances() {
  final rows = <Attendance>[];
  final firstDay = DateTime(2026, 7, 1);
  final lastDay = DateTime(2026, 8, 1);
  final paidThrough = DateTime(2026, 7, 15);

  var workingDay = 0;
  for (
    var day = firstDay;
    !day.isAfter(lastDay);
    day = day.add(const Duration(days: 1))
  ) {
    if (day.weekday == DateTime.sunday) continue;
    workingDay++;

    final date = DateTime(day.year, day.month, day.day);
    final tag =
        '${date.year}-${_pad(date.month)}-${_pad(date.day)}';
    final paid = !date.isAfter(paidThrough);
    DateTime at(int hour, int minute) =>
        DateTime(date.year, date.month, date.day, hour, minute);

    // --- Ayoub — fixed salary, store hours ---
    final ayoubLate = workingDay == 2;
    final ayoubOvertime = workingDay % 5 == 0;
    rows.add(
      Attendance(
        id: 'att-testcalcul-ayoub-$tag',
        storeId: StoreIds.testCalcul,
        employeeId: EmployeeIds.ayoub,
        date: date,
        status: AttendanceStatus.done,
        sessions: [
          AttendanceSession(
            clockInAt: ayoubLate ? at(8, 35) : at(8, 0),
            clockOutAt: ayoubOvertime ? at(23, 30) : at(22, 0),
            pauses: [AttendancePause(startAt: at(12, 0), endAt: at(13, 0))],
          ),
        ],
        paymentStatus: paid ? PaymentStatus.paid : PaymentStatus.unpaid,
        payrollPeriodId: paid ? _testCalculAyoubPeriodId : null,
      ),
    );

    // --- Hakim — extra, own hours ---
    final hakimOvertime = workingDay % 4 == 0;
    rows.add(
      Attendance(
        id: 'att-testcalcul-hakim-$tag',
        storeId: StoreIds.testCalcul,
        employeeId: EmployeeIds.hakim,
        date: date,
        status: AttendanceStatus.done,
        sessions: [
          AttendanceSession(
            clockInAt: at(10, 0),
            clockOutAt: hakimOvertime ? at(22, 0) : at(20, 0),
            pauses: [AttendancePause(startAt: at(13, 0), endAt: at(13, 30))],
          ),
        ],
        paymentStatus: paid ? PaymentStatus.paid : PaymentStatus.unpaid,
        payrollPeriodId: paid ? _testCalculHakimPeriodId : null,
      ),
    );
  }
  return rows;
}

/// Yesterday on TestCalcul, finished and unpaid, with the day split into
/// several Pointer → Fin de journée cycles — the case a single-session history
/// never shows:
/// - **Ayoub**, 2 sessions: 08:00–12:00, then 13:30–18:00 with a 15-min break
///   (8 h 15 worked → 412,50 € at 50 €/h).
/// - **Hakim**, 3 sessions: 07:00–10:00, 11:00–14:30 with a 20-min break, then
///   17:00–21:00 (10 h 10 worked → 711,67 € at 70 €/h).
List<Attendance> _testCalculMultiSessionDays() => [
  Attendance(
    id: 'att-testcalcul-ayoub-yesterday',
    storeId: StoreIds.testCalcul,
    employeeId: EmployeeIds.ayoub,
    date: dayOnly(1),
    status: AttendanceStatus.done,
    sessions: [
      AttendanceSession(
        clockInAt: timeOnDay(1, 8),
        clockOutAt: timeOnDay(1, 12),
      ),
      AttendanceSession(
        clockInAt: timeOnDay(1, 13, 30),
        clockOutAt: timeOnDay(1, 18),
        pauses: [
          AttendancePause(
            startAt: timeOnDay(1, 15, 30),
            endAt: timeOnDay(1, 15, 45),
          ),
        ],
      ),
    ],
    paymentStatus: PaymentStatus.unpaid,
  ),
  Attendance(
    id: 'att-testcalcul-hakim-yesterday',
    storeId: StoreIds.testCalcul,
    employeeId: EmployeeIds.hakim,
    date: dayOnly(1),
    status: AttendanceStatus.done,
    sessions: [
      AttendanceSession(
        clockInAt: timeOnDay(1, 7),
        clockOutAt: timeOnDay(1, 10),
      ),
      AttendanceSession(
        clockInAt: timeOnDay(1, 11),
        clockOutAt: timeOnDay(1, 14, 30),
        pauses: [
          AttendancePause(
            startAt: timeOnDay(1, 12, 30),
            endAt: timeOnDay(1, 12, 50),
          ),
        ],
      ),
      AttendanceSession(
        clockInAt: timeOnDay(1, 17),
        clockOutAt: timeOnDay(1, 21),
      ),
    ],
    paymentStatus: PaymentStatus.unpaid,
  ),
];

String _pad(int value) => value.toString().padLeft(2, '0');
