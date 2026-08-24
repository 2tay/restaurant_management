import '../models/time_entry.dart';
import 'mock_employees.dart';
import 'mock_reference.dart';
import 'mock_stores.dart';

abstract final class TimeEntryIds {
  static const String karimToday = 'te-karim-0';
  static const String eliseToday = 'te-elise-0';
  static const String karimYesterday = 'te-karim-1';
  static const String eliseYesterday = 'te-elise-1';
  static const String fatimaYesterday = 'te-fatima-1';
  static const String noah2 = 'te-noah-2';
  static const String julien2 = 'te-julien-2';
  static const String karim3 = 'te-karim-3';
  static const String fatima3 = 'te-fatima-3';
  static const String elise4 = 'te-elise-4';
  static const String camille5 = 'te-camille-5';
}

/// Attendance spanning several distinct days, not just today, so Stage 3's
/// date-range filter has something to filter.
///
/// Only *today*'s entries are left mid-day (`onShift` / `onBreak`) — every
/// earlier day is finished, because a day in the past cannot still be in
/// progress. A day with no entry at all means "not clocked in yet" and is
/// simply absent, per the `TimeEntry` model doc, which is why some employees
/// (Noah and Julien, today) have no row here.
///
/// Covers both demo-critical states the walkthrough needs: Élise's break
/// yesterday ran to 50 minutes, past `PointageRules.maxBreakDuration`
/// (`isLate: true`), and Karim's shift the day before worked 8h30 against the
/// 8h standard day, so `overtime()` has something real to show.
final List<TimeEntry> mockTimeEntries = [
  // --- Today — in progress -----------------------------------------------
  TimeEntry(
    id: TimeEntryIds.karimToday,
    storeId: StoreIds.sablon,
    employeeId: EmployeeIds.karim,
    date: dayOnly(0),
    status: TimeEntryStatus.onShift,
    clockInAt: timeOnDay(0, 7, 45),
    isLate: false,
  ),
  TimeEntry(
    id: TimeEntryIds.eliseToday,
    storeId: StoreIds.sablon,
    employeeId: EmployeeIds.elise,
    date: dayOnly(0),
    status: TimeEntryStatus.onBreak,
    clockInAt: timeOnDay(0, 9, 0),
    breakStartAt: timeOnDay(0, 13, 15),
    isLate: false,
  ),

  // --- Yesterday ------------------------------------------------------------
  TimeEntry(
    id: TimeEntryIds.karimYesterday,
    storeId: StoreIds.sablon,
    employeeId: EmployeeIds.karim,
    date: dayOnly(1),
    status: TimeEntryStatus.clockedOut,
    clockInAt: timeOnDay(1, 8, 0),
    breakStartAt: timeOnDay(1, 12, 0),
    breakEndAt: timeOnDay(1, 12, 30),
    clockOutAt: timeOnDay(1, 17, 0),
    isLate: false,
  ),
  TimeEntry(
    id: TimeEntryIds.eliseYesterday,
    storeId: StoreIds.sablon,
    employeeId: EmployeeIds.elise,
    date: dayOnly(1),
    status: TimeEntryStatus.clockedOut,
    clockInAt: timeOnDay(1, 9, 0),
    breakStartAt: timeOnDay(1, 13, 0),
    breakEndAt: timeOnDay(1, 13, 50),
    clockOutAt: timeOnDay(1, 17, 0),
    isLate: true,
  ),
  TimeEntry(
    id: TimeEntryIds.fatimaYesterday,
    storeId: StoreIds.sablon,
    employeeId: EmployeeIds.fatima,
    date: dayOnly(1),
    status: TimeEntryStatus.clockedOut,
    clockInAt: timeOnDay(1, 8, 0),
    breakStartAt: timeOnDay(1, 12, 0),
    breakEndAt: timeOnDay(1, 12, 25),
    clockOutAt: timeOnDay(1, 16, 25),
    isLate: false,
  ),

  // --- 2 days ago -------------------------------------------------------------
  TimeEntry(
    id: TimeEntryIds.noah2,
    storeId: StoreIds.sablon,
    employeeId: EmployeeIds.noah,
    date: dayOnly(2),
    status: TimeEntryStatus.clockedOut,
    clockInAt: timeOnDay(2, 10, 0),
    breakStartAt: timeOnDay(2, 13, 0),
    breakEndAt: timeOnDay(2, 13, 20),
    clockOutAt: timeOnDay(2, 15, 0),
    isLate: false,
  ),
  TimeEntry(
    id: TimeEntryIds.julien2,
    storeId: StoreIds.sablon,
    employeeId: EmployeeIds.julien,
    date: dayOnly(2),
    status: TimeEntryStatus.clockedOut,
    clockInAt: timeOnDay(2, 9, 0),
    breakStartAt: timeOnDay(2, 12, 30),
    breakEndAt: timeOnDay(2, 13, 0),
    clockOutAt: timeOnDay(2, 17, 0),
    isLate: false,
  ),

  // --- 3 days ago — the overtime example --------------------------------------
  TimeEntry(
    id: TimeEntryIds.karim3,
    storeId: StoreIds.sablon,
    employeeId: EmployeeIds.karim,
    date: dayOnly(3),
    status: TimeEntryStatus.clockedOut,
    clockInAt: timeOnDay(3, 8, 0),
    breakStartAt: timeOnDay(3, 12, 0),
    breakEndAt: timeOnDay(3, 12, 30),
    clockOutAt: timeOnDay(3, 17, 0),
    isLate: false,
  ),
  TimeEntry(
    id: TimeEntryIds.fatima3,
    storeId: StoreIds.sablon,
    employeeId: EmployeeIds.fatima,
    date: dayOnly(3),
    status: TimeEntryStatus.clockedOut,
    clockInAt: timeOnDay(3, 8, 30),
    breakStartAt: timeOnDay(3, 12, 15),
    breakEndAt: timeOnDay(3, 12, 45),
    clockOutAt: timeOnDay(3, 17, 15),
    isLate: false,
  ),

  // --- 4 days ago — a short shift with no break -------------------------------
  TimeEntry(
    id: TimeEntryIds.elise4,
    storeId: StoreIds.sablon,
    employeeId: EmployeeIds.elise,
    date: dayOnly(4),
    status: TimeEntryStatus.clockedOut,
    clockInAt: timeOnDay(4, 9, 0),
    clockOutAt: timeOnDay(4, 13, 0),
    isLate: false,
  ),

  // --- 5 days ago — an archived employee's history, kept as-is ---------------
  TimeEntry(
    id: TimeEntryIds.camille5,
    storeId: StoreIds.sablon,
    employeeId: EmployeeIds.camille,
    date: dayOnly(5),
    status: TimeEntryStatus.clockedOut,
    clockInAt: timeOnDay(5, 8, 0),
    breakStartAt: timeOnDay(5, 12, 0),
    breakEndAt: timeOnDay(5, 12, 30),
    clockOutAt: timeOnDay(5, 16, 0),
    isLate: false,
  ),
];
