import '../../models/models.dart';

/// Derivations over [Employee].
///
/// Same role `stock_status.dart` plays for items: figures and labels the UI
/// needs that fall out of the data rather than being stored on it. Kept off
/// the model so it stays plain data for Phase 2's storage layer to persist
/// untouched, and out of the screens so each one does not reinvent it.

/// Active unless soft-removed. The one source of truth is [Employee.archivedAt].
bool isEmployeeActive(Employee employee) => employee.archivedAt == null;

/// Limits on what an employee record may hold.
abstract final class EmployeeRules {
  /// The highest hourly rate the form and the repository accept, in €/h.
  /// Well above any real wage — it only catches a slipped key (`1e9`, `1500`
  /// for `15,00`) before it is frozen into a paid `payroll_periods` row.
  static const double maxHourlyRate = 1000;
}

/// A rate the payroll maths can use: a real number, from 0 (an unpaid
/// trainee) to [EmployeeRules.maxHourlyRate]. Refuses a negative rate, `NaN`
/// and `Infinity`, which `double.tryParse` all accept and which would poison
/// every amount computed from them.
bool isValidHourlyRate(double pay) =>
    pay.isFinite && pay >= 0 && pay <= EmployeeRules.maxHourlyRate;

/// "Prénom Nom", trimmed, each word starting with a capital — "amélie
/// vandenberghe" as typed still reads "Amélie Vandenberghe". Only the first
/// letter of a word is touched, so "McKenna" or "Jean-Baptiste" keep their
/// own casing. The display name every screen shows.
String employeeDisplayName(Employee employee) =>
    '${employee.firstName} ${employee.lastName}'
        .trim()
        .split(RegExp(r'\s+'))
        .map(_capitalised)
        .join(' ');

String _capitalised(String word) =>
    word.isEmpty ? word : word[0].toUpperCase() + word.substring(1);

/// First letter of the first and last name — "Amélie Vandenberghe" → "AV".
/// Falls back to a single initial when only one name part is present.
String employeeInitials(Employee employee) {
  final first = employee.firstName.trim();
  final last = employee.lastName.trim();
  final letters = [
    if (first.isNotEmpty) first[0],
    if (last.isNotEmpty) last[0],
  ].join();
  return letters.toUpperCase();
}
