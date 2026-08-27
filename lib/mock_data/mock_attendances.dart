import '../models/attendance.dart';
import 'mock_employees.dart';
import 'mock_reference.dart';
import 'mock_stores.dart';

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

/// Attendance spanning several distinct days.
///
/// Only *today*'s rows are left mid-day (`working` / `onBreak`); every earlier
/// day is finished, because a day in the past cannot still be in progress. A
/// day with no row at all means "not clocked in yet" and is simply absent —
/// Noah and Marc have no row today.
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
    clockInAt: timeOnDay(0, 7, 45),
    pauses: const [],
    paymentStatus: PaymentStatus.unpaid,
  ),
  Attendance(
    id: AttendanceIds.amelieToday,
    storeId: StoreIds.sablon,
    employeeId: EmployeeIds.amelie,
    date: dayOnly(0),
    status: AttendanceStatus.working,
    clockInAt: timeOnDay(0, 8, 30),
    pauses: [
      AttendancePause(
        startAt: timeOnDay(0, 10, 30),
        endAt: timeOnDay(0, 10, 45),
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
    clockInAt: timeOnDay(0, 8, 0),
    pauses: [
      AttendancePause(
        startAt: timeOnDay(0, 12, 0),
        endAt: timeOnDay(0, 12, 20),
      ),
      AttendancePause(startAt: timeOnDay(0, 15, 0)),
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
    clockInAt: timeOnDay(1, 8, 0),
    clockOutAt: timeOnDay(1, 17, 0),
    pauses: [
      AttendancePause(startAt: timeOnDay(1, 12, 0), endAt: timeOnDay(1, 12, 30)),
    ],
    paymentStatus: PaymentStatus.unpaid,
  ),
  Attendance(
    id: AttendanceIds.amelie1,
    storeId: StoreIds.sablon,
    employeeId: EmployeeIds.amelie,
    date: dayOnly(1),
    status: AttendanceStatus.done,
    clockInAt: timeOnDay(1, 8, 0),
    clockOutAt: timeOnDay(1, 18, 30),
    pauses: [
      AttendancePause(startAt: timeOnDay(1, 12, 30), endAt: timeOnDay(1, 13, 0)),
    ],
    paymentStatus: PaymentStatus.unpaid,
  ),
  Attendance(
    id: AttendanceIds.fatima1,
    storeId: StoreIds.sablon,
    employeeId: EmployeeIds.fatima,
    date: dayOnly(1),
    status: AttendanceStatus.done,
    clockInAt: timeOnDay(1, 8, 20),
    clockOutAt: timeOnDay(1, 16, 20),
    pauses: [
      AttendancePause(startAt: timeOnDay(1, 12, 0), endAt: timeOnDay(1, 12, 15)),
    ],
    paymentStatus: PaymentStatus.unpaid,
  ),
  Attendance(
    id: AttendanceIds.elise1,
    storeId: StoreIds.sablon,
    employeeId: EmployeeIds.elise,
    date: dayOnly(1),
    status: AttendanceStatus.done,
    clockInAt: timeOnDay(1, 16, 0),
    clockOutAt: timeOnDay(1, 23, 30),
    pauses: [
      AttendancePause(startAt: timeOnDay(1, 19, 0), endAt: timeOnDay(1, 19, 20)),
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
    clockInAt: timeOnDay(2, 8, 0),
    clockOutAt: timeOnDay(2, 17, 0),
    pauses: [
      AttendancePause(startAt: timeOnDay(2, 12, 0), endAt: timeOnDay(2, 12, 30)),
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
    clockInAt: timeOnDay(2, 9, 0),
    clockOutAt: timeOnDay(2, 15, 0),
    pauses: const [],
    paymentStatus: PaymentStatus.unpaid,
  ),
  Attendance(
    id: AttendanceIds.karim3,
    storeId: StoreIds.sablon,
    employeeId: EmployeeIds.karim,
    date: dayOnly(3),
    status: AttendanceStatus.done,
    clockInAt: timeOnDay(3, 8, 0),
    clockOutAt: timeOnDay(3, 17, 15),
    pauses: [
      AttendancePause(startAt: timeOnDay(3, 12, 0), endAt: timeOnDay(3, 12, 30)),
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
    clockInAt: timeOnDay(3, 8, 0),
    clockOutAt: timeOnDay(3, 16, 0),
    pauses: const [],
    paymentStatus: PaymentStatus.unpaid,
  ),

  // --- 5 days ago — an archived employee's history, kept as-is --------------
  Attendance(
    id: AttendanceIds.camille5,
    storeId: StoreIds.sablon,
    employeeId: EmployeeIds.camille,
    date: dayOnly(5),
    status: AttendanceStatus.done,
    clockInAt: timeOnDay(5, 8, 0),
    clockOutAt: timeOnDay(5, 16, 0),
    pauses: [
      AttendancePause(startAt: timeOnDay(5, 12, 0), endAt: timeOnDay(5, 12, 30)),
    ],
    paymentStatus: PaymentStatus.unpaid,
  ),
];
