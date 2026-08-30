# Phase 2 — Employé. Local database (drift). Staged implementation plan

## Context

Phase 2 moved the **stock side** of the app onto a local-first SQLite database (drift):
`lib/data/{database,mappers,repositories,seed,view_models}` is built, tested and merged.
`phase2.md` is that plan and its ten "As built" logs.

The **Gestion Employée** module — the roster, the pointage kiosk, the attendance history, the
paie, and the Phase 6 CIN + PIN auth / role permissions — still runs entirely on
`lib/mock_data/`. Every screen reads a global list; every write edits it; a restart wipes it.

Phase 2 — Employé does for that module exactly what Phase 2 did for stock. Same four
decisions:

| Decision | Choice |
|---|---|
| Scope | **Local DB only.** No backend, no real hashing, no network. The PIN stays a fake hash (`credential_status.dart:fakePinHash`); the session is a `meta` row, not a token. Phase 3 owns real auth. |
| Engine | **drift** — the database, the schema conventions and the tooling already exist. This adds four tables and extends one. |
| Demo data | **Kept.** `demo_seed.dart` grows: it already imports `lib/mock_data/`; it starts inserting employees, credentials, attendance and paie. |
| Tests | **Stay green throughout.** Each stage ports its own suites; the suite never goes red for more than one stage. |

The seam is one-to-one, the same shape `phase2.md` walked across:

| Today | Becomes |
|---|---|
| `MockQueries` — 12 employee/attendance/paie/credential read methods | repository reads |
| `mock_data/mutations/employee_mutations.dart` | `EmployeeRepository` writes |
| `mock_data/mutations/attendance_mutations.dart` | `AttendanceRepository` writes |
| `mock_data/mutations/payroll_mutations.dart` | `PayrollRepository` writes |
| `mock_data/mutations/credential_mutations.dart` | `CredentialRepository` writes |
| `AccountMutations.updateStoreSettings` (the hours/break/paie part) | `StoreRepository` writes (its column already partly there) |
| `MockSession` (`mock_session.dart`) | `currentEmployeeProvider` + `meta.currentEmployeeId` |

### What does NOT change

Pure functions with no data access. Reused **verbatim**, and the tests that exercise them
directly (the arithmetic groups in `attendance_test.dart` and `payroll_test.dart`, all of
`auth_test.dart`'s lockout math via `credential_status`, all of `permissions_test.dart`'s
`can()` table) keep asserting the same things:

- `lib/core/utils/employee_status.dart` — `isEmployeeActive`, `employeeDisplayName`,
  `employeeInitials`
- `lib/core/utils/attendance_status.dart` — `AttendanceRules`, `workedDuration`,
  `totalBreak`, `resolvedSchedule`, `lateBy` / `isLate`, `overtimeBy`, `breakOverrun` /
  `hasLateBreak` / `totalBreakOverrun`
- `lib/core/utils/payroll_math.dart` — `PayrollRules`, `hourlyRate`, `dayAmount`,
  `periodTotals`, `periodAmount`
- `lib/core/utils/credential_status.dart` — `AuthRules`, `fakePinHash`, `pinMatches`,
  `isValidPin`, `isLocked`
- `lib/core/utils/permissions.dart` — `Capability`, `can`, `canAccessStore`, `visibleStores`
- `lib/models/*` — stay immutable plain classes. **No drift annotations.** Drift generates
  its own row classes; mappers convert. Same promise `phase2.md` kept.

Their consumers (`_guard`, `AppSidebar`, the gated buttons) change in **one** way only: how
they get the current employee — a provider instead of the `mockCurrentEmployee` getter.

### Key constraints — the ones specific to this module

- **Attendance is date-anchored.** `attendanceForToday(employeeId)` compares against
  `dayOnly(0)` — "today", resolved when the query runs. The pointage board renders a live
  clock. `AttendanceMutations.clockIn/startPause/endPause/clockOut` each take an optional
  `now` so tests pin a timestamp between two calls. **The repository must keep that seam:**
  a `DateTime Function()` clock, defaulting to `DateTime.now`, injected in the provider and
  overridden in tests. Phase 2's `seedDemoData(db, {at})` already re-anchors seeded dates;
  this is the *query-time* clock, which is a different thing.

- **`payrollDays` is this module's `_visibleItems`** — the one read that must be rewritten,
  and the one that **cannot become pure SQL**. It iterates active employees, resolves each
  one's schedule, and per finished day computes `workedDuration` and `overtimeBy` from the
  pauses. That arithmetic lives in `attendance_status.dart` and must stay the single
  definition. Shape: one SQL query fetches the `done` attendance rows + their pauses
  (grouped), Dart folds the durations with the unchanged functions, then aggregates and
  paginates. Same call `phase2.md` made for `openOrdersForItem` — SQL for the fetch, Dart
  for the rule. `attendanceStatsForStore` has the identical shape.

- **The session must resolve synchronously.** `router.dart:_guard` reads
  `MockSession.isSignedIn` and `mockCurrentEmployee.role` on **every** navigation, inside a
  `redirect` callback that cannot await. A `FutureProvider` would make the guard async and
  break redirect ordering. So `currentEmployeeProvider` is a **`Notifier<Employee?>`
  hydrated before the first frame** in `main()` (read `meta.currentEmployeeId`, resolve the
  row, seed the state), and `signIn` / `signOut` write the `meta` row *and* the notifier in
  one step. The guard reads `ref.read(...)` — synchronous, already-resolved.

- **`MockSession` has a "default owner in tests" trick** (`mock_session.dart`: `_current`
  starts as Marc; `main()` calls `signOut()`). The DB equivalent: `db_fixture.dart` seeds
  the credentials and `meta.currentEmployeeId = employee-marc`, so widget tests get an
  authenticated owner session with no login step — the same reason `router_test` /
  `navigation_test` need no change to their bodies.

- **Route/nav tests build tables from `mockEmployees.first.id` at collection time.**
  `router_test.dart`, `navigation_test.dart` and `permissions_test.dart` reference
  `mockEmployees`, `EmployeeIds.amelie` etc. outside any test body. `EmployeeIds` are
  compile-time constants and stay — the fix is to use them, not the list. `permissions_test`
  also does `MockQueries.employeeById(EmployeeIds.amelie)` at `MockSession.signIn(...)` — that
  moves into a `setUp`.

- `analysis_options.yaml` promotes `unused_import` / `unused_local_variable` to **errors**
  and enables `unawaited_futures`. All three bite during an async migration — same as
  `phase2.md`.

- **`flutter analyze` cannot see generated code** (`app_database.g.dart` is a `part`). A
  missing import there is invisible until the tests compile the part. **Analyze passing is
  not evidence the schema compiles — run the tests.**

---

## Stage 0 — Groundwork *(S)*

**Goal:** this file, folder additions, decisions written down. No behaviour change.

1. This file is the brief. Scope, the four decisions, what stays out (real auth, hashing,
   network — Phase 3).
2. No new dependencies. drift, drift_dev, build_runner, sqlite3, uuid are all in from
   Phase 2. Keep the `drift 2.31` / `intl 0.20.2` pins — do not let a transitive bump widen
   them.
3. Folder additions (no new top-level folder — `lib/data/` is shared):
   ```
   lib/data/database/tables/employees.dart      -- Employees, EmployeeCredentials
   lib/data/database/tables/attendance.dart     -- Attendances, AttendancePauses
   lib/data/database/tables/payroll.dart        -- PayrollPeriods
   lib/data/mappers/employee_mapper.dart
   lib/data/mappers/attendance_mapper.dart
   lib/data/mappers/payroll_mapper.dart
   lib/data/mappers/credential_mapper.dart
   lib/data/repositories/employee_repository.dart
   lib/data/repositories/attendance_repository.dart
   lib/data/repositories/payroll_repository.dart
   lib/data/repositories/credential_repository.dart
   ```
   `StoreSettings` writes join `store_repository.dart` (its `stalePartialOrderDays` column is
   already there); the five pointage/paie columns are added to the existing `stores` table,
   not a new one — consistent with how `phase2.md` placed `stalePartialOrderDays`.

**Done when:** `flutter analyze` clean, `flutter test` still 100% green (nothing touched),
`dart run build_runner build --force-jit` regenerates identically.

### As built

Stage 0 is a document and two decisions; there is nothing to log that the sections above do
not already say. `paymentStatus` **derived** and `schemaVersion` **1 → 2 with a real
`onUpgrade`** are the two that constrain Stage 1 and are settled. No dependency, folder or
code change — `lib/data/` already has `database/tables/`, `mappers/` and `repositories/`.

**Verified at the stage boundary:** `flutter analyze` clean; `flutter test` 685/685 green;
`python tool/ux_audit.py` clean; `dart run build_runner build --force-jit` writes nothing new.

**Decisions to record here (each is a trap if left implicit):**

- **`schemaVersion` 1 → 2, with a real `onUpgrade`.** Phase 2's schema is committed. By the
  time this phase runs it may be on real installs, so the columns and tables arrive as a
  migration, not a v1 edit. Capture the v1 schema first: `dart run drift_dev schema dump
  lib/data/database/app_database.dart drift_schemas/`. `onUpgrade` for 1→2: `createTable`
  the four new tables, `alterTable ... addColumn` the five on `stores` with their defaults.
- **Times stay `int` minutes-since-midnight.** `Employee.scheduledStartMinutes`,
  `StoreSettings.openMinutes` are minutes-past-midnight ints today and the models are pure
  Dart on purpose (no `TimeOfDay`). SQLite `INTEGER`. A `DateTime` would be lying — these
  are times of day, not instants.
- **Durations are never stored.** `workedDuration`, `overtimeBy`, `totalBreak` are derived
  every time from `clockInAt` / `clockOutAt` / pauses. A stored duration is a second source
  of truth that drifts the moment a timestamp is corrected. Same reasoning as `StockStatus`
  never being a column.
- **New ids are UUID v4** (`lib/data/repositories/new_id.dart`, reused). Seeded ids keep
  their slugs: `employee-marc`, `att-karim-1`, `payroll-seed-karim`,
  `cred-employee-marc`. Debuggable demo.
- **`PaymentStatus` on an attendance row is derived, not stored.** Today `mock_attendances`
  carries both a `paymentStatus` field and a `payrollPeriodId`, kept in sync by hand (and a
  duplicated period-id string across files to dodge an import cycle). In SQL there is **one**
  nullable `payrollPeriodId` FK; the mapper computes
  `paymentStatus = payrollPeriodId == null ? unpaid : paid`. The `Attendance` model keeps
  its field — nothing above the mapper changes — but the database has one source of truth.

---

## Stage 1 — Schema and the new tables *(M)*

**Goal:** the four tables exist, `stores` has its five new columns, the database opens at v2.
Not wired to the app.

Files: `lib/data/database/tables/{employees,attendance,payroll}.dart`, plus edits to
`stores.dart` and `app_database.dart`.

**Four new tables:**

| Table | Notes |
|---|---|
| `employees` | `storeId` FK → stores **RESTRICT** (an establishment with staff cannot be deleted — matches the domain). `cin` **unique index**, `email` unique index — account-wide, the Phase 6 rule at the schema level. `role`, `contractType` as `textEnum`. `archivedAt` nullable (soft delete, the only delete). `scheduledStartMinutes` / `scheduledEndMinutes` nullable ints. `pay REAL`. |
| `employee_credentials` | `employeeId` FK → employees **`ON DELETE CASCADE`** (no employee, no PIN). `employeeId` unique (one credential each). `pinHash TEXT`, `failedAttempts INTEGER DEFAULT 0`, `lockedUntil` / `lastLoginAt` nullable `DateTime`. |
| `attendances` | `employeeId` FK **CASCADE**, `storeId` FK **CASCADE**. `date` (midnight-normalised). **Unique index `(employeeId, date)`** — one row per employee per day, the `mock_data_test` invariant becomes a constraint. `status` textEnum. `clockInAt` / `clockOutAt` nullable. `payrollPeriodId` FK → payroll_periods **`ON DELETE RESTRICT`** (a paid period cannot be deleted out from under its days) — nullable, null meaning unpaid. |
| `attendance_pauses` | child table of `attendances`. `attendanceId` FK **CASCADE**, `position INTEGER` (ordered list → column, the lesson from `phase2.md` stage 3's order/receipt lines), `startAt`, `endAt` nullable (null = running). |
| `payroll_periods` | `employeeId` FK **CASCADE**, `storeId` FK **CASCADE**, `paidByEmployeeId` — **no FK** (the owner who paid may later be archived; the row keeps their id and renders their name, same pattern as `stock_movements.supplierId`). `status` textEnum. `appliedRate REAL`, `computedAmount REAL`, totals `REAL`, `workedDays INTEGER`. |

**Five columns on `stores`** (this is where the rest of `StoreSettings` lands — the model's
`storeId` + these six is the whole thing, and `stalePartialOrderDays` is already a column):

`openMinutes INTEGER DEFAULT 480`, `closeMinutes INTEGER DEFAULT 1020`,
`maxBreakMinutes INTEGER DEFAULT 30`, `overtimeMultiplier REAL DEFAULT 1.25`,
`workingDaysPerMonth INTEGER DEFAULT 26`. Defaults are the `AttendanceRules.*` /
`PayrollRules.*` constants — reference them in a comment so a drift-time change and a
constant change cannot silently disagree.

Also in this stage:

- `TypeConverter` via `textEnum<T>()` for `EmployeeRole`, `ContractType`, `AttendanceStatus`,
  `PaymentStatus`, `PayrollStatus`. Name string, never index.
- Indexes: `employees(storeId)`, `employees(cin)` (unique), `employees(email)` (unique),
  `attendances(employeeId, date)` (unique), `attendances(storeId, date DESC)`,
  `payroll_periods(employeeId, paidAt DESC)`, `payroll_periods(storeId, paidAt DESC)`,
  `attendance_pauses(attendanceId, position)`.
- The v1 → v2 migration in `MigrationStrategy.onUpgrade`, and `drift_schemas/` gains the v2
  dump.

**Done when:** `dart run build_runner build --force-jit` regenerates
`app_database.g.dart`; a new `test/db/employee_schema_test.dart` opens
`AppDatabase.memory()`, asserts all 20 tables exist, `foreign_keys` on, that a second
attendance row for the same `(employeeId, date)` throws, that a duplicate CIN throws, that
deleting an employee cascades their credential and attendance but a paid `payroll_periods`
row blocks the delete; and a migration test seeds a v1 DB and upgrades it.

---

## Stage 2 — Mappers and seed *(M)*

**Goal:** the database can be filled with the employee demo data. The UI still reads mocks.

1. `lib/data/mappers/{employee,attendance,payroll,credential}_mapper.dart` — pure
   `Employee employeeFromRow(EmployeeRow)` / `EmployeesCompanion employeeToRow(Employee)`,
   one file per aggregate. `attendanceFromRows(row, pauseRows)` rebuilds the embedded pause
   list, sorted by `position`. `store_mapper.dart` extends to carry the five new columns
   into `StoreSettings` (and the six-field `StoreSettings` back).
2. `demo_seed.dart` extends: after `stores` and before `notifications`, insert `employees`
   → `employee_credentials` → `payroll_periods` → `attendances` → `attendance_pauses`, in
   FK order, in the **same transaction**. Source is still `lib/mock_data/`
   (`mockEmployees`, `mockCredentials`, `mockPayrollPeriods`, `mockAttendances`,
   `mockStoreSettings`). Dates shift by `at - mockNow` like every other seeded date — which
   is what makes "Karim clocked in 7:45 today" land on the seed instant's day.
   - `mockStoreSettings` merges into the `stores` insert — `storeToRow(store, settings)`.
     `AccountMutations.createStore` seeds a default settings row today; the repository's
     `createStore` writes the column defaults.
3. `clearAllData` gains the five deletes in reverse FK order (pauses → attendances →
   payroll_periods → credentials → employees), before `stores`.
4. `db_fixture.dart` (`openSeededDatabase`) already seeds everything the seed writes — it
   gains `meta.currentEmployeeId = EmployeeIds.marc` so a seeded DB is "signed in as the
   owner", the fixture equivalent of `MockSession`'s default.

**Tests ported in this stage:** the employee/credential/attendance/payroll assertions in
`mock_data_test.dart` → a new group in `test/db/employee_seed_test.dart`: every employee
resolves to a real store, CIN and email unique across the roster, every owner and manager
has a credential, one attendance row per employee per day, a paid attendance day carries a
`payrollPeriodId` and every id it names exists, one archived employee present, TestCalcul's
two people and their July history present. The ones that are now **DB constraints** (CIN
unique, `(employeeId, date)` unique, credential FK) get a "the schema enforces this" test
instead of a "the data happens to satisfy it" test.

**Done when:** `flutter test` green (old suites untouched, seed suite extended), and the
seeded DB matches the employee dataset the demo path relies on.

---

## Stage 3 — Read repositories *(L)*

**Goal:** every employee-module `MockQueries` method has a repository equivalent. Nothing in
`lib/features/` calls them yet.

Shape, same rules as `phase2.md` stage 3:

- **List reads return `Stream<List<T>>`** via `.watch()` — this is what replaces
  `mockDataRevisionProvider` for the roster, the pointage board and the two history tables.
- **Single reads by id return `Stream<T?>`** where a screen watches one record
  (`employee_detail_page`), `Future<T?>` where a form reads once.
- **Pure predicates stay synchronous and stay where they are** — everything in
  `attendance_status.dart` / `payroll_math.dart` / `permissions.dart` operates on
  already-loaded objects. Do not turn them into repository calls.

Split by aggregate: `employee_repository`, `attendance_repository`, `payroll_repository`,
`credential_repository`; `store_repository` gains the full `StoreSettings` read.

Queries that must be **rewritten rather than translated**:

| Today | Becomes |
|---|---|
| `attendancesForStore` — filters (`from`/`to`/`status`/`employeeId`), sorts, then `.sublist()` a page **in Dart over the whole list** | one query: `WHERE` for each filter, `ORDER BY date DESC, clockInAt DESC`, `LIMIT`/`OFFSET`, plus a `COUNT(*)` for the pager |
| `attendanceStatsForStore` — walks the filtered rows, resolving each employee's schedule and folding `workedDuration` / `overtimeBy` / `isLate` per row | SQL fetches the rows + pauses in the range; Dart folds the durations with the **unchanged** `attendance_status.dart` functions. Not pure SQL — the arithmetic stays one definition. |
| `payrollDays` — iterates active employees, clamps the range to each hire date, resolves each schedule, computes worked/overtime per `done` day, counts paid/unpaid, paginates | one query per: `done` attendance rows + pauses for the store's active employees in `[from,to]`, `date >= hireDate` in SQL; Dart resolves schedules and folds durations; paid/unpaid counts from `payrollPeriodId IS NULL`; pagination on the filtered result. **This is the single hardest read in the phase.** |
| `attendanceForToday(employeeId)` — `firstWhere` over the whole list against `dayOnly(0)` | `WHERE employeeId = ? AND date = ?` with `?` = `dayOnly(clock())` — the injected clock, not `DateTime.now()` inline |
| `payrollPeriodsForStore` — employee-name search + rolling `withinDays`, then Dart page | `JOIN employees` for the name filter, `WHERE paidAt >= ?`, `ORDER BY paidAt DESC`, `LIMIT`/`OFFSET` |

Ordering contracts, now explicit `ORDER BY` (tests depend on them):

- `attendancesForEmployee` — **most recent day first**, `date DESC` then `clockInAt DESC`.
- `attendancesForStore` — same, and the `clockInAt` tiebreak matters: a store's board seeds
  several rows on the same day.
- `payrollPeriodsForEmployee` / `…ForStore` — **most recent `paidAt` first**, `id` tiebreak
  (like `phase2.md`'s movements — several periods can be paid in one sitting in a test).
- `attendance_pauses` — **by `position`**, always. A running pause is last.

**The checklist — `MockQueries` → repositories** (Stage 9 uses this):

| `MockQueries` | Replacement |
|---|---|
| `employeesForStore` | `EmployeeRepository.employees / watchEmployees` |
| `activeEmployeesForStore` | `EmployeeRepository.activeEmployees / watchActiveEmployees` |
| `employeeById` | `EmployeeRepository.employee / watchEmployee` |
| `employeeByCin`, `employeeByEmail` | same names on `EmployeeRepository`, `{excludingId}` kept |
| `credentialForEmployee` | `CredentialRepository.forEmployee` |
| `attendanceById` | `AttendanceRepository.attendance` |
| `attendanceForToday` | `AttendanceRepository.today(employeeId) / watchToday` — takes the clock |
| `attendancesForEmployee` | `AttendanceRepository.forEmployee / watchForEmployee` |
| `attendancesForStore` | `AttendanceRepository.page(...)` — the record shape stays `(rows, totalCount, page, pageCount)`; `watchPage` for the live table |
| `attendanceStatsForStore` | `AttendanceRepository.stats(...)` — `Future`, the KPI header reads once per filter change |
| `payrollPeriodById` | `PayrollRepository.period` |
| `payrollPeriodsForEmployee` | `PayrollRepository.forEmployee / watchForEmployee` |
| `payrollPeriodsForStore` | `PayrollRepository.page(...)` |
| `payrollDays` | `PayrollRepository.days(...)` — same record shape, `watchDays` for the table |
| `storeSettings` | `StoreRepository.settings / watchSettings` — now the full six-field `StoreSettings` |

**Two display lookups have no counterpart, on purpose:** `employeeDisplayName` and
`employeeRoleLabel` operate on a loaded `Employee` and stay synchronous. `employee_detail`'s
"who paid this period" resolves `paidByEmployeeId` — that becomes a joined column on a
`PayrollPeriodView`, not a query per row (the shape Stage 9 must avoid).

**Tests:** new `test/db/employee_queries_test.dart` — seed at a fixed instant, then assert
each repository figure against the same expectations the current `MockQueries` tests use.
Where `MockQueries` is still present and correct, assert the repository *against the mock*,
not against a hand-computed number — the method `phase2.md` stage 3 used, for the same
reason: the two implementations must agree on everything not wall-clock-dependent.

**Done when:** every employee-module `MockQueries` member has a repository counterpart and
the checklist above maps them one-to-one.

---

## Stage 4 — Employee and credential writes *(M)*

**Goal:** the identity aggregates write for real, and login works against the database.

- `employee_repository`: `create`, `update`, `archive`, `restore`. CIN + email unique
  account-wide (self-excluded on update), required fields non-empty, `archivedAt` **not** an
  `update` parameter (archiving is its own method — the audit-relevant transition off the
  routine form, same as `phase2.md`'s item `quantity`). `archive` / `restore` refuse the
  wrong prior state (returns `false`). Delete: **there is none** — soft-remove only.
- `credential_repository`: `setPin`, `recordFailedAttempt`, `recordSuccessfulLogin`,
  `unlock`, `authenticate`. `authenticate(cin, pin, {now})` composes the primitives and
  returns `LoginAttempt(outcome, employee?)` — `LoginOutcome` unchanged. Lockout after
  `AuthRules.maxFailedAttempts`, `lockedUntil = now + AuthRules.lockoutDuration`. Staff with
  the right PIN → `noAppAccess`, counters untouched. **`authenticate` does not touch the
  session** — the login screen (Stage 9) signs in on `success`.
- **`create` + `setPin` in one transaction.** The add-employee form creates the person and
  their PIN in one submit; an employee row with no credential is somebody who cannot sign
  in, which reads as a bug. The repository exposes `create({..., pin})` and does both, or
  the form calls two repo methods inside `db.transaction` — decide by which keeps the
  return-value contract cleanest (`Future<Employee?>`).

**Return-value contract must survive.** `add_edit_employee_page.dart` branches
`if (result == null)` synchronously today. Keep `Future<Employee?>`, `Future<bool>`,
`Future<LoginAttempt>`.

**Tests ported:** `employees_test.dart` (12) → `test/db/employees_test.dart`; `auth_test.dart`
(10) → `test/db/auth_test.dart`. Same names, same assertions, repository calls instead of
`XMutations`, `setUp` opens a seeded in-memory DB. The lockout-timing tests keep pinning
`now`. **Delete the originals in the same commit** — keeping both green is impossible once
the write path forks.

Add the `ux_audit.py` check (mechanical guard, written now while the replacement is being
built): only `credential_repository.dart` may write `employee_credentials`; only
`employee_repository.dart` may write `employees`.

**Done when:** both ported suites green, originals deleted, `flutter analyze` clean.

---

## Stage 5 — The attendance repository *(M)*

**Goal:** the pointage writes, transactional, with an injectable clock.

`attendance_repository.dart` — `clockIn`, `startPause`, `endPause`, `clockOut`,
`lockForPayroll`. Each refuses the wrong prior state (returns `null` / `false`), exactly as
`AttendanceMutations` does, and **refuses any write against a day whose `payrollPeriodId` is
set** — a paid day is immutable.

Rules carried over exactly:

- `clockIn` refuses if a row already exists for `(employeeId, dayOnly(clock()))` — now a
  unique-constraint catch as well as a check.
- `startPause` needs `working`; `endPause` needs `onBreak` and an open pause; `clockOut`
  needs `working` (refuses mid-break).
- Pauses are a child table: `startPause` inserts a pause row at `position = count`;
  `endPause` updates the open one. **The write goes through the typed API** —
  `customStatement` does not notify streams (`phase2.md` stage 3, item 1), and the board
  watches these.
- `lockForPayroll(attendanceIds, periodId)` — called **only** by `PayrollRepository.pay`,
  inside its transaction. Sets `payrollPeriodId` and (if `paymentStatus` is stored) flips
  it. Refuses (whole call, touches nothing) if any id is missing or already paid.

**The clock.** `AttendanceRepository({required DateTime Function() now})`. The provider
supplies `DateTime.now`; `db_fixture.dart` supplies a fixed function so a test can clock in
at 07:45 and clock out at 17:00 without wall-clock time passing. Every method takes an
optional `now` override on top, mirroring `AttendanceMutations` — a test that needs two
different instants in one method chain.

**Concurrency note that did not exist in Phase 1:** `startPause` reads the pause count then
inserts at that position — inside the transaction, not read-outside-written-inside. A
double-tapped Pause button is now genuinely concurrent futures. Add the test that fires two
`startPause` at one row with `Future.wait` and asserts exactly one pause was appended — and
verify it has teeth the way `phase2.md` stage 5 did (break it on purpose, watch it fail,
revert).

**Tests ported:** `attendance_test.dart` (23) → `test/db/attendance_test.dart`. The
`workedDuration` / `overtimeBy` / `hasLateBreak` arithmetic groups do not change — they
already take an `Attendance` object; they now get one built from rows. Delete the original.

**Done when:** ported suite green, original deleted, the concurrency test proven.

---

## Stage 6 — The payroll repository *(L — the hardest stage)*

**Goal:** the paie, transactional, and `payrollDays` as real SQL + Dart.

`payroll_repository.dart` — `preview`, `pay`, `days`. Plus the two paginated reads from
Stage 3 (`page`, `forEmployee`) if not already landed there.

**`pay` is the reason this is its own stage.** Today it is: compute totals → create the
`PayrollPeriod` → flip every covered `Attendance` to `paid` + stamp `payrollPeriodId`, as
sequential list edits that cannot half-fail. As SQL it is **one transaction**:

1. `_payableDays(employeeId, storeId, from, to)` — `done`, unpaid, `date >= hireDate`,
   in range;
2. `periodTotals` / `periodAmount` over those days, using the **unchanged** `payroll_math.dart`
   (which needs the pauses — fetched with the days);
3. insert the `PayrollPeriod` (`status: paid`, `appliedRate` frozen from `Employee.pay`,
   `paidAt` / `paidByEmployeeId` stamped);
4. `AttendanceRepository.lockForPayroll(dayIds, periodId)` **inside the same transaction**;
5. if any day slipped to `paid` between the preview and here, the whole thing rolls back and
   `pay` returns `null`.

If any step throws, nothing is written. **Acceptance test:** `pay` a range where one day is
concurrently marked paid → `PayrollPeriod` count, every attendance's `paymentStatus`, and
the totals are **completely** unchanged. Prove it has teeth (remove the transaction, watch a
half-paid period, revert).

**`days` — the rewrite.** Same record shape as today
(`rows, paidDays, unpaidDays, worked, overtime, totalCount, page, pageCount`). SQL fetches
the `done` attendance rows + pauses for the store's active employees, `date >= hireDate` and
in `[from, to]`, ordered `date DESC, employeeId`. Dart resolves each employee's schedule
(`resolvedSchedule` with the store settings) and folds `workedDuration` / `overtimeBy` per
row. `paidDays` / `unpaidDays` are `COUNT` on `payrollPeriodId IS NULL` and are **over the
whole range**, independent of the status filter — the KPI numbers stay visible whatever the
table is filtered to. Pagination on the filtered rows.

`preview` — pure computation over `_payableDays`, persists nothing. `Future<PayrollPreview>`.

**Tests ported:** `payroll_test.dart` (20) → `test/db/payroll_test.dart`. The `hourlyRate` /
`dayAmount` groups do not change. The `pay` / `preview` / `days` groups get the seeded DB and
the fixed instant. Plus the rollback test. `payroll_history_page_test.dart` (4, widget)
moves to Stage 9. Delete the original.

**Done when:** ported suite green, rollback test proven, original deleted. **At the end of
Stage 6 the entire employee data layer is done and tested, and the app still runs on
mocks** — same deliberate low-risk boundary as `phase2.md` stage 7.

---

## Stage 7 — Store settings and the session *(S)*

- `store_repository.dart`: `updateStoreSettings(storeId, {openMinutes, closeMinutes,
  maxBreakMinutes, overtimeMultiplier, workingDaysPerMonth})` — one `UPDATE stores`, each
  field null = leave, a nonsense value (negative, time ≥ 1440, multiplier < 1) ignored not
  refused (the forgiving stance the settings screen takes today). `settings(storeId)`
  returns a synthesised default when — impossible but cheap to handle — the row is missing.
- `meta.currentEmployeeId` — the session, backed by a `meta` row. Nullable: absent /
  cleared = signed out. `CredentialRepository` or a small `SessionRepository` owns
  `signIn(employeeId)` (write the row) and `signOut()` (delete it).
- **`currentEmployeeProvider`** — a `Notifier<Employee?>`. `build()` reads
  `meta.currentEmployeeId`, resolves the employee row, returns it (or null).
  `signIn` / `signOut` write the meta row **and** `state = ...` in one step, so a screen
  reacts and the guard's next `ref.read` is already correct. Hydrated before the first frame
  (`main()` awaits it), so `_guard` never sees a loading state.

**Tests ported:** the store-settings assertions from `account_test.dart` /
`mock_write_test.dart` → `test/db/store_settings_test.dart` (a Sablon settings edit persists,
a re-seed restores it, `liege` is unaffected). A session test: `signIn` then `signOut`
leaves `meta` with no `currentEmployeeId`; a fresh open with a stored id resolves the
employee; a stored id pointing at an archived employee still resolves (archiving does not
sign you out — Phase 3's problem).

**Done when:** settings persist, the session round-trips, the data layer is complete.

---

## Stage 8 — Provider layer *(M)*

**Goal:** the bridge between the four repositories and the widgets, built and tested before a
screen is touched.

- `lib/data/providers.dart` gains: `employeeRepositoryProvider`,
  `attendanceRepositoryProvider` (with the clock), `payrollRepositoryProvider`,
  `credentialRepositoryProvider`; `storeRepositoryProvider` already exists.
- `StreamProvider.family` per screen-level query, keyed on `storeId` or `employeeId` (or a
  small record for `attendancesForStore`'s filter bundle). Maps one-to-one onto the call
  sites — every query already takes `storeId` or `employeeId` first.
- **`currentEmployeeProvider`** (Stage 7) is registered here and hydrated in `main()`
  alongside `openAppDatabase()`, before `runApp`.
- **`_guard` reads the session synchronously.** It becomes a small function that takes a
  `Ref` (or reads a plain top-level mirror the notifier keeps in sync) — `ref.read
  (currentEmployeeProvider)` returns the already-resolved `Employee?`. `can(...)`,
  `canAccessStore(...)`, `visibleStores(...)` are unchanged; they just receive the provider
  value instead of `mockCurrentEmployee`.
- The `AsyncValue` house rule from `phase2.md` stage 8 applies: `data` → screen,
  `loading` → `SkeletonList` / `SkeletonGrid` matching the layout, `error` → `ErrorState`
  with a retry that invalidates. One helper widget.

**Done when:** a widget test pumps an employee screen against an in-memory DB, asserts
skeleton → data; a test asserts `_guard` redirects a signed-out session to `/login` and a
manager away from another store's routes — the `permissions_test` guarantees, now against
the provider.

---

## Stage 9 — Screen cutover *(L)*

**Goal:** every file under `lib/features/employees/`, `lib/features/auth/`, the store-settings
page, and the shell widgets that read the session, go through repositories. The mock layer
is unreachable from the UI.

**Be honest about this stage:** the app compiles but is not coherent until the last screen
lands. One branch, one merge. Order (dependency-light first):

| Order | Feature / file | Notes |
|---|---|---|
| 1 | `auth/login_page.dart`, `forgot_password_page.dart` | `_signIn` → `credentialRepository.authenticate` → `sessionRepository.signIn` on success; destination still `spanAllStores ? /stores : toDashboard(storeId)` |
| 2 | shell: `app_top_bar.dart` (`_AccountButton`, logout → `signOut`), `store_switcher.dart` / `store_selector_page.dart` (`visibleStores` off `currentEmployeeProvider`), `app_sidebar.dart` (`can(role, child.capability)` off the provider), `router.dart:_guard` | the session reads |
| 3 | `employees/employees_list_page.dart` | roster + KPI row, `watchEmployees` / `watchActiveEmployees` |
| 4 | `employees/add_edit_employee_page.dart` | `ConsumerStatefulWidget`, `await` create/update + setPin; `if (!mounted) return;` before the snackbar |
| 5 | `employees/employee_detail_page.dart` | `watchEmployee`, the attendance section (`watchForEmployee`), the payroll section (`watchForEmployee` on periods) — the "who paid" lookup uses the joined `PayrollPeriodView`, not a query per row |
| 6 | `employees/timeclock_board_page.dart` | the kiosk. `watchActiveEmployees` + `watchToday` per card — or one `watchBoard(storeId)` view-model that joins today's row per employee (**preferred** — 8 cards × a stream each is the row-query shape to avoid). Live clock unchanged. `isFullScreenProvider` unchanged. |
| 7 | `employees/attendance_history_page.dart` | `watchPage(filterBundle)` for the table, `stats(filterBundle)` future for the KPI header, the detail side-panel reads the already-loaded row |
| 8 | `employees/payroll_history_page.dart` | `watchDays(...)`, the "Payer" flow: `preview` future → `ConfirmDialog` → `pay` → snackbar. `paidByEmployeeId` = `currentEmployeeProvider`'s id |
| 9 | `settings/store_settings_page.dart` | the pointage/paie section reads `watchSettings`, `_save` → `updateStoreSettings`; the `editStoreSettings` gate unchanged |

Three shapes of work (same as `phase2.md` stage 9):

1. **`ConsumerWidget` screens** — drop `ref.watch(mockDataRevisionProvider)`, watch the
   stream provider, render the `AsyncValue`. Mechanical.
2. **Leaf widgets that query in `build()` with no `ref`** — the timeclock card, the
   attendance row, the payroll row. **Do not** make each a `FutureBuilder`. Give the list a
   **view-model** built by one joined query (`AttendanceRowView` carrying the employee name
   + resolved schedule marks; `TimeclockCardView` carrying today's row per employee). This
   is the largest chunk.
3. **Forms** — `ConsumerStatefulWidget`, `await` the repo call, `if (!mounted) return;`
   before the snackbar/pop. Grep for the missing `mounted` check as an acceptance criterion.

**Widget test suites in this stage:**

- `router_test.dart`, `navigation_test.dart`, `permissions_test.dart`,
  `payroll_history_page_test.dart` get a `setUp` that opens `AppDatabase.memory()`, seeds it,
  and pumps `ProviderScope(overrides: [databaseProvider.overrideWithValue(db),
  currentEmployeeProviderOverride])`.
- The three route-table builders that read `mockEmployees.first.id` / call
  `MockQueries.employeeById` at collection time → `EmployeeIds.*` constants and a `setUp`.
- `permissions_test`'s `MockSession.signIn(manager)` → `sessionRepository.signIn` in `setUp`,
  `tearDown` back to the seeded owner.
- Run `router_test` at all three viewports against the **skeleton** state too — the pointage
  board and the two history tables are new layouts.

---

## Stage 10 — Teardown, tooling and docs *(M)*

1. **Delete the employee mock layer:**
   `mock_employees.dart`, `mock_attendances.dart`, `mock_payroll_periods.dart`,
   `mock_credentials.dart`, `mock_store_settings.dart`, `mock_session.dart`, and
   `mutations/{employee,attendance,payroll,credential}_mutations.dart`. Remove
   `AccountMutations.updateStoreSettings` (its store creation already left in `phase2.md`
   stage 7). Delete the employee blocks from `mock_queries.dart` — after Phase 2's stage 10
   this file is likely already gone; if so, this phase's Stage 3 added the blocks to the
   still-living file and Stage 10 deletes the file with `phase2.md`'s teardown, or this
   phase deletes it. `unused_import: error` makes the removal self-policing.
   - Move the employee dataset (`mockEmployees` etc.) to `lib/data/seed/dataset/` — demo
     fixtures now, not an app layer.
   - `mock_data.dart` barrel loses the six exports.
2. **`test/mock_write_test.dart`** — remove `mockEmployees` / `mockAttendances` /
   `mockPayrollPeriods` / `mockCredentials` from `_snapshotCounts` and `_mutableLists`. If
   the file is empty after `phase2.md`'s teardown, it is already gone.
3. **`tool/ux_audit.py`** — the "written outside the mutation layer" checks already point at
   `lib/data/repositories/` after `phase2.md`. Add the employee-specific guards from Stage 4
   permanently: `employees` table written only by `employee_repository.dart`,
   `employee_credentials` only by `credential_repository.dart`, `attendances` /
   `attendance_pauses` only by `attendance_repository.dart`,
   `payroll_periods` only by `payroll_repository.dart` (and `attendance_repository` for the
   `payrollPeriodId` lock — same allow-list shape as movement/order).
4. **Docs.** `phase2-employee.md` gets its ten "As built" sections. `README.md` — the
   employee module joins "the app persists". `DOMAIN_MODEL.md` — the "Where this lives"
   table repointed at the four repositories. `.claude/phase_gestion_employee.md` — a closing
   note that Phase 2's storage seam has been crossed for this module too.

---

## Verification

Run at the end of every stage, not only at the end:

```powershell
flutter analyze                 # unused_import and unawaited_futures are ERRORS here
flutter test                    # green at every stage boundary
python tool/ux_audit.py         # from the repo root
dart run build_runner build --force-jit
```

End-to-end by hand, once Stage 9 lands — the pointage / paie walkthrough with the step that
could not exist before:

1. Launch → login with the owner's CIN + `1234` → store grid → **Brasserie du Sablon**.
2. **Gestion Employée → Tableau de pointage** → clock Karim in, take a pause, resume,
   clock out.
3. **Historique de pointage** → Karim's finished day is there with worked hours and any
   overtime.
4. **Historique de paiement** → pick Karim → **Payer** the shown range → confirm.
5. **Kill the app completely and relaunch.** Karim's clock-out, and the paid period, are
   still there. *This is the whole point.*
6. Sign out → sign in as a **manager** (created in step earlier, PIN set) → "Gestion
   Employée" shows only Tableau de bord + Historique pointage; `/employees` typed by hand
   → back to the dashboard; **Paramètres → Établissement** shows but "Enregistrer" is
   disabled.
7. Sign in as a **staff** account → "Ce compte n'a pas accès à l'application".
8. **Réinitialiser la démonstration** → back to the seed, relaunch confirms the reset
   persisted.
9. Rotate to portrait, reopen the pointage board — new skeleton layout, `router_test`
   covers the frame but the skeleton is new.

---

## Risks, in the order they will actually bite

| Risk | Mitigation |
|---|---|
| `payrollDays` / `attendanceStatsForStore` forced into pure SQL, forking `attendance_status.dart` | SQL for the fetch, Dart for the arithmetic — stated in Stage 3 and 6, tested against `MockQueries` |
| `_guard` made async by a `FutureProvider` session → redirect races | `currentEmployeeProvider` is a `Notifier`, hydrated before the first frame; guard does `ref.read`, never `watch` an unresolved value |
| Attendance "today" drifting between seed instant and query instant | Injected clock in `AttendanceRepository`; `db_fixture.dart` pins it |
| Widget-test route tables reading `mockEmployees.first.id` at collection time | Fixed `EmployeeIds.*` constants + a `setUp`, not a `setUpAll` |
| `pay` half-applying (period created, days not locked) | One transaction + an explicit rollback test, proven by breaking it |
| Stage 9 a long incoherent branch | Strict file order, `flutter analyze` green at every commit, one merge |
| `customStatement` not notifying the board's streams | Every write through the typed API or `customUpdate(updates: {table})` — the lesson is already in `phase2.md` |
| Schema already committed → columns cannot be a v1 edit | `schemaVersion` 1 → 2, real `onUpgrade`, v1 dump captured first |
| Scope creep into real auth | fake hash, `meta`-row session, no token. Phase 3. |
