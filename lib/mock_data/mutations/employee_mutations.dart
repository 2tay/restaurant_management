import '../../models/models.dart';
import '../mock_employees.dart';
import '../mock_queries.dart';
import 'mock_write.dart';

/// Writes against personnel records — create, update, archive.
///
/// **Never touches attendance.** That is `TimeclockMutations`' job, and this
/// file's job is the same split `item_mutations.dart` / `movement_mutations.
/// dart` draw between an article and its quantity: one file owns the record,
/// a second and only that file owns the piece of state that must stay a
/// trustworthy audit trail.
abstract final class EmployeeMutations {
  /// Creates an employee.
  ///
  /// Returns null when a required field is empty, or the email is already
  /// used by another employee of this store — the one guard worth running,
  /// mirrored on `AccountMutations.invite` via `teamMemberByEmail`.
  static Employee? create({
    required String storeId,
    required String fullName,
    required String email,
    required String phone,
    required String address,
    required String cin,
    required EmployeeType type,
    required PayType payType,
    required double payRate,
    String? photoAsset,
  }) {
    final trimmedName = fullName.trim();
    final trimmedEmail = email.trim();
    final trimmedPhone = phone.trim();
    final trimmedAddress = address.trim();
    final trimmedCin = cin.trim();
    if (trimmedName.isEmpty ||
        trimmedEmail.isEmpty ||
        trimmedPhone.isEmpty ||
        trimmedAddress.isEmpty ||
        trimmedCin.isEmpty) {
      return null;
    }
    if (MockQueries.employeeByEmail(storeId, trimmedEmail) != null) {
      return null;
    }

    final employee = Employee(
      id: MockWrite.id('employee'),
      storeId: storeId,
      fullName: trimmedName,
      email: trimmedEmail,
      phone: trimmedPhone,
      address: trimmedAddress,
      cin: trimmedCin,
      photoAsset: photoAsset,
      type: type,
      payType: payType,
      payRate: payRate,
      createdAt: DateTime.now(),
    );

    mockEmployees.add(employee);
    MockWrite.changed();
    return employee;
  }

  /// Edits an employee's details.
  ///
  /// **`archivedAt` is absent on purpose.** Archiving is its own method
  /// below, the same reasoning as quantity being off the item edit form: an
  /// audit-relevant transition should not be reachable by dragging a field on
  /// a routine form.
  static Employee? update(
    String id, {
    String? fullName,
    String? email,
    String? phone,
    String? address,
    String? cin,
    EmployeeType? type,
    PayType? payType,
    double? payRate,
    String? photoAsset,
    bool clearPhoto = false,
  }) {
    final index = mockEmployees.indexWhere((e) => e.id == id);
    if (index == -1) return null;

    final existing = mockEmployees[index];
    final trimmedName = fullName?.trim();
    if (trimmedName != null && trimmedName.isEmpty) return null;

    final trimmedEmail = email?.trim();
    if (trimmedEmail != null && trimmedEmail.isEmpty) return null;
    if (trimmedEmail != null &&
        MockQueries.employeeByEmail(
              existing.storeId,
              trimmedEmail,
              excludingId: id,
            ) !=
            null) {
      return null;
    }

    final trimmedPhone = phone?.trim();
    if (trimmedPhone != null && trimmedPhone.isEmpty) return null;
    final trimmedAddress = address?.trim();
    if (trimmedAddress != null && trimmedAddress.isEmpty) return null;
    final trimmedCin = cin?.trim();
    if (trimmedCin != null && trimmedCin.isEmpty) return null;

    final updated = Employee(
      id: existing.id,
      storeId: existing.storeId,
      fullName: trimmedName ?? existing.fullName,
      email: trimmedEmail ?? existing.email,
      phone: trimmedPhone ?? existing.phone,
      address: trimmedAddress ?? existing.address,
      cin: trimmedCin ?? existing.cin,
      photoAsset: clearPhoto ? null : photoAsset ?? existing.photoAsset,
      type: type ?? existing.type,
      payType: payType ?? existing.payType,
      payRate: payRate ?? existing.payRate,
      createdAt: existing.createdAt,
      archivedAt: existing.archivedAt,
      teamMemberId: existing.teamMemberId,
    );

    mockEmployees[index] = updated;
    MockWrite.changed();
    return updated;
  }

  /// Soft-removes an employee: sets `archivedAt`, and nothing else.
  ///
  /// **Never touches `mockTimeEntries`.** History for an archived employee
  /// stays exactly as it was, the same as a removed supplier keeping its
  /// movements and closed orders. Returns `false` if already archived — there
  /// is no hard delete to fall back to, and no second archive to record.
  static bool archive(String id) {
    final index = mockEmployees.indexWhere((e) => e.id == id);
    if (index == -1) return false;

    final existing = mockEmployees[index];
    if (existing.archivedAt != null) return false;

    mockEmployees[index] = Employee(
      id: existing.id,
      storeId: existing.storeId,
      fullName: existing.fullName,
      email: existing.email,
      phone: existing.phone,
      address: existing.address,
      cin: existing.cin,
      photoAsset: existing.photoAsset,
      type: existing.type,
      payType: existing.payType,
      payRate: existing.payRate,
      createdAt: existing.createdAt,
      archivedAt: DateTime.now(),
      teamMemberId: existing.teamMemberId,
    );

    MockWrite.changed();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Application access
  // ---------------------------------------------------------------------------

  /// Records that [employeeId] now has an application account, [teamMemberId].
  ///
  /// Called once, right after `AccountMutations.invite` succeeds for this
  /// person, from `LinkTeamAccessPage`. A separate write on purpose — each
  /// mutation file only ever touches the list it owns, so the invite and the
  /// link are two calls rather than one method reaching into both.
  static Employee? linkTeamMember(String employeeId, String teamMemberId) {
    final index = mockEmployees.indexWhere((e) => e.id == employeeId);
    if (index == -1) return null;

    final existing = mockEmployees[index];
    final updated = Employee(
      id: existing.id,
      storeId: existing.storeId,
      fullName: existing.fullName,
      email: existing.email,
      phone: existing.phone,
      address: existing.address,
      cin: existing.cin,
      photoAsset: existing.photoAsset,
      type: existing.type,
      payType: existing.payType,
      payRate: existing.payRate,
      createdAt: existing.createdAt,
      archivedAt: existing.archivedAt,
      teamMemberId: teamMemberId,
    );

    mockEmployees[index] = updated;
    MockWrite.changed();
    return updated;
  }

  /// Clears `teamMemberId` on any employee pointing at [teamMemberId].
  ///
  /// Called by `AccountMutations.removeMember` when a linked account is
  /// removed, so an employee's profile never points at an account that no
  /// longer exists — the same cascade `ItemMutations.delete` runs over the
  /// supplier prices and movements that name the item being removed.
  static void clearTeamMemberLink(String teamMemberId) {
    var changed = false;

    for (var i = 0; i < mockEmployees.length; i++) {
      final existing = mockEmployees[i];
      if (existing.teamMemberId != teamMemberId) continue;

      mockEmployees[i] = Employee(
        id: existing.id,
        storeId: existing.storeId,
        fullName: existing.fullName,
        email: existing.email,
        phone: existing.phone,
        address: existing.address,
        cin: existing.cin,
        photoAsset: existing.photoAsset,
        type: existing.type,
        payType: existing.payType,
        payRate: existing.payRate,
        createdAt: existing.createdAt,
        archivedAt: existing.archivedAt,
        teamMemberId: null,
      );
      changed = true;
    }

    if (changed) MockWrite.changed();
  }
}
