import '../../models/models.dart';

/// What a role is allowed to do — the single table the sidebar, the router
/// guard and the action buttons all read.
///
/// `.claude/phase_gestion_employee.md` §Phase 6: enforcement was deferred while
/// Phases 2–5 built every screen ungated. This is that enforcement. The grants
/// are **static** — a role's capabilities are declared here in code, not stored
/// per person. Making them owner-configurable later means replacing
/// `_grants[role]` with "role default + per-employee overrides" without
/// touching a single call site.
enum Capability {
  /// The roster — add / edit / archive / restore staff.
  manageEmployees,

  /// The pointage kiosk board.
  viewTimeclock,

  /// The attendance history log.
  viewAttendanceHistory,

  /// The payroll history and the "Payer" action.
  managePayroll,

  /// Saving changes on Paramètres → Établissement.
  editStoreSettings,

  /// Opening a new store.
  createStore,

  /// See and operate in **every** store of the business, not only the store
  /// this person belongs to. The owner spans; a manager or staff member is
  /// bound to their home store (`Employee.storeId`).
  spanAllStores,
}

/// The capability set each role holds. Reads as a matrix; edit here to move a
/// permission between roles.
const Map<EmployeeRole, Set<Capability>> _grants = {
  EmployeeRole.owner: {
    Capability.manageEmployees,
    Capability.viewTimeclock,
    Capability.viewAttendanceHistory,
    Capability.managePayroll,
    Capability.editStoreSettings,
    Capability.createStore,
    Capability.spanAllStores,
  },
  EmployeeRole.manager: {
    Capability.viewTimeclock,
    Capability.viewAttendanceHistory,
  },
  EmployeeRole.staff: <Capability>{},
};

/// Whether [role] holds [capability]. Pure — call sites pass
/// `mockCurrentEmployee.role`.
bool can(EmployeeRole role, Capability capability) =>
    _grants[role]!.contains(capability);

/// Whether [employee] may see and act in the store [storeId].
///
/// The owner spans the whole business; everyone else is bound to the store
/// they were created in.
bool canAccessStore(Employee employee, String storeId) =>
    can(employee.role, Capability.spanAllStores) ||
    employee.storeId == storeId;

/// The stores [employee] may navigate to — every store for the owner, just the
/// home store for a manager or staff member.
List<Store> visibleStores(Employee employee, List<Store> allStores) =>
    can(employee.role, Capability.spanAllStores)
    ? allStores
    : allStores.where((store) => store.id == employee.storeId).toList();
