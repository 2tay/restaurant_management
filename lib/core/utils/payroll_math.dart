import '../../models/models.dart';
import 'attendance_status.dart';

/// The pay arithmetic — "how a payslip figure should look", not a business
/// rule, so it stays out of the model and out of the screens the same way
/// `attendance_status.dart` and `order_status.dart` do. One place computes
/// the amount; the preview screen and the mutation both call it.
///
/// No absence handling (client decision, Phase 3): a fixed-salary employee is
/// paid a daily rate for every day they actually worked, plus an overtime
/// premium; there is no unjustified-absence deduction.
abstract final class PayrollRules {
  /// Overtime hours are paid at the normal rate times this — the default a
  /// new store starts from.
  static const double defaultOvertimeMultiplier = 1.25;

  /// Turns a monthly salary into a daily rate — the default divisor.
  static const int defaultWorkingDaysPerMonth = 26;
}

/// This employee's effective hourly rate, given the store settings.
///
/// - `extra`: [Employee.pay] is already €/h.
/// - `fixed`: monthly pay ÷ working days per month ÷ the standard 8h day.
double hourlyRate(Employee employee, StoreSettings settings) {
  switch (employee.contractType) {
    case ContractType.extra:
      return employee.pay;
    case ContractType.fixed:
      final daily = employee.pay / settings.workingDaysPerMonth;
      return daily / AttendanceRules.standardWorkDay.inMinutes * 60;
  }
}

double _hours(Duration d) => d.inMinutes / 60;

/// The end of day one [day] is measured against for overtime: the value frozen
/// on its row, or — for a row from before schema v3 — the live resolved
/// [scheduleEndMinutes]. Keeps a settings change from moving the overtime on a
/// day already worked.
int _endMinutesFor(Attendance day, int scheduleEndMinutes) =>
    day.scheduledEndMinutes ?? scheduleEndMinutes;

/// The pieces behind one finished day's amount, so a payslip detail view can
/// show the arithmetic instead of re-deriving it: the hourly [rate] used, the
/// [base] (every worked hour at that rate), the overtime [premium] (the extra
/// on top of the overtime hours, above what [base] already pays them), and the
/// [total] the two sum to. All zero for a day that is not `done`.
typedef DayAmount = ({double rate, double base, double premium, double total});

/// The [DayAmount] breakdown for one finished day. [dayAmount] is this,
/// projected to its [DayAmount.total].
DayAmount dayAmountBreakdown(
  Attendance day,
  Employee employee,
  StoreSettings settings, {
  required int scheduledEndMinutes,
}) {
  const zero = (rate: 0.0, base: 0.0, premium: 0.0, total: 0.0);
  if (day.status != AttendanceStatus.done) return zero;

  final worked = workedDuration(day);
  if (worked == null) return zero;

  final overtime = overtimeBy(day, scheduledEndMinutes) ?? Duration.zero;
  final rate = hourlyRate(employee, settings);
  final base = rate * _hours(worked);
  final premium = (settings.overtimeMultiplier - 1) * rate * _hours(overtime);

  return (rate: rate, base: base, premium: premium, total: base + premium);
}

/// What one finished day is worth: every worked hour at the normal rate, plus
/// an extra premium on the overtime hours. Zero for a day that is not
/// `done` — nothing to pay until the day is closed.
double dayAmount(
  Attendance day,
  Employee employee,
  StoreSettings settings, {
  required int scheduledEndMinutes,
}) => dayAmountBreakdown(
  day,
  employee,
  settings,
  scheduledEndMinutes: scheduledEndMinutes,
).total;

/// Totals over a set of finished days.
({int days, double workedHours, double overtimeHours}) periodTotals(
  Iterable<Attendance> days,
  Employee employee,
  StoreSettings settings,
) {
  final schedule = resolvedSchedule(
    employee,
    storeOpenMinutes: settings.openMinutes,
    storeCloseMinutes: settings.closeMinutes,
  );

  var count = 0;
  var worked = Duration.zero;
  var overtime = Duration.zero;

  for (final day in days) {
    if (day.status != AttendanceStatus.done) continue;
    count++;
    worked += workedDuration(day) ?? Duration.zero;
    overtime +=
        overtimeBy(day, _endMinutesFor(day, schedule.endMinutes)) ??
        Duration.zero;
  }

  return (
    days: count,
    workedHours: _hours(worked),
    overtimeHours: _hours(overtime),
  );
}

/// The amount for a set of finished days.
double periodAmount(
  Iterable<Attendance> days,
  Employee employee,
  StoreSettings settings,
) {
  final schedule = resolvedSchedule(
    employee,
    storeOpenMinutes: settings.openMinutes,
    storeCloseMinutes: settings.closeMinutes,
  );

  var total = 0.0;
  for (final day in days) {
    total += dayAmount(
      day,
      employee,
      settings,
      scheduledEndMinutes: _endMinutesFor(day, schedule.endMinutes),
    );
  }
  return total;
}
