import '../../models/models.dart';
import 'attendance_status.dart';

/// This employee's hourly rate — [Employee.pay] is already €/h.
double hourlyRate(Employee employee, StoreSettings settings) => employee.pay;

double _hours(Duration d) => d.inMinutes / 60;

/// The rate one day is figured at: the one frozen on its payroll run once the
/// day is paid ([period]), the employee's current one until then — so a later
/// raise never rewrites what a paid day shows.
double dayRate(
  Employee employee,
  StoreSettings settings,
  PayrollPeriod? period,
) => period?.appliedRate ?? hourlyRate(employee, settings);

/// What one finished day is worth at [rate] €/h: the time worked over every
/// session, breaks deducted, at that rate. Zero for a day that is not `done` —
/// nothing to pay until the day is closed.
double dayAmountAt(Attendance day, double rate) {
  if (day.status != AttendanceStatus.done) return 0;
  final worked = workedDuration(day);
  if (worked == null) return 0;
  return rate * _hours(worked);
}

/// What one finished day is worth at the employee's current rate.
double dayAmount(Attendance day, Employee employee, StoreSettings settings) =>
    dayAmountAt(day, hourlyRate(employee, settings));

/// Totals over a set of finished days.
({int days, double workedHours}) periodTotals(Iterable<Attendance> days) {
  var count = 0;
  var worked = Duration.zero;

  for (final day in days) {
    if (day.status != AttendanceStatus.done) continue;
    count++;
    worked += workedDuration(day) ?? Duration.zero;
  }

  return (days: count, workedHours: _hours(worked));
}

/// The amount for a set of finished days.
double periodAmount(
  Iterable<Attendance> days,
  Employee employee,
  StoreSettings settings,
) {
  var total = 0.0;
  for (final day in days) {
    total += dayAmount(day, employee, settings);
  }
  return total;
}
