import '../../models/models.dart';
import '../mock_employees.dart';
import '../mock_queries.dart';
import 'mock_write.dart';

/// Writes against personnel records — create, update, archive, restore.
///
/// **Never touches attendance or payroll.** Those are `AttendanceMutations`'
/// and `PayrollMutations`' jobs (Phases 3 and 5); this file's job is the same
/// split `item_mutations.dart` / `movement_mutations.dart` draw between an
/// article and its quantity — one file owns the record, another owns the
/// audit trail.
abstract final class EmployeeMutations {
  /// Creates an employee.
  ///
  /// Returns null when a required text field is empty, or when the CIN or the
  /// email is already used by another employee anywhere on the account (both
  /// are unique account-wide — see `.claude/phase_gestion_employee.md`
  /// decision 6; CIN is also the future login identifier).
  static Employee? create({
    required String storeId,
    required String firstName,
    required String lastName,
    required String cin,
    required String phone,
    required String email,
    required EmployeeRole role,
    required ContractType contractType,
    required double pay,
    DateTime? hireDate,
    int? scheduledStartMinutes,
    int? scheduledEndMinutes,
    String? photoAsset,
  }) {
    final first = firstName.trim();
    final last = lastName.trim();
    final trimmedCin = cin.trim();
    final trimmedPhone = phone.trim();
    final trimmedEmail = email.trim();
    if (first.isEmpty ||
        last.isEmpty ||
        trimmedCin.isEmpty ||
        trimmedPhone.isEmpty ||
        trimmedEmail.isEmpty) {
      return null;
    }
    if (MockQueries.employeeByCin(trimmedCin) != null) return null;
    if (MockQueries.employeeByEmail(trimmedEmail) != null) return null;

    final employee = Employee(
      id: MockWrite.id('employee'),
      storeId: storeId,
      firstName: first,
      lastName: last,
      cin: trimmedCin,
      phone: trimmedPhone,
      email: trimmedEmail,
      photoAsset: photoAsset,
      hireDate: hireDate ?? DateTime.now(),
      role: role,
      contractType: contractType,
      pay: pay,
      scheduledStartMinutes: scheduledStartMinutes,
      scheduledEndMinutes: scheduledEndMinutes,
      createdAt: DateTime.now(),
    );

    mockEmployees.add(employee);
    MockWrite.changed();
    return employee;
  }

  /// Edits an employee's details.
  ///
  /// **`archivedAt` is not a parameter.** Removal is [archive] / [restore] —
  /// the same reasoning as quantity being off the item edit form: an
  /// audit-relevant transition should not be reachable by dragging a field on
  /// a routine form. Pass [clearSchedule] to wipe a custom start/end back to
  /// "use the store's hours".
  static Employee? update(
    String id, {
    String? firstName,
    String? lastName,
    String? cin,
    String? phone,
    String? email,
    EmployeeRole? role,
    ContractType? contractType,
    double? pay,
    int? scheduledStartMinutes,
    int? scheduledEndMinutes,
    bool clearSchedule = false,
    String? photoAsset,
    bool clearPhoto = false,
  }) {
    final index = mockEmployees.indexWhere((e) => e.id == id);
    if (index == -1) return null;
    final existing = mockEmployees[index];

    final first = firstName?.trim();
    if (first != null && first.isEmpty) return null;
    final last = lastName?.trim();
    if (last != null && last.isEmpty) return null;

    final trimmedCin = cin?.trim();
    if (trimmedCin != null) {
      if (trimmedCin.isEmpty) return null;
      if (MockQueries.employeeByCin(trimmedCin, excludingId: id) != null) {
        return null;
      }
    }

    final trimmedPhone = phone?.trim();
    if (trimmedPhone != null && trimmedPhone.isEmpty) return null;

    final trimmedEmail = email?.trim();
    if (trimmedEmail != null) {
      if (trimmedEmail.isEmpty) return null;
      if (MockQueries.employeeByEmail(trimmedEmail, excludingId: id) != null) {
        return null;
      }
    }

    final updated = Employee(
      id: existing.id,
      storeId: existing.storeId,
      firstName: first ?? existing.firstName,
      lastName: last ?? existing.lastName,
      cin: trimmedCin ?? existing.cin,
      phone: trimmedPhone ?? existing.phone,
      email: trimmedEmail ?? existing.email,
      photoAsset: clearPhoto ? null : photoAsset ?? existing.photoAsset,
      hireDate: existing.hireDate,
      role: role ?? existing.role,
      contractType: contractType ?? existing.contractType,
      pay: pay ?? existing.pay,
      scheduledStartMinutes: clearSchedule
          ? null
          : scheduledStartMinutes ?? existing.scheduledStartMinutes,
      scheduledEndMinutes: clearSchedule
          ? null
          : scheduledEndMinutes ?? existing.scheduledEndMinutes,
      createdAt: existing.createdAt,
      archivedAt: existing.archivedAt,
    );

    mockEmployees[index] = updated;
    MockWrite.changed();
    return updated;
  }

  /// Soft-removes an employee: sets `archivedAt`, nothing else. Returns
  /// `false` if already archived. History (attendance, payroll) is left
  /// exactly as it was, the same as a removed supplier keeping its movements.
  static bool archive(String id) => _setArchivedAt(id, DateTime.now());

  /// Brings a retired employee back. Returns `false` if not archived.
  static bool restore(String id) => _setArchivedAt(id, null);

  static bool _setArchivedAt(String id, DateTime? value) {
    final index = mockEmployees.indexWhere((e) => e.id == id);
    if (index == -1) return false;
    final existing = mockEmployees[index];
    if ((existing.archivedAt == null) == (value == null)) return false;

    mockEmployees[index] = Employee(
      id: existing.id,
      storeId: existing.storeId,
      firstName: existing.firstName,
      lastName: existing.lastName,
      cin: existing.cin,
      phone: existing.phone,
      email: existing.email,
      photoAsset: existing.photoAsset,
      hireDate: existing.hireDate,
      role: existing.role,
      contractType: existing.contractType,
      pay: existing.pay,
      scheduledStartMinutes: existing.scheduledStartMinutes,
      scheduledEndMinutes: existing.scheduledEndMinutes,
      createdAt: existing.createdAt,
      archivedAt: value,
    );

    MockWrite.changed();
    return true;
  }
}
