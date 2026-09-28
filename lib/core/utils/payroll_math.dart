import '../../models/models.dart';
import 'attendance_status.dart';

/// This employee's hourly rate — [Employee.pay] is already €/h.
double hourlyRate(Employee employee, StoreSettings settings) => employee.pay;

double _hours(Duration d) => d.inMinutes / 60;

/// What one finished day is worth: every worked hour at the hourly rate. Zero
/// for a day that is not `done` — nothing to pay until the day is closed.
double dayAmount(Attendance day, Employee employee, StoreSettings settings) {
  if (day.status != AttendanceStatus.done) return 0;
  final worked = workedDuration(day);
  if (worked == null) return 0;
  return hourlyRate(employee, settings) * _hours(worked);
}

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
