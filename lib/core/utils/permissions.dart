import '../../models/models.dart';

/// What a role is allowed to do — the single table the sidebar, the router
/// guard and the action buttons all read.
///
/// `.claude/phase_gestion_employee.md` §Phase 6: enforcement was deferred while
/// Phases 2–5 built every screen ungated. This is that enforcement. Kept as one
/// function rather than a matrix page (that page is not being reinstated) so
/// there is exactly one source of truth.
///
/// Pure — takes a role, not the session. Call sites pass
/// `mockCurrentEmployee.role`.
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
}

/// Whether [role] holds [capability].
///
/// - **owner** — everything (spans stores, payroll, staff, settings).
/// - **manager** — runs the store day to day: the pointage board and the
///   attendance history, nothing else.
/// - **staff** — no active app access at all (their pointage is done for them
///   at the shared kiosk); they cannot even sign in.
bool can(EmployeeRole role, Capability capability) => switch (role) {
  EmployeeRole.owner => true,
  EmployeeRole.manager =>
    capability == Capability.viewTimeclock ||
        capability == Capability.viewAttendanceHistory,
  EmployeeRole.staff => false,
};
