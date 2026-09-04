import '../../models/models.dart';

/// Derivations over [Employee].
///
/// Same role `stock_status.dart` plays for items: figures and labels the UI
/// needs that fall out of the data rather than being stored on it. Kept off
/// the model so it stays plain data for Phase 2's storage layer to persist
/// untouched, and out of the screens so each one does not reinvent it.

/// Active unless soft-removed. The one source of truth is [Employee.archivedAt].
bool isEmployeeActive(Employee employee) => employee.archivedAt == null;

/// "Prénom Nom", trimmed. The display name every screen shows.
String employeeDisplayName(Employee employee) =>
    '${employee.firstName} ${employee.lastName}'.trim();

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
