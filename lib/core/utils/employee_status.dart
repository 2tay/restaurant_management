import '../../models/employee.dart';

/// Whether an employee is currently active.
///
/// The one place this is decided. Mirrors `stock_status.dart`: the model
/// stays plain data and carries no `isActive` flag of its own —
/// `Employee.archivedAt` is the single source of truth, and this function is
/// how the rest of the app reads it.
bool isEmployeeActive(Employee e) => e.archivedAt == null;
