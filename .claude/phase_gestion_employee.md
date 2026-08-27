# Gestion Employée — rebuild brief

## 0. How to use this document

This is a **contract**, in the same spirit as [`phase1.md`](./phase1.md) and
[`phase_employees.md`](./phase_employees.md). It replaces the two modules that exist today —
**Équipe** (`lib/features/team/`) and **Personnel** (`lib/features/employees/`) — with a single
**Gestion Employée** module, and adds payroll and real authentication/permissions.

Source of the requirement: [`docs/gestion_personnelle.md`](../docs/gestion_personnelle.md).

**Work it in 6 phases, in order.** Each phase lands as its own reviewable commit. A phase must
not require re-touching an earlier phase's screens except through the seams this document names
in advance.

| Phase | Scope |
|---|---|
| **1** | **Teardown** — delete every trace of the current Équipe + Personnel modules, leave the app compiling and green |
| **2** | **Foundations + page Employée** — the new models, the write/read layer, routes, sidebar entry, mock data, and the roster screen (list / add / edit / detail) |
| **3** | **Tableau de bord** — the pointage kiosk: today's board, N pauses/day, mark-absent, live clock, full screen |
| **4** | **Historique de pointage** — the filterable attendance log across every employee and day, with KPIs and pagination |
| **5** | **Historique de paiement** — payroll periods, day-by-day compute, "Payer" with day-locking |
| **6** | **Auth + permissions** — CIN + PIN login (fake), `EmployeeCredential`, role-based gating. **Detailed design deferred — see §Phase 6.** |

**At the end of every phase**, write a completion doc describing what was built, into
`.claude/employee_docs/` — same purpose and French style as
[`docs/page_personelle.md`](../docs/page_personelle.md): a plain overview so whoever picks the
code up next does not have to recompose it from commits. Naming:
`.claude/employee_docs/phase_1_teardown.md`, `phase_2_employee_page.md`, etc.

---

## 1. Confirmed decisions

These were agreed before writing this brief. They are settled; the rest of the document builds
on them.

1. **`Employee` and `TeamMember` merge into one model.** `TeamMember`, `lib/features/team/`,
   the roles/permissions matrix page — all gone. Everyone (Owner included) is an `Employee`
   carrying a `role`.
2. **One store per employee.** `Employee.storeId` is a single id, not a list. Multi-store is
   the Owner's concern only: an Owner can create stores (existing `add_store_page.dart` /
   `AccountMutations.createStore` stays) and switch between them by navigation, exactly as
   today. There is no per-employee store list.
3. **Auth is the last phase and stays fake.** No backend, no real hashing, no JWT. A mock
   session, a login screen that checks CIN + PIN against mock credentials, `mockCurrentEmployee`
   becomes the login result, and `router` gains a `redirect` guard. Consistent with the
   README's "still fake, deliberately" stance on login.
4. **Permission enforcement design is deferred to Phase 6.** Phases 2–5 build every screen
   ungated (as the rest of the app is today); the current mock user is the Owner, so
   everything is reachable while those phases are in flight.
5. **`student` contract type is removed.** Two types only: `fixed` (Salarié fixe) and `extra`.
6. **CIN and email are both unique — per account, i.e. globally across stores.** Not
   per-store like the old `employeeByEmail`. CIN is also the future login identifier.
7. **Long tables cap then paginate.** The attendance history and the payment history render up
   to a page size (25) then show a pager. `DataTableWrapper` still owns horizontal scroll;
   vertical is bounded by the page, not infinite.
8. **Name is split** into `firstName` + `lastName`. Initials and display name are derived.
9. **No absence handling** (decided during Phase 3). No `absent` / `absentJustified` status,
   no "Marquer absent", no justification, no `Attendance.comment`. A day nobody clocked is
   just "Non pointé". Consequences downstream: the attendance history has no absence filter
   or KPI; payroll has no unjustified-absence deduction and no `absenceDays` — a fixed-salary
   employee is simply paid their monthly amount. The lines below that still mention absences
   are superseded by this point.

---

## 2. Conventions to follow — the "same behaviour"

Nothing here is new. It is the existing project discipline, restated so no phase skips a step
because this brief did not repeat it. Every one of these is already how `orders`, `inventory`,
`suppliers` etc. were built.

- **Feature-first.** `lib/features/employees/presentation/{pages,widgets}/`. No `data/` or
  `domain/` in this phase.
- **Models** in `lib/models/`: immutable, `const` constructor, no logic, no `fromJson`, no
  persistence annotations. Add every new model to the `lib/models/models.dart` barrel. Pure
  Dart — no `package:flutter` import in a model (times are stored as `int` minutes-since-midnight,
  not `TimeOfDay`).
- **Derivations** in `lib/core/utils/`, beside the model, never on it — mirror
  `stock_status.dart` / `order_status.dart`. Threshold constants live in a named
  `abstract final class` (like `OrderRules`, `PointageRules`).
- **Reads** go through `MockQueries` (`lib/mock_data/mock_queries.dart`). Screens never touch
  a mock list directly.
- **Writes** go through one mutation file per aggregate in `lib/mock_data/mutations/`. Each
  method **refuses the wrong prior state** (returns `null`/`false`) rather than coercing it,
  and calls `MockWrite.changed()` **on success only**. This is enforced by `ux_audit.py`: no
  mock list is written outside `mock_data/mutations/`.
- **`MockWrite.captureSeed()` / `reset()`** (`mutations/mock_write.dart`) must list every new
  mutable list. `mock_write_test.dart`'s "clears every mutable list and asserts reset brings
  it back" test must be extended for each. **This is the single easiest thing to forget.**
- **`mock_data.dart` barrel** re-exports every new mock file.
- **Routes** in `lib/app/routes.dart` (constants + `toX(storeId)` builders) and `router.dart`
  (`GoRoute` entries). Literal segments (`new`, `timeclock`, …) are declared **before**
  `:employeeId`, same reason `orders` declares `new` before `:orderId`.
- **Navigation** via `context.goSection()` / `pushScreen()` / `backTo()` from
  `lib/app/navigation.dart` — never a raw `context.go()` (`ux_audit.py` flags it). Root screens
  carry no back control; pushed screens carry a labelled back control and breadcrumbs.
- **Every user-facing string** through `AppLocalizations`, added to `lib/l10n/app_fr.arb` with
  an `@key` description, regenerated with `flutter gen-l10n`. Reuse existing keys where the
  text already exists.
- **No hardcoded colours / text styles / spacing.** `app_colors.dart`, `app_typography.dart`,
  `app_spacing.dart` (`AppSpacing` / `AppSizing` / `AppRadius` / `AppMotion`) only. Check for
  an existing token before adding one.
- **No formatting by hand.** `core/utils/formatters.dart` (`Formatters.price`, `.date`,
  `.time`, `.duration`, `.dateLong`, `.relative`). Add a helper there if a new shape is needed
  (e.g. minutes-since-midnight → `08:30`).
- **Status is never colour alone** — colour + a distinct icon shape + a text label, built the
  way `StockStatusBadge` is. `ux_audit.py` checks this.
- **Every destructive action confirms first and the dialog names the record**
  (`ConfirmDialog.confirmDelete(name: …)` / `.show`). Every write fires the standard snackbar
  (`AppSnackBar.success`).
- **Every list has both empty states** — "nothing here yet" vs "your filters matched nothing"
  (`EmptyState` / `EmptyState.noResults`).
- **Shared widgets go in `lib/shared/widgets/`** and are re-exported from `widgets.dart`. A
  widget used by two features is shared, not copied. (This brief moves several today-duplicated
  bits — the avatar, the status badge, the KPI tile, the attendance row — into `shared/`.)
- **Forms** use `FormScaffold` (Cancel bottom-left, submit bottom-right, dirty-form guard —
  do not re-implement).
- **Tests** per aggregate, styled like `orders_test.dart` — the test file is the spec.
  `test/support/mock_reset.dart` in `setUp`. `navigation_test.dart` and `router_test.dart`
  extended for every new route, checked at 1280×800, 1024×600 and portrait.
- **Before calling a phase done:** `flutter analyze` clean, `flutter test` clean,
  `python tool/ux_audit.py` → 0 violations, and `flutter run` + a manual walk of the new
  screens.
- **Mock data rules:** Brasserie du Sablon carries the full dataset; **Taverne Saint-Gilles
  stays empty** (it is the README's every-empty-state store). Dates anchored to `mockNow`
  via `mock_reference.dart` helpers; nothing asserts on them. One record of every enum value,
  one archived, and every demo-critical state present and reachable without manipulation.

---

## 3. Target architecture — models and ownership

### Aggregates and who writes them

| Aggregate | Model file | Mutation file (the **only** writer) | Introduced |
|---|---|---|---|
| Employee | `employee.dart` | `employee_mutations.dart` | Phase 2 |
| Attendance (+ embedded pauses) | `attendance.dart` | `attendance_mutations.dart` | Phase 3 |
| PayrollPeriod | `payroll_period.dart` | `payroll_mutations.dart` — **the only file that flips `Attendance.paymentStatus`** | Phase 5 |
| EmployeeCredential | `employee_credential.dart` | `credential_mutations.dart` | Phase 6 |

Same split discipline as `item_mutations.dart` (the article) vs `movement_mutations.dart` (its
quantity): the record and the audit-relevant state it carries are owned by different files so
they can never disagree.

### Models (shapes — English names, French only at the UI)

```dart
// employee.dart
enum EmployeeRole { owner, manager, staff }      // UI: Owner / Gérant / Employé
enum ContractType { fixed, extra }               // UI: Salarié fixe / Extra

class Employee {
  final String id;
  final String storeId;                          // exactly one — decision 2
  final String firstName;
  final String lastName;
  final String cin;                              // unique account-wide, future login id
  final String phone;
  final String email;                            // unique account-wide
  final String? photoAsset;                      // mocked, like Store.imageAsset
  final DateTime hireDate;
  final EmployeeRole role;
  final ContractType contractType;
  final double pay;                              // monthly € when fixed, €/h when extra
  final int? scheduledStartMinutes;              // null → fall back to store open time
  final int? scheduledEndMinutes;                // null → fall back to store close time
  final DateTime createdAt;
  final DateTime? archivedAt;                    // null = active. Soft delete only.
}

// attendance.dart  (per decision 9: no absence statuses, no comment)
enum AttendanceStatus {
  notClockedIn,        // never stored — the absence of a row means this
  working,
  onBreak,
  done,
}
enum PaymentStatus { unpaid, paid }

class AttendancePause {
  final DateTime startAt;
  final DateTime? endAt;                         // null while the pause is running
}

class Attendance {
  final String id;
  final String storeId;
  final String employeeId;
  final DateTime date;                           // midnight — the work day
  final AttendanceStatus status;
  final DateTime? clockInAt;
  final DateTime? clockOutAt;
  final List<AttendancePause> pauses;            // embedded, like PurchaseOrder.lines
  final PaymentStatus paymentStatus;
  final String? payrollPeriodId;                 // set when a period locks this day
}

// payroll_period.dart
enum PayrollStatus { computed, paid }

class PayrollPeriod {
  final String id;
  final String storeId;
  final String employeeId;
  final DateTime startDate;
  final DateTime endDate;
  final int workedDays;
  final double totalWorkedHours;
  final double totalOvertimeHours;
  final double appliedRate;                      // frozen snapshot of the rate at pay time
  final double computedAmount;
  final PayrollStatus status;
  final String? paidByEmployeeId;                // the Owner who validated
  final DateTime? paidAt;
  final DateTime createdAt;
}

// employee_credential.dart  (Phase 6)
class EmployeeCredential {
  final String id;
  final String employeeId;
  final String pinHash;                          // fake hash, never plain
  final int failedAttempts;
  final DateTime? lockedUntil;
  final DateTime? lastLoginAt;
}
```

### Derivations — `core/utils/`

- **`employee_status.dart`** — `isEmployeeActive(e)`, `employeeDisplayName(e)`,
  `employeeInitials(e)`.
- **`attendance_status.dart`** — `AttendanceRules` (constants), `totalBreak(a)`,
  `workedDuration(a)` (clockOut − clockIn − Σ pauses, floored at zero, null until clockOut),
  `resolvedSchedule(employee, store)` → (startMinutes, endMinutes),
  `lateBy(a, resolvedStart)`, `overtimeBy(a, resolvedEnd)` — null until the timestamps exist,
  never negative.
- **`payroll_math.dart`** (Phase 5) — `PayrollRules` (default `overtimeMultiplier` 1.25,
  `workingDaysPerMonth` 26), `dailyRate(employee, settings)`, `dayAmount(attendance, employee,
  settings)`, `periodTotals(List<Attendance>)`, `periodAmount(...)`. Fixed vs extra handled
  here, not in a screen.
- **`permissions.dart`** (Phase 6) — `can(role, Capability)`.

### Store settings — a real model (`StoreSettings`), decided in Phase 3

The old `MockSettings` static holder is **removed**. Per-store config is a proper immutable
model, `lib/models/store_settings.dart`, read via `MockQueries.storeSettings(storeId)` and
written via `AccountMutations.updateStoreSettings`. It carries `openMinutes`, `closeMinutes`,
`maxBreakMinutes` (all landed in Phase 3), plus `stalePartialOrderDays` (migrated from the
old holder). `overtimeMultiplier` / `workingDaysPerMonth` join it in **Phase 5**.
`AccountMutations.createStore` seeds a default row; `mockStoreSettings` is in the
`MockWrite` snapshot. Editable on **Paramètres → Établissement**.

---

## Phase 1 — Teardown

**Goal:** remove every trace of the current Équipe and Personnel modules. The app must compile,
`flutter analyze` and `flutter test` must be green, and `ux_audit.py` must report 0 violations
at the end. No new feature — this is a pure subtraction, reviewable on its own.

### Delete outright

- `lib/features/team/` (whole folder)
- `lib/features/employees/` (whole folder)
- `lib/models/team_member.dart`, `lib/models/time_entry.dart`, `lib/models/employee.dart`
- `lib/mock_data/mock_team.dart`, `lib/mock_data/mock_employees.dart`,
  `lib/mock_data/mock_time_entries.dart`
- `lib/mock_data/mutations/employee_mutations.dart`,
  `lib/mock_data/mutations/timeclock_mutations.dart`
- `lib/core/utils/employee_status.dart`, `lib/core/utils/timeclock_status.dart`
- `lib/shared/widgets/time_entry_status_badge.dart`
- `test/employees_test.dart`, `test/timeclock_test.dart`

### Clean references

- **`lib/models/models.dart`** — drop the three removed exports.
- **`lib/mock_data/mock_data.dart`** — drop the removed exports.
- **`lib/mock_data/mutations/mock_write.dart`** — remove `mockTeam`, `mockEmployees`,
  `mockTimeEntries` from `captureSeed()` and `reset()`.
- **`lib/mock_data/mutations/account_mutations.dart`** — delete the entire **Team** section
  (`invite`, `updateMember`, `removeMember`, `isLastOwner`) and the `clearTeamMemberLink`
  call inside it. Keep **Stores** and **Notifications** untouched.
- **`lib/mock_data/mock_queries.dart`** — delete `teamForStore`, `teamMemberById`,
  `teamMemberByEmail`, `ownerCount`, and the whole `Employees` + `Pointage` query blocks.
- **`lib/app/routes.dart`** — delete every `team`, `roles`, `member`, `employees`,
  `timeclock`, `timeclockHistory`, `linkTeamAccess` constant and its `toX` builder.
- **`lib/app/router.dart`** — delete the matching imports and `GoRoute` entries.
- **`lib/shared/widgets/app_sidebar.dart`** — delete the **Team** `_Destination`, the whole
  **Employés** accordion machinery (`_ChildDestination`, `_EmployeesParentLabel`,
  `_EmployeesChildLabel`, `_TreeBranchPainter`, `_showFlyout`, `_employeesExpanded`, the
  `_destinationKeys` if now unused). The rail goes back to a flat list of direct
  destinations. Re-check `router_test.dart` at all three breakpoints.
- **`lib/shared/widgets/widgets.dart`** — drop the `time_entry_status_badge` export.
- **The signed-in user.** `mockCurrentUser` (from `mock_team.dart`) is read by
  `app_top_bar.dart`, `store_dashboard_page.dart` and `account_settings_page.dart`. Replace it
  with a temporary stub `lib/mock_data/mock_session.dart`:
  ```dart
  const String mockSignedInFullName = 'Marc Delvaux';
  const String mockSignedInEmail = 'marc.delvaux@brasserie-sablon.be';
  ```
  Point the three call sites at it. In `account_settings_page.dart` remove the role line and
  the `roleLabel` import (Phase 6 restores a real role). This stub is the **Phase 1 → Phase 2
  seam** — Phase 2 replaces it with `mockCurrentEmployee`.
- **`test/account_test.dart`** — remove the team group, keep stores + notifications.
- **`test/navigation_test.dart` / `test/router_test.dart`** — remove the team / employees /
  timeclock route rows and the "highlights Gestion des employés" / "Tableau de pointage" /
  "Historique" tests.
- **`test/mock_data_test.dart` / `test/mock_write_test.dart`** — remove team / employee /
  time-entry assertions.
- **`test/components_test.dart`** — remove the `TimeEntryStatusBadge` test.
- **`lib/l10n/app_fr.arb`** — remove the now-dead keys (`team*`, `member*`, `role*`,
  `permission*`, `employee*`, `timeEntry*`, `timeclock*`, `linkTeamAccess*`, `a11yPermission*`,
  the `nav` keys for team/employees). `flutter gen-l10n`. Grep the codebase for each removed
  getter before deleting to be sure nothing else uses it.
- **`docs/page_personelle.md`** — move to `.claude/employee_docs/_archive/page_personelle_v1.md`
  (it documents the module being removed; keep it for history, out of the active docs).

### Sweep

`grep -ri` for `team`, `TeamMember`, `TeamRole`, `Employee`, `TimeEntry`, `timeclock`,
`pointage`, `roleLabel`, `mockCurrentUser` across `lib/` and `test/` and resolve every hit.
Watch for false positives (`Semantics(role:)`, ARIA-ish `role` on unrelated widgets).

### Done when

App runs, opens on login → store selector → dashboard, every remaining section works, the rail
has no Équipe / Employés entry, `flutter analyze` + `flutter test` + `ux_audit.py` all clean.

### Completion doc

`.claude/employee_docs/phase_1_teardown.md` — list what was deleted, the `mock_session.dart`
stub and why, and the exact seams Phase 2 must pick up (the stub, the flat sidebar, the freed
route namespace).

---

## Phase 2 — Foundations + page Employée

**Goal:** the new module's spine, plus the roster screen. After this phase an Owner can add,
edit, archive, restore and inspect staff, with roles and contract types.

### Models & derivations

- `lib/models/employee.dart` — `Employee`, `EmployeeRole`, `ContractType` per §3. Barrel it.
- `lib/core/utils/employee_status.dart` — `isEmployeeActive`, `employeeDisplayName`,
  `employeeInitials`.
- `mockCurrentEmployee` — replace the `mock_session.dart` stub with a real `Employee`
  (the Owner, Sablon). Repoint `app_top_bar.dart`, `store_dashboard_page.dart`,
  `account_settings_page.dart` (restore the role line, now via a shared `employeeRoleLabel`).

### Mock data — `lib/mock_data/mock_employees.dart`

`EmployeeIds` + `List<Employee> mockEmployees`. Brasserie du Sablon:

- one **Owner** (= `mockCurrentEmployee`), one **Gérant** (manager), the rest **staff**
- at least one `fixed` and one `extra`
- one employee with an explicit `scheduledStart/End`, the rest null (fall back to store hours)
- one **archived** (Camille — keep the name, `archivedAt` set)
- Taverne Saint-Gilles: **none**

`mock_data_test.dart` grows parallel assertions (one of each role, one of each contract, one
archived, Taverne empty).

### Mutations — `lib/mock_data/mutations/employee_mutations.dart`

`abstract final class EmployeeMutations`:

- `create({storeId, firstName, lastName, cin, phone, email, role, contractType, pay,
  scheduledStartMinutes?, scheduledEndMinutes?, photoAsset?})` → validates required fields
  non-empty; **CIN unique account-wide**, **email unique account-wide** (new `MockQueries`
  helpers, matched via `_normalise` like category names). Returns `null` on any failure.
- `update(id, {…})` → same uniqueness guards with `excludingId: id`. **Never accepts
  `archivedAt`** — archiving is its own method (same reasoning as quantity being off the item
  edit form).
- `archive(id)` → sets `archivedAt = now`, touches nothing else. Returns `false` if already
  archived.
- `restore(id)` → clears `archivedAt`. Returns `false` if not archived. (The doc's
  "Restaurer" action.)
- No hard delete.

Add `mockEmployees` to `MockWrite.captureSeed()/reset()` and extend the `mock_write_test.dart`
full-restore test.

### Queries — `lib/mock_data/mock_queries.dart`

- `employeesForStore(storeId)` — all, any status
- `activeEmployeesForStore(storeId)` — `isEmployeeActive` only
- `employeeById(id)` — resolvable even when archived
- `employeeByCin(cin, {excludingId})`, `employeeByEmail(email, {excludingId})` — account-wide,
  normalised

### Routes & navigation

`lib/app/routes.dart`:
```
employees        = '$storeBase/employees'
addEmployee      = '$employees/new'
timeclock        = '$employees/timeclock'
attendanceHistory= '$employees/attendance-history'
payroll          = '$employees/payroll'
payrollNew       = '$payroll/new'
employeeDetail   = '$employees/:employeeId'
editEmployee     = '$employeeDetail/edit'
```
All literal segments before `:employeeId`. Matching `toX(storeId)` / `toEmployee(storeId, id)`
builders. Register all in `router.dart` in the same order (Phase 2 wires `employees`,
`addEmployee`, `employeeDetail`, `editEmployee`; the others get placeholder routes now or are
added in their phase — placeholder is cleaner for the sidebar).

**Sidebar** — one `_Destination`, **Gestion Employée**, `matchSegment: 'employees'`, an
accordion with **4 children** (reuse the pattern Phase 1 deleted — restore it from git history,
now with 4 items):

| Child | Route | Later gated to |
|---|---|---|
| Employée | `toEmployees` | Owner |
| Tableau de bord | `toTimeclock` | Owner + Gérant |
| Historique pointage | `toAttendanceHistory` | Owner + Gérant |
| Historique de paiement | `toPayroll` | Owner |

In Phases 2–5 all four are always visible. Phase 6 filters by `mockCurrentEmployee.role`.
Collapsed rail falls back to the popup flyout. Re-verify `router_test.dart` at all three
breakpoints — the accordion can add 3 rows while expanded.

### Screens — `lib/features/employees/presentation/`

- **`employees_list_page.dart`** — root (no back control). KPI row (total actifs, Fixes/Extras,
  Gérants, embauches ce mois — via the shared `StatTile`). `SearchField` by name **and CIN**.
  `FilterPill` toggle Actifs / Archivés (default Actifs). Grid or list of employee cards
  (`EmployeeAvatar`, name, CIN, `EmployeeRoleBadge`, contract chip, archived pill). Row menu:
  Modifier / Retirer (archive) / Restaurer (when archived). Two empty states.
- **`add_edit_employee_page.dart`** — one `FormScaffold` for both modes. Fields: prénom, nom,
  CIN, téléphone, e-mail, photo (mocked picker → warning snackbar), `role` (`AppDropdown`,
  closed list), `contractType` (segmented / dropdown), pay (label switches
  "Salaire mensuel (€)" ↔ "Tarif horaire (€/h)" reactively), horaires personnalisés optionnels
  (two time fields, empty → "horaires de l'établissement"). **No credentials section yet** —
  Phase 6. Uniqueness failures (CIN / email) shown under the field, not in a snackbar.
- **`employee_detail_page.dart`** — pushed screen, back "Retour à Personnel". Sections:
  coordonnées, emploi (role, contract, pay, resolved schedule), état (archived banner with
  date + a "Restaurer" action). **Attendance history + payroll history sections are placeholders
  in Phase 2** — a "no data yet" card each, wired for real in Phases 3 and 5 via the shared
  `AttendanceRow` / a payroll list widget. Actions: Modifier, Retirer / Restaurer
  (`ConfirmDialog` naming the person).

### Shared widgets — `lib/shared/widgets/`

- `employee_avatar.dart` — `EmployeeAvatar({employee, size})`: photo or initials circle. The
  four local copies from the old module become this one.
- `employee_role_badge.dart` — `EmployeeRoleBadge` + `String employeeRoleLabel(l10n, role)`.
- `stat_tile.dart` — `StatTile({label, value, icon, accent?})`: the KPI card the old
  `timeclock_history_page` had as a private `_StatTile`, now shared (dashboard's `SummaryTile`
  stays as-is — migrating it is out of scope).
- Re-export all from `widgets.dart`.

### Tests

`test/employees_test.dart` (styled like `suppliers_test.dart` / `catalog_test.dart`):

- CIN unique account-wide; email unique account-wide; a rename does not collide with itself;
  the same CIN/email in a different store **is refused** (decision 6, unlike the old per-store
  rule).
- `archive` sets `archivedAt`, nothing else; refused (false) when already archived.
- `restore` clears it; refused when not archived.
- `update` cannot change `archivedAt` whatever is passed.
- an archived employee is out of `activeEmployeesForStore` but still `employeeById`-resolvable.

`navigation_test.dart` / `router_test.dart` — the employees routes, sidebar highlight from a
nested screen, the accordion children. `mock_write_test.dart` — `mockEmployees` restore.

### Completion doc

`.claude/employee_docs/phase_2_employee_page.md`.

---

## Phase 3 — Tableau de bord (pointage kiosk)

**Goal:** the shared-tablet clock-in board — today's status per active employee, N pauses/day,
mark-absent, live clock, full-screen kiosk mode.

### Models & derivations

- `lib/models/attendance.dart` — `Attendance`, `AttendancePause`, `AttendanceStatus`,
  `PaymentStatus` per §3. Barrel.
- `lib/core/utils/attendance_status.dart` — `AttendanceRules` (defaults only),
  `totalBreak`, `workedDuration` (excludes **all** pauses), `resolvedSchedule`, `lateBy` /
  `isLate`, `overtimeBy`, and `breakOverrun` / `hasLateBreak` / `totalBreakOverrun`
  (per-segment break-overrun check against `StoreSettings.maxBreakMinutes`).
- **`StoreSettings` model** (see §3) — `lib/models/store_settings.dart` +
  `mock_store_settings.dart` + `AccountMutations.updateStoreSettings` +
  `MockQueries.storeSettings`. New section on `store_settings_page.dart`: "Horaires de
  l'établissement" — ouverture, fermeture, pause max.
- `Formatters` — add `minutesToClock(int)` → `08:30` and `clockToMinutes(String)`.

### Mock data — `lib/mock_data/mock_attendances.dart`

`AttendanceIds` + `List<Attendance> mockAttendances`, spanning several distinct days:

- **today, in progress** — some `working`, one `onBreak` **with two completed pauses + one
  running** (proves N pauses), a couple of employees with **no row** (→ `notClockedIn`)
- earlier days all finished (`done`), including one with **real overtime** and one flagged
  **late** against the resolved schedule
- one `absent` (unjustified) and one `absentJustified` with a `comment`
- one finished day already `paid` (`paymentStatus: paid`, `payrollPeriodId` set) — Phase 5
  needs a locked day to exist; wire the id now, the `PayrollPeriod` row arrives in Phase 5

`mock_data_test.dart` — assert the seed covers: multiple pauses in one day, one late, one
overtime, one of each absence kind, one paid day.

### Mutations — `lib/mock_data/mutations/attendance_mutations.dart`

`abstract final class AttendanceMutations` — **the only writer of `mockAttendances`**. Every
method takes an optional `now` (tests pin it, like `MovementMutations.recordStockIn`'s
`occurredAt`) and refuses the wrong prior state:

| Method | Refuses when | Effect |
|---|---|---|
| `clockIn(employeeId, storeId, {now})` | today's row already exists | new row, `working`, `clockInAt` |
| `startPause(attendanceId, {now})` | status != `working` | append `AttendancePause(startAt: now)`, status `onBreak` |
| `endPause(attendanceId, {now})` | status != `onBreak` / no open pause | close the open pause, status `working` |
| `clockOut(attendanceId, {now})` | status != `working` (in particular not on break) | `clockOutAt`, status `done` |
| `markAbsent(employeeId, storeId, {justified, comment, now})` | today's row exists and is not `notClockedIn` | row with status `absent` / `absentJustified` |
| `clearAbsence(attendanceId)` | status not an absence | back to `notClockedIn` (delete the row) |

**Every method also refuses if the target day is `paymentStatus == paid`** — a locked day is
immutable (mirrors "confirmed receipts are permanent").

Add `mockAttendances` to `MockWrite` seed + `mock_write_test.dart`.

### Queries

- `attendanceForToday(employeeId)` — via `dayOnly(0)`
- `attendanceById(id)`
- `attendancesForEmployee(employeeId)` — most recent first (feeds the detail page section)

### Screens

- **`timeclock_board_page.dart`** — `goSection` destination, no back control. Header: today's
  date + **live clock** isolated in its own `Timer.periodic` widget. **Full-screen toggle**
  (`isFullScreenProvider`, reset to false in `dispose`) — restore this from the old
  implementation. **No KPIs** (kiosk = speed, per the doc). `SearchField` by name + CIN.
  Grid of cards, `notClockedIn` sorted first. Each card: `EmployeeAvatar`, name, CIN,
  `AttendanceStatusBadge`, the day's timestamp log (clock-in, each pause window, clock-out),
  and:
  - one primary action button cycling **Pointer → Pause → Reprendre → … → Fin de journée**
    (Reprendre returns to `working`, where **Pause is offered again** — N pauses — until
    Fin de journée)
  - a secondary **"Marquer absent"** action (only before clock-in), opening a small dialog
    (justifiée / non justifiée + optional reason)
  - once `done` / `absent*`: read-only summary (worked duration, overtime, a "Retard" mark),
    no buttons
- Standard success snackbar on every tap.
- **`employee_detail_page.dart`** — replace the Phase 2 placeholder attendance section with the
  real one, using the shared `AttendanceRow` scoped to the employee.

### Shared widgets

- `attendance_status_badge.dart` — `AttendanceStatusBadge` + `attendanceStatusLabel(l10n,
  status)` (colour + distinct icon + label; reuse palette tokens: `working`→green,
  `onBreak`→amber, `done`→grey, `absent`→red, `absentJustified`→neutral).
- `attendance_row.dart` — `AttendanceRow({attendance, employeeName?, dense?})`: one day's line
  (date, times, worked duration, status, late marker). Used by the detail page (Phase 3) and
  the history table (Phase 4).

### Tests

`test/attendance_test.dart` (styled like `orders_test.dart`):

- `clockIn` twice same day refused, first row untouched
- `startPause` before `clockIn`, `endPause` before `startPause`, `clockOut` while `onBreak` —
  all refused, state unchanged
- **two full pause cycles in one day succeed**, `totalBreak` sums both, `workedDuration`
  excludes both
- `markAbsent` justified / unjustified transitions; `clearAbsence` reverses
- late / overtime computed against the resolved schedule (employee override wins over store
  hours; null override falls back)
- any write against a `paid` day is refused
- `MockWrite.reset()` restores `mockAttendances`

### Completion doc

`.claude/employee_docs/phase_3_timeclock_board.md`.

---

## Phase 4 — Historique de pointage

**Goal:** the filterable attendance log across every employee and day, with KPIs and
pagination. No new model — reads and presents `mockAttendances`.

### Queries — `lib/mock_data/mock_queries.dart`

```dart
static AttendancePage attendancesForStore(
  String storeId, {
  DateTimeRange? range,          // "Aujourd'hui" / "Cette semaine" / "Ce mois" / "Personnalisé"
  AttendanceStatus? status,
  String? employeeQuery,         // name, _normalise-matched (case/space-insensitive)
  int page = 0,
  int pageSize = 25,
})
```
Returns a small `AttendancePage` record: `rows` (the page slice, most-recent-day-first),
`totalCount`, `page`, `pageCount`. Filters AND-combine. Employee name resolved via
`employeeById` inside the query so the UI never looks it up. Range boundaries **inclusive both
ends**.

A separate unpaginated `attendanceStatsForStore(storeId, {range})` for the KPI header —
totals over the filtered period, independent of the page.

### Screens — `attendance_history_page.dart`

- `goSection` destination, no back control.
- **KPI row** (`StatTile`): total heures travaillées, total heures de retard, nombre
  d'absences, taux de présence % — over the filtered period.
- Filters (`FilterPill` + `PopupMenuButton`, the `stock_history_page.dart` pattern): période
  (4 presets + Personnalisé → date-range picker; check the reports pages for an existing one
  before building), statut (`AttendanceStatus`), employé (`SearchField`). Removable active-
  filter chips below.
- **Table** via `DataTableWrapper` (`minWidth` set, horizontal scroll contained): Date,
  Employé, Entrée, Sortie, Retard, Nb pauses, Durée pauses, Durée travail, Heures sup, Statut
  (`AttendanceStatusBadge`), Retard (icon-only). Row → detail side panel (reuse the old
  `_HistoryDetailPanel` shape).
- **Pagination** (decision 7): a shared `Paginator` widget — "Précédent / Suivant" +
  "X–Y sur Z". `lib/shared/widgets/paginator.dart`.
- Two empty states (no attendance at all vs no rows for the filters, with "effacer les
  filtres").

### Shared widgets

- `paginator.dart` — `Paginator({page, pageCount, totalCount, onChanged})`.

### Screens touched

- `employee_detail_page.dart` — the attendance section can stay on `attendancesForEmployee`
  (documented deviation, like the old module) or switch to `attendancesForStore` with the
  employee fixed. Prefer keeping the simple query; note it.

### Tests

Extend `test/attendance_test.dart` or add `test/attendance_history_test.dart`:

- range boundaries inclusive both ends
- status filter alone; employee-name filter alone (case/space-insensitive, partial)
- all three AND-combined
- sort order most-recent-first
- pagination: page count, slice size, last page remainder, `page` out of range clamps

### Completion doc

`.claude/employee_docs/phase_4_attendance_history.md`.

---

## Phase 5 — Historique de paiement

**Goal:** payroll periods — list what's been paid, compute a new period day-by-day, and "Payer"
locks those days against any future period (no double payment).

### Models & derivations

- `lib/models/payroll_period.dart` — `PayrollPeriod`, `PayrollStatus` per §3. Barrel.
- `lib/core/utils/payroll_math.dart` — `PayrollRules` (default `overtimeMultiplier` 1.25,
  `workingDaysPerMonth` 26), `dailyRate(employee, settings)` (fixed: `pay / workingDaysPerMonth`;
  extra: n/a — extra is paid by the hour), `dayAmount(attendance, employee, settings)`
  (worked hours × hourly-equivalent + overtime × multiplier; **unjustified absence →
  retenue for `fixed`, zero for `extra`**; `extra` has no absence concept),
  `periodTotals(List<Attendance>)`, `periodAmount(...)`.
- **Settings** — add `overtimeMultiplier` + `workingDaysPerMonth` to the per-store holder and
  the `store_settings_page.dart` section from Phase 3.

### Mock data — `lib/mock_data/mock_payroll_periods.dart`

One **paid** `PayrollPeriod` for the employee whose earlier days Phase 3 seeded as `paid`
(wire the two together — the `payrollPeriodId` on those `Attendance` rows points here). Keep it
small: one row is enough to show the list and prove the lock.

### Mutations — `lib/mock_data/mutations/payroll_mutations.dart`

`abstract final class PayrollMutations` — **the only file that writes `mockPayrollPeriods` and
the only file that flips `Attendance.paymentStatus`**:

- `preview(employeeId, storeId, range)` → pure computation, **persists nothing** — returns the
  day-by-day breakdown + totals + amount for the screen. (Like a receipt draft before confirm.)
- `pay(employeeId, storeId, range, {paidByEmployeeId, now})` → refuses if **any** day in range
  is already `paid`; otherwise creates the `PayrollPeriod` (`status: paid`, `appliedRate`
  frozen, `paidAt`/`paidBy` stamped) **and** flips every covered `Attendance` to
  `paymentStatus: paid` + sets `payrollPeriodId`. One atomic success → one `MockWrite.changed()`.

Add `mockPayrollPeriods` to `MockWrite` seed + `mock_write_test.dart`.

### Queries

- `payrollPeriodsForStore(storeId, {employeeId?, range?, status?, page, pageSize})` → paginated,
  most-recent-first
- `payrollPeriodById(id)`
- `payrollPeriodsForEmployee(employeeId)` — feeds the detail page section

### Screens — `payroll_history_page.dart` + `payroll_new_page.dart`

- **`payroll_history_page.dart`** — `goSection` destination. KPI row (masse salariale payée sur
  la période, montant en attente, employés payés / non payés, total heures sup payées). Filters:
  employé, période, statut. Table of `PayrollPeriod` rows (employé, période couverte, montant,
  date de paiement). `Paginator`. "Nouveau paiement" button → `payrollNew`. Two empty states.
- **`payroll_new_page.dart`** (pushed) — step 1: pick employee + period (range picker). Step 2:
  day-by-day table from `PayrollMutations.preview` (date, heures travaillées, heures sup,
  absent oui/non, statut). Totals. A **"Payer"** primary action → `ConfirmDialog` naming the
  employee and the amount → `PayrollMutations.pay` → success snackbar → back to the history.
  If any day is already locked, the affected rows are flagged and "Payer" is disabled with an
  explanation (not a silent failure).
- **`employee_detail_page.dart`** — replace the Phase 2 payroll placeholder with the real
  `payrollPeriodsForEmployee` list.

### Shared widgets

- `payment_status_badge.dart` — `PaymentStatusBadge` (`paid` / `unpaid`) + label, if the
  history table wants it.

### Tests

`test/payroll_test.dart` (styled like `orders_test.dart` — this is the phase with real
behaviour):

- `dailyRate` / `dayAmount`: fixed vs extra; unjustified absence → retenue for fixed, nothing
  for extra; overtime × multiplier
- `preview` persists nothing (`mockPayrollPeriods` and `paymentStatus` unchanged after a call)
- `pay` creates the period, flips every covered day to `paid`, stamps `payrollPeriodId`
- `pay` over a range containing an already-paid day is **refused**, nothing half-applied
- `appliedRate` on the stored period is the rate at pay time — a later `EmployeeMutations.update`
  of `pay` does not change a paid period
- an `AttendanceMutations` write against a day locked by `pay` is refused (cross-check with
  Phase 3)
- `MockWrite.reset()` restores both lists
- the seed has one paid period and its days are consistent (`paymentStatus == paid` ⇔
  `payrollPeriodId != null`)

### Completion doc

`.claude/employee_docs/phase_5_payroll.md`.

---

## Phase 6 — Auth + permissions

**Design deferred — to be detailed in a follow-up session (decision 4).** Sketch only, so the
earlier phases leave the right seams:

- **`EmployeeCredential`** model + `mock_credentials.dart` + `credential_mutations.dart`
  (`setPin`, `recordFailedAttempt`, `recordSuccessfulLogin`, `unlock`). Fake hash. Added to
  `MockWrite`.
- **Mock session** — `mockCurrentEmployee` becomes the result of a login, held in a small
  mutable holder / provider. A real logout.
- **Login screen** — CIN + PIN, checked against `mock_credentials`, failure counter + temporary
  lock. Replaces the current fake `login_page.dart` flow (still no network).
- **`router.dart`** — a `redirect` guard: unauthenticated → login; authenticated `staff` role
  → blocked from the store shell (staff have no active access, per the doc).
- **`core/utils/permissions.dart`** — `Capability` enum + `can(role, capability)`. The
  Gestion Employée sidebar children filter by it; the four pages guard their routes;
  action buttons (`archive`, `markAbsent`, `pay`, store settings, create store) check it.
- **Add-employee form** — gains the credentials section (set an initial PIN) it deliberately
  omitted in Phase 2.
- **`roles_permissions_page`** — optionally reinstated as a read-only reference matrix, now
  backed by the same `can()` table it documents (not a second hardcoded copy).
- Tests: `test/auth_test.dart` (login, lockout, logout), `test/permissions_test.dart`
  (`can()` table, a `staff` login cannot reach the shell, sidebar children filtered).

### Completion doc

`.claude/employee_docs/phase_6_auth_permissions.md`.

---

## Cross-cutting checklist (every phase)

- [ ] New strings → `app_fr.arb` with `@description`, `flutter gen-l10n`
- [ ] No hardcoded colour / text style / spacing
- [ ] Status badges: colour + icon + label
- [ ] Destructive actions confirm and name the record
- [ ] Every write fires the standard snackbar
- [ ] Both empty-state variants per list
- [ ] Shared widgets in `lib/shared/widgets/` + barrel, not copied into a feature
- [ ] New mock lists in `MockWrite.captureSeed()/reset()` + `mock_write_test.dart`
- [ ] New routes in `navigation_test.dart` + `router_test.dart` at 1280×800 / 1024×600 / portrait
- [ ] `flutter analyze` clean · `flutter test` clean · `python tool/ux_audit.py` → 0 violations
- [ ] `flutter run` + manual walk of the new screens
- [ ] Completion doc written to `.claude/employee_docs/`
