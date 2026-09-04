# Employees module — brief for the implementing agent

## 0. How to use this document

This is an implementation brief in the same spirit as [`phase1.md`](./phase1.md): a
contract, not a suggestion. It follows the conventions the codebase already enforces —
feature-first folders, `mock_queries.dart` for reads, one mutation file per aggregate,
immutable logic-free models, everything through `AppLocalizations`, `flutter analyze` +
`flutter test` clean, `python tool/ux_audit.py` clean.

Work it in **3 stages, one per page**, in order — each stage should land as its own
reviewable change, and stage *N* must not require re-touching stage *N-1*'s screens except
through the seams this document names in advance.

- **Stage 1 — Personnel** (`lib/features/employees`): the roster. Add / edit / soft-remove
  a staff member, see their profile, see their clock history.
- **Stage 2 — Pointage** (time clock board): today's date/time, one card per active
  employee, the 3-tap status button.
- **Stage 3 — Historique de pointage**: the filterable table across all employees and days.

Stage 1 also carries the **foundation work** shared by all three (routes, sidebar entry,
models that stage 2/3 need to *reference*, even though stage 1 doesn't populate them) — see
§1. Don't defer that split further; re-plumbing the sidebar in stage 3 is exactly the kind
of rework this staging is meant to avoid.

## Assumptions made in writing this brief — confirm or correct before starting

The request left a few points underspecified. Rather than block on them, this brief makes
the call the same way the rest of the app resolves this kind of ambiguity (see
`OrderRules.significantPriceChange`, `TeamRole`'s deliberately-small enum) — a concrete,
named, easy-to-change decision. **Read this list before Stage 1; it drives the data model.**

1. **"Personnelle" → *Personnel*.** French for "staff" is *le personnel*; used as the page
   label and route name throughout. (Say if you meant something else — a person's own
   personal-info page, for instance, would be a different feature entirely.)

2. **The pause button is a 4-state cycle, not 3.** The request names 3 statuses (*Pointer* /
   *Pause* / *Fin de journée*) but also asks to "calculer la durée de pause" against a fixed
   threshold — which needs a start **and** an end timestamp. So the real cycle is:

   `Pointer` → `Pause` → `Reprendre` → `Fin de journée`

   Tapping *Pause* starts the break; tapping *Reprendre* ends it, computes the duration, and
   compares it to `PointageRules.maxBreakDuration`, flagging `isLate` if it ran over. The
   request's "second status" covers what happens on *both* of those taps. **One break per
   working day** — the button does not offer a second *Pause* after *Reprendre*; only *Fin
   de journée* remains. If multiple breaks per day are wanted, say so — it changes `TimeEntry`
   from one row per day to a list of break windows.

3. **Overtime needs a baseline.** "Heures supplémentaires" requires *worked hours* to be
   compared against something. This brief adds `PointageRules.standardWorkDayDuration` (a
   single store-wide constant, default 8h) rather than a per-employee contracted-hours field,
   to match the size of what was asked. A per-employee baseline is a natural Stage 4 if
   wanted later.

4. **The dropdown is a flyout on one rail entry, not an accordion.** `AppSidebar` is a fixed
   `NavigationRail` that is *already* documented as height-constrained on a small tablet
   (`app_sidebar.dart`'s comment about 380dp/148dp stolen from content). Growing it by two
   full rows when "Employés" expands risks exactly that regression again. Instead: one rail
   entry, **Employés**, opens a small popup (same `PopupMenuButton` pairing `FilterPill`
   already uses) with two items, *Personnel* and *Pointage*. The rail's destination count
   stays fixed at 11. If you want a true accordion instead, budget time to re-verify
   `router_test.dart`'s 1024×600 pass and say so up front — it may need the rail's
   `scrollable` behavior re-checked.

5. **Historique de pointage is a tab of Pointage, not a third sidebar page.** The request
   names two pages for the dropdown ("Personnelle et Pointage") but three numbered
   behaviors. This brief reconciles that by putting the history table behind a second
   `SectionTabs` entry on the Pointage screen — *Aujourd'hui* / *Historique* — exactly the
   pattern `order_detail_page.dart` (Lignes/Réceptions) and the supplier detail page already
   use for "two views of one screen." If you actually want *Historique* as its own sidebar
   destination, that's a one-line change to §4 below (add a third popup item and a route),
   but the tab approach is recommended: it needs no new nav mechanism at all.

6. **Photo is a mocked field, not a real upload** — same treatment as `Store.imageAsset`.
   No image picker plumbing, no file storage. A nullable asset-path string; null renders an
   initials tile. Consistent with the project's "still fake, deliberately" stance on anything
   that would need real infrastructure to not be a lie (README, "Still fake, deliberately").

7. **Employee type stays a small, closed enum**, matching `TeamRole`'s "three roles, not a
   matrix" philosophy: `fixedSalary` (Salarié fixe), `student` (Étudiant), `extra` (Extra).
   Add a fourth the same way if needed later — do not build a configurable-types settings
   screen for this.

8. **Break threshold and standard work day are hardcoded constants for now** (`PointageRules`
   in `core/utils/`), not a new row on the store settings page. `stalePartialOrderDays` is
   the precedent for promoting a constant like this to a per-store setting later — same move,
   not in scope for these 3 stages.

---

## 1. Foundations (do this once, at the start of Stage 1)

### Models — `lib/models/`

Immutable, no logic, no `fromJson` — same contract as every other model.

**`employee.dart`**
```dart
enum EmployeeType { fixedSalary, student, extra }
enum PayType { monthlySalary, hourlyRate }

class Employee {
  final String id;
  final String storeId;
  final String fullName;
  final String email;
  final String phone;
  final String address;
  final String cin;
  final String? photoAsset;       // null → initials tile, like Store.imageAsset
  final EmployeeType type;
  final PayType payType;
  final double payRate;           // interpreted per payType — monthly € or €/h
  final DateTime createdAt;
  final DateTime? archivedAt;     // null = active. Soft delete sets this, never removes the row.
}
```
Do **not** add an `isActive` bool alongside `archivedAt` — one nullable field is the single
source of truth, same reasoning as `PurchaseOrderLine.closedShort` being the only signal of
a shortfall rather than a second derived flag that could disagree with it. Derive
"is this employee active" in `core/utils/`, not on the model — see below.

**`time_entry.dart`**
```dart
enum TimeEntryStatus { notClockedIn, onShift, onBreak, clockedOut }

class TimeEntry {
  final String id;
  final String storeId;
  final String employeeId;
  final DateTime date;            // normalized to midnight — the work day this entry is for
  final TimeEntryStatus status;
  final DateTime? clockInAt;
  final DateTime? breakStartAt;
  final DateTime? breakEndAt;
  final DateTime? clockOutAt;
  final bool isLate;              // break exceeded PointageRules.maxBreakDuration — set once, at Reprendre
}
```
One `TimeEntry` per employee per calendar day, created lazily on the first `Pointer` tap of
that day — there is no "opening balance" row like `StockMovement` needs, because a day with
no entry simply means *not clocked in yet*, which is representable without a row.

Add both to `lib/models/models.dart`'s barrel export.

### Derivations — `core/utils/`

Mirror `stock_status.dart` and `order_status.dart` exactly: models stay dumb, derivation
lives beside them.

**`employee_status.dart`**
```dart
bool isEmployeeActive(Employee e) => e.archivedAt == null;
```

**`timeclock_status.dart`**
```dart
abstract final class PointageRules {
  static const Duration maxBreakDuration = Duration(minutes: 30);
  static const Duration standardWorkDayDuration = Duration(hours: 8);
}

Duration? breakDuration(TimeEntry entry) { ... }        // null until breakEndAt is set
Duration? workedDuration(TimeEntry entry) { ... }        // null until clockOutAt is set; excludes the break
Duration? overtime(TimeEntry entry) { ... }              // workedDuration - standardWorkDayDuration, floored at zero
```
Same rationale as `stockStatusOf`: this is "how a number should look," not a business rule,
so it stays out of the model and out of the screens — one place computes it.

### Routes — `lib/app/routes.dart`

Append to the store-scoped block, following the existing `toX(storeId)` builder convention:

```dart
static const String employees = '$storeBase/employees';
static const String addEmployee = '$employees/new';
static const String employeeDetail = '$employees/:employeeId';
static const String editEmployee = '$employeeDetail/edit';
static const String timeclock = '$employees/timeclock';
```
`new` is declared before `:employeeId` for the same go_router ordering reason `orders`
declares `new` before `:orderId` — otherwise "new" and "timeclock" get read as an id. Add the
matching `toEmployees`, `toAddEmployee`, `toEmployee`, `toEditEmployee`, `toTimeclock`
builders next to the existing ones.

`timeclock` carries no path segment for the history tab — it's an in-place `SectionTabs`
switch (§5), not a route, exactly like the order detail's Lignes/Réceptions.

### Sidebar — `lib/shared/widgets/app_sidebar.dart`

Add one `_Destination`-equivalent entry, **Employés**, between Team and Settings (or wherever
reads best — it's a judgment call, not a rule). Per assumption 4, this one entry needs to
open a 2-item popup instead of navigating directly:

- Wrap it so tapping opens a `PopupMenuButton` (same pairing `FilterPill` already documents:
  "Pair it with a `PopupMenuButton`; it is the `child`, not the menu") anchored to the rail
  item, offering *Personnel* → `toEmployees(storeId)` and *Pointage* → `toTimeclock(storeId)`,
  both via `context.goSection(...)`.
- `matchSegment: 'employees'` so the rail highlights **Employés** from every screen under it
  — list, detail, add/edit, and the timeclock board.
- Extend `navigation_test.dart`'s sidebar-highlight assertions to cover this entry, the same
  way it already checks every other section highlights from a nested screen.
- Re-run `router_test.dart` at all three breakpoints once this lands — it's the test that
  already caught the rail growing past budget once; it's the right guard here too.

### Mock data — `lib/mock_data/`

`mock_employees.dart` and `mock_time_entries.dart`, seeded like every other mock file (see
`mock_data_test.dart` for the property style to match — this file should grow parallel
assertions once stage 1/2 seed data exists):

- At least one employee of each `EmployeeType` and each `PayType`.
- At least one **archived** employee (`archivedAt` set) — the empty/filtered-state precedent.
- Brasserie du Sablon should have employees; **Taverne Saint-Gilles stays empty** (it's the
  brand-new store the README uses to exercise every empty state — an employees list that
  quietly seeds it breaks that property).
- Time entries spanning **several distinct days**, not just today, so Stage 3's date-range
  filter has something to filter — include at least one entry with `isLate: true` and at
  least one with real overtime, so those states are demo-able rather than theoretical.
- Dates anchored to `DateTime.now()` the way `mock_stock_movements.dart` already is, per the
  README's "dates in the mock data are anchored... nothing asserts on them" convention.

### Mutations — `lib/mock_data/mutations/`

**Two files, split the same way `item_mutations.dart` / `movement_mutations.dart` split** —
that pair is the closest existing precedent: one file owns the record, a second and only
that file owns the specific piece of state that must stay a trustworthy audit trail.

| File | Owns |
|---|---|
| `employee_mutations.dart` | Personnel records — create, update, archive. **Never touches attendance.** |
| `timeclock_mutations.dart` | Pointage — clock-in, break start, break end, clock-out. **The only file that writes a `TimeEntry`.** |

`employee_mutations.dart`:
- `create(...)` → validates non-empty required fields, unique email per store (same guard
  `AccountMutations.invite` runs via `teamMemberByEmail`, mirrored here against employees).
- `update(id, ...)` → never accepts `archivedAt` as a parameter; archiving is its own method,
  same reasoning as quantity being off the item edit form — an audit-relevant transition
  should not be reachable by dragging a field on a routine form.
- `archive(id)` → sets `archivedAt = DateTime.now()`. Does **not** touch `mockTimeEntries` —
  history for an archived employee stays exactly as-is, same as a removed supplier keeping
  its movements and closed orders. Returns `false` if already archived.
- No hard `delete`. The request explicitly ruled it out ("pas hard suppression"); don't add
  one "for completeness."

`timeclock_mutations.dart` — one call per button state, each refusing the wrong prior state
rather than silently coercing it (mirror `order_mutations.dart`'s pattern of refusing an edit
on a sent order, refusing cancellation on a partial receipt):
- `clockIn(employeeId, storeId)` → refuses if today's entry already exists for that employee;
  creates it with `status: onShift`, `clockInAt: now`.
- `startBreak(entryId)` → refuses unless `status == onShift`; sets `breakStartAt: now`,
  `status: onBreak`.
- `endBreak(entryId)` → refuses unless `status == onBreak`; sets `breakEndAt: now`, computes
  `breakDuration`, sets `isLate` if it exceeds `PointageRules.maxBreakDuration`, `status`
  back to `onShift`.
- `clockOut(entryId)` → refuses unless `status == onShift`; sets `clockOutAt: now`,
  `status: clockedOut`.

Every one of these calls `MockWrite.changed()` on success only — a refused call is a no-op,
same as every other mutation in the app.

### `mock_write.dart` — do not skip this

`MockWrite.captureSeed()` / `reset()` snapshot every mutable list by hand. **Add
`mockEmployees` and `mockTimeEntries` to both.** This is the easiest thing in this brief to
forget and the one the project has already been burned by once — it's why
`mock_write_test.dart`'s last test "clears every mutable list and asserts the reset brings
all of it back." **Extend that exact test** to clear and restore the two new lists. If you
skip this, the demo-reset button silently stops restoring employees after the first walkthrough,
and nothing before that test catches it.

### `ux_audit.py`

No script changes needed. Phase 1.7's generalized rule — "no mock list is written outside
`mock_data/mutations/`" — already covers `mockEmployees` and `mockTimeEntries` as long as the
two mutation files above are the only place that touches them. Just don't violate it.

---

## 2. Stage 1 — Personnel

Folder: `lib/features/employees/presentation/pages/`, `widgets/` — same shape as
`lib/features/team`.

- **`employees_list_page.dart`** — root screen (no back control, per the "root screens carry
  neither" rule), reached from the sidebar. Cards or rows (project already leans list-of-cards
  for people — see `team_list_page.dart` for the closest precedent) showing photo/initials,
  full name, type, and an archived indicator when applicable. `SearchField` by name. A
  `FilterPill`-driven toggle for "afficher les personnels retirés" — default hides archived,
  same instinct as items/suppliers defaulting to what's currently usable. Two empty states:
  no employees at all (new store) vs. no results for the current search/filter — the UX rule
  the audit script checks for.
- **`add_edit_employee_page.dart`** — one `FormScaffold`-based screen for both create and
  edit (existing convention — see `add_edit_supplier_page.dart`/`add_edit_member_page.dart`
  for the shared-form-for-both-modes shape). Fields: full name, email, phone, address, CIN,
  photo (mocked picker per assumption 6), type (`AppDropdown`, with no inline "+ Créer" — the
  type list is closed per assumption 7, unlike categories/units), pay type (segmented
  control or dropdown), pay rate (label switches between "Salaire mensuel (€)" and "Tarif
  horaire (€/h)" based on the selected pay type — do this reactively in the form state, not
  as two separate fields). Cancel bottom-left, submit bottom-right, dirty-form guard — all
  free from `FormScaffold`, don't reimplement them.
- **`employee_detail_page.dart`** — pushed screen (`pushScreen`, labelled back control
  "Retour à Personnel"). Shows the profile fields, a status line if archived (who/when isn't
  tracked, just "Retiré le 12/03/2026"), and a **clock-history section**: the employee's own
  `TimeEntry` rows, most recent first, no filters needed here since it's already scoped to
  one person — reuse the row-rendering you'll build for Stage 3's table rather than
  duplicating it; Stage 3 should be written so this section can call into it directly (a
  shared widget taking `List<TimeEntry>`, not a page-only helper).
- Actions: "Modifier" → `editEmployee` route. "Retirer" → `ConfirmDialog` **naming the
  person** ("Retirer « Amélie Vandenberghe » ?" — never a generic "supprimer cet élément ?"),
  destructive style, calls `EmployeeMutations.archive`. Both fire the standard snackbar on
  success.
- Quantity/attendance is **not editable from this page** — same reasoning as item quantity
  being read-only on the edit form. If a clock time needs correcting, that's a Stage 2/3
  concern (out of scope here; don't build a manual time-entry editor unless asked).

**Tests** — new `test/employees_test.dart`, styled like `catalog_test.dart` /
`suppliers_test.dart`:
- Unique email per store; a rename doesn't collide with itself; same email in a different
  store is fine.
- `archive` sets `archivedAt`, doesn't touch `mockTimeEntries`, is refused (returns false) on
  an already-archived id.
- `update` cannot change `archivedAt` no matter what's passed.
- An archived employee is excluded from `MockQueries.activeEmployeesForStore` but still
  resolvable by `employeeById` (the detail page must still open for a retired employee's
  record).

---

## 3. Stage 2 — Pointage

- **`timeclock_board_page.dart`** — root-ish screen reached via the sidebar popup
  (`pushScreen` semantics don't apply; it's a `goSection` destination like the rest of the
  rail). Header shows today's date and a live clock, formatted through
  `core/utils/formatters.dart`'s existing `fr_BE` helpers — do not hand-format either.
  Isolate the ticking clock in its own small widget with its own `Timer.periodic` so the
  employee list beneath it doesn't rebuild every second — the list only needs to redraw on
  `mockDataRevisionProvider` changes, same as every other screen.
- `SectionTabs` at the top: *Aujourd'hui* (this board) / *Historique* (Stage 3's table),
  switching in place per assumption 5 — same callback-based usage as
  `order_detail_page.dart`.
- One card per **active** employee only (`MockQueries.activeEmployeesForStore` —
  archived employees never appear here, they have nothing to punch). Card shows
  photo/initials, name, and a `TimeEntryStatusBadge` (new widget, built the same way
  `StockStatusBadge` is: colour + distinct icon shape + label, never colour alone — this is
  a hard rule the audit script checks). Suggest grouping *not yet pointé* employees first, so
  someone finding their own card at the start of a shift doesn't have to scan the whole list
  — optional polish, not a hard requirement.
- The button, one per card, cycles through the 4 states from assumption 2:

  | Card status | Button label | Tap calls | Resulting status |
  |---|---|---|---|
  | Not clocked in | **Pointer** | `TimeclockMutations.clockIn` | En service |
  | En service | **Pause** | `TimeclockMutations.startBreak` | En pause |
  | En pause | **Reprendre** | `TimeclockMutations.endBreak` | En service |
  | En service (post-break) | **Fin de journée** | `TimeclockMutations.clockOut` | Terminé |

  Once *Terminé*, the card becomes read-only for the rest of the day: no button, just a
  summary (worked duration, overtime if any via `overtime()`, a small "Retard pause" mark if
  `isLate`). A card that reached *Terminé* must not offer *Pointer* again the same day — the
  one-entry-per-day rule from §1 enforces this at the mutation layer; the UI should simply
  reflect whatever `TimeEntryStatus` the day's entry reports, not maintain its own state.
- Standard snackbar on every successful tap, matching every other write in the app.

**Tests** — `test/timeclock_test.dart`, styled like `orders_test.dart` (the closest existing
precedent for "a status machine with rules worth pinning down"):
- `clockIn` twice same day for the same employee is refused, and the first entry is
  untouched.
- `startBreak` before `clockIn`, `endBreak` before `startBreak`, `clockOut` while `onBreak`
  are all refused — the state machine has no back door.
- A break longer than `PointageRules.maxBreakDuration` sets `isLate: true`; a shorter one
  doesn't touch it.
- `overtime()` is zero for an 8h shift and positive for a longer one; `workedDuration()`
  correctly excludes the break window.
- The seeded dataset actually contains one `isLate` entry and one with real overtime (mirrors
  how `orders_test.dart` asserts the seed covers every status the walkthrough needs).
- A reset (`MockWrite.reset()`) restores `mockTimeEntries` to the seed — this is the test that
  would have caught a forgotten `mock_write.dart` update from §1.

---

## 4. Stage 3 — Historique de pointage

Content lives behind the *Historique* tab on `timeclock_board_page.dart` (§3) — no new route,
no new sidebar entry, per assumption 5.

- Table via `DataTableWrapper` (contained horizontal scroll — the page itself must never
  scroll sideways, same rule every wide table in the app already follows). Columns: Employé,
  Date, Arrivée, Pause, Reprise, Départ, Durée travaillée, Statut (`TimeEntryStatusBadge`),
  Retard (icon-only when `isLate`, blank otherwise — not colour alone, same rule).
- Filters, `FilterPill` + `PopupMenuButton` pattern throughout:
  - Date range — check `usage_report_page.dart` / the other reports pages for an existing
    period-picker before building a new one; reuse it if one exists rather than inventing a
    second date-range control.
  - Status (`TimeEntryStatus`).
  - Employee — `SearchField`, matched case/space-insensitively the same way category and
    unit names are compared in `catalog_mutations.dart`, so "amelie" finds "Amélie" without
    demanding exact accents.
- Two empty states, same distinction the audit script checks everywhere else: no pointage
  data at all for the store vs. no rows match the current filters.
- `MockQueries` addition: `timeEntriesForStore(storeId, {DateTimeRange? range,
  TimeEntryStatus? status, String? employeeQuery})` combining all three filters — this is
  also what `EmployeeDetailPage`'s history section (§2) should end up calling with just
  `employeeQuery` fixed, rather than a second bespoke query.

**Tests** — extend `test/timeclock_test.dart` or add `test/timeclock_history_test.dart`:
- Date range boundaries are inclusive on both ends.
- Status filter and employee-name filter each work alone and combined.
- Name matching is case/space-insensitive, mirroring the exact assertions
  `catalog_test.dart` already runs for category/unit names.

---

## 5. Cross-cutting checklist (all 3 stages)

Nothing here is new — it's the existing project rules, restated so nothing is missed because
it wasn't repeated in this brief:

- Every user-facing string through `AppLocalizations`, added to `app_fr.arb` with an `@key`
  description, regenerated with `flutter gen-l10n`.
- No hardcoded colours, text styles, or spacing — `app_colors.dart` / `app_typography.dart` /
  the spacing scale only. Check `app_colors.dart` for an existing token that fits
  `TimeEntryStatus` before adding new ones (`onBreak` may well reuse the same amber the
  low-stock badge uses, for instance).
- Every list has both empty-state variants designed.
- Every destructive action confirms first and names the record.
- Every write fires the standard snackbar.
- `flutter analyze` and `flutter test` clean, `python tool/ux_audit.py` clean, before calling
  a stage done.
- `flutter run` and manually walk the new screens — same expectation the rest of the app was
  held to.
