# Phase 2 — Local database (drift). Staged implementation plan

## Context

The app is a demo-ready prototype. Every screen renders from `lib/mock_data/`, and every
write edits a global mutable list that a hot restart wipes. Phase 1.7 finished the write
layer, so the *rules* are complete and pinned by ~390 tests — what is missing is storage.

Phase 2 replaces the in-memory layer with a **local-first SQLite database (drift)** so the
app keeps its data across restarts and becomes something a kitchen can actually use.
Decisions taken before writing this plan:

| Decision | Choice |
|---|---|
| Scope | **Local DB only.** `sync_service`, `api_service`, `auth_service` stay stubs for Phase 3 |
| Engine | **drift** (SQLite) — real FKs, joins for the reports, transactions for receiving, `watch()` streams for live UI |
| Demo data | **Kept.** First launch seeds from the current mock dataset; Settings keeps *Réinitialiser la démonstration* (wipe + re-seed) |
| Tests | **Stay green throughout.** Each stage ports its own suites; the suite never goes red for more than one stage |

The seam this migration walks across already exists and is one-to-one:
`MockQueries` (57 read methods) → repository reads, and the six files in
`mock_data/mutations/` → six repositories. `lib/mock_data/mutations/mock_write.dart:24`
says so in its own doc comment.

### What does NOT change

These are pure functions with no data access. They are reused **verbatim** and their tests
(`stock_cost_test.dart`, 23 tests) do not move:

- `lib/core/utils/stock_cost.dart` — CUMP weighted-average arithmetic
- `lib/core/utils/order_status.dart` — every order/receipt derivation + `OrderRules`
- `lib/core/utils/stock_status.dart` — `stockStatusOf`, `needsAttention`
- `lib/models/*` — stay immutable plain classes. **No drift annotations on them.** Drift
  generates its own row classes; mappers convert. This is what `DOMAIN_MODEL.md` and the
  Phase 1 brief promised, and it keeps the models usable by the PDF layer and by Phase 3.

### Key constraints

- **All ids are `String`** (`item-tomates`, `item-new-7`) and appear in route paths. Keep
  `String` PKs (`TextColumn().withLength()` + primary key). An `int` autoincrement PK would
  break every route, every `xById`, and the seed.
- **Nothing in `lib/` is async today.** Zero `FutureBuilder`/`StreamBuilder`/`AsyncValue`.
  23 screens call `ref.watch(mockDataRevisionProvider)` then read synchronously; ~20 forms
  are plain `StatefulWidget` with no `ref` at all.
- `LoadingState`, `SkeletonList`, `SkeletonGrid`, `ErrorState` are **already designed and
  unused** (`lib/shared/widgets/`). Phase 2 is the wiring, not the design.
- `analysis_options.yaml` promotes `unused_import` and `unused_local_variable` to **errors**
  and enables `unawaited_futures` — both bite hard during an async migration.
- `router_test.dart` / `navigation_test.dart` build their route tables from
  `mockItems.first.id` **at test-collection time**, outside any test body. That cannot be
  awaited and must become fixed fixture ids.

---

## Stage 0 — Groundwork *(S)*

**Goal:** dependencies in, folders in, decisions written down. No behaviour change.

1. This file is the Phase 2 brief, the way `.claude/phase1.md` was Phase 1's: scope, the
   four decisions above, and what stays out (sync, API, auth, encryption).
2. `pubspec.yaml`:
   - dependencies: `drift`, `drift_flutter`, `uuid` (see *As built* 1 — not
     `sqlite3_flutter_libs`, `drift_flutter` brings it)
   - dev_dependencies: `drift_dev`, `build_runner`, `sqlite3` (for tests)
   - leave `intl: 0.20.2` pinned — do not let a transitive bump widen it.
3. `analysis_options.yaml` — add `**/*.drift.dart` beside the existing `**/*.g.dart`
   exclude, so generated code never trips `prefer_const_constructors` or `unused_import`.
4. Create the folder skeleton (empty, with a README each):
   ```
   lib/data/
     database/      app_database.dart, tables/, converters/, migrations/
     mappers/       one file per aggregate: row <-> model
     repositories/  one file per aggregate, mirroring mock_data/mutations/
     seed/          demo dataset loader
   ```
   Feature folders keep `presentation/` only — repositories are shared across features
   (an item is read by inventory, orders, reports and search alike), so a central
   `lib/data/` is the honest structure, not `features/*/data/`.

**Done when:** `flutter pub get` and `flutter analyze` are clean, `flutter test` still 100%
green (nothing has been touched yet), and `dart run build_runner build --force-jit` runs
with no inputs.

**Decisions to record here (each is a trap if left implicit):**

- **Money stays `double` / SQLite `REAL`.** Integer cents would be more correct but would
  rewrite `stock_cost.dart`, every model, and 23 arithmetic tests for a precision problem
  the existing `costEpsilon = 0.001` comparisons already absorb. Written down so it is a
  decision, not an oversight.
- **New ids are UUID v4** (`uuid` package), seeded ids keep their readable slugs.
  `MockWrite.id('item')` → `item-new-7` is process-local and collides across restarts the
  moment data persists. Slug ids in the seed stay, because they make the demo debuggable.
- **`schemaVersion: 1` from the start**, with a real `MigrationStrategy` and drift's schema
  dump discipline (`dart run drift_dev schema dump`) adopted immediately — Phase 3 will add
  columns, and the habit is free now and expensive to retrofit.

### As built — four things the plan did not know

Stage 0 is done. Four facts came out of the actual dependency resolution, and each one
changes an instruction later in this document.

**1. `sqlite3_flutter_libs` is not a direct dependency.** `drift_flutter` already depends on
it, and naming it here as well would be noise. Its `0.6.0+eol` release is an empty package —
from `package:sqlite3` 3.x the native library arrives through Dart build hooks instead — but
we are not on 3.x (see 2), so the real `0.5.42` is what resolved and what bundles SQLite into
the app. `flutter pub get` registered it in the Windows, Linux and macOS plugin registrants,
which is the confirmation that it did.

**2. drift is held at the 2.31 line, and it is Flutter that holds it.** `drift_dev` above
2.31 wants `analyzer >= 10`, which wants `meta ^1.18`; the Flutter SDK pins `meta 1.17.0`.
So drift 2.34 is simply not installable here. Resolved: drift 2.31.0, drift_dev 2.31.0,
drift_flutter 0.2.8, sqlite3 2.9.4, build_runner 2.15.1, uuid 4.6.0. The constraint is
commented in `pubspec.yaml`, next to the `intl` pin it now keeps company with. **Raise it
only together with a Flutter upgrade, and never in the middle of a stage.**

**3. The generator must run in JIT mode: `dart run build_runner build --force-jit`.**
`path_provider_foundation` (pulled in by `drift_flutter` → `path_provider`) depends on
`objective_c`, which ships a build hook, and `dart compile` refuses to AOT-compile a build
script whose graph contains one — build_runner fails outright rather than falling back to
JIT on its own. `--delete-conflicting-outputs` is also gone in build_runner 2.15 and is now
ignored with a warning. Every `build_runner` line in this document has been corrected to the
working form; use it, because the error the AOT path produces
(`'dart compile' does not support build hooks`) points nowhere near the cause.

**4. Because sqlite3 stayed on the 2.x line, the Windows test gotcha in Stage 1 is real.**
Had drift pulled sqlite3 3.x, hooks would have bundled the library for `flutter test` too and
that whole problem would have evaporated. It did not. `sqlite3: ^2.9.4` is therefore a dev
dependency, and `test/support/sqlite.dart` is Stage 1's first job, before the schema.

**Verified at the stage boundary:** `flutter pub get` clean; `flutter analyze` clean;
`flutter test` 391/391 green; `python tool/ux_audit.py` clean (14 checks, 0 violations);
`dart run build_runner build --force-jit` completes and writes nothing into the source tree —
correct, since no drift input exists yet.

---

## Stage 1 — Schema and the database class *(M)*

**Goal:** the database exists, opens, and can be created in memory for tests. Not wired to
the app.

Files: `lib/data/database/app_database.dart`, `lib/data/database/tables/*.dart`.

**14 tables**, one per persisted model plus two join/child tables:

| Table | Notes |
|---|---|
| `stores` | + `stalePartialOrderDays INTEGER NOT NULL DEFAULT 7` — this is where `MockSettings` goes (`lib/mock_data/mock_settings.dart:9` already says so) |
| `categories`, `units` | `storeId` FK → stores, `ON DELETE CASCADE` |
| `items` | `categoryId`/`unitId` FK **RESTRICT** — the domain rule "cannot delete a category in use" becomes a DB constraint, not just a check |
| `suppliers` | |
| `supplier_prices` | unique index `(itemId, supplierId)` — the "already linked" rule at the schema level |
| `price_history` | FK to item + supplier, `ON DELETE CASCADE` |
| `stock_movements` | FK item `ON DELETE CASCADE`; **supplierId FK `ON DELETE SET NULL`** — Step 5 of `DOMAIN_MODEL.md`: a deleted supplier must not unmake goods that really moved |
| `purchase_orders` + `purchase_order_lines` | `PurchaseOrder.lines` is an embedded list today; it becomes a child table with `ON DELETE CASCADE` |
| `goods_receipts` + `goods_receipt_lines` | same shape |
| `notifications` | |
| `team_members` + `team_member_stores` | `TeamMember.storeIds` is a `List<String>` → join table |

Also in this stage:

- `TypeConverter`s for the five stored enums (`StockMovementType`, `StockOutReason`,
  `PurchaseOrderStatus`, `NotificationKind`, `TeamRole`; `StockStatus` is derived, never
  stored). Store enums as their **name string**, not their index: an index shifts if
  somebody reorders the enum, and the DB outlives the source file.
- `PRAGMA foreign_keys = ON` in `beforeOpen` — off by default in SQLite, and every FK
  above is silently decorative without it.
- Indexes: `items(storeId)`, `items(storeId, barcode)`, `stock_movements(itemId, occurredAt DESC)`,
  `stock_movements(storeId, occurredAt DESC)`, `supplier_prices(itemId)`,
  `supplier_prices(supplierId)`, `purchase_orders(storeId, status)`,
  `price_history(itemId, supplierId, changedAt DESC)`.
- Two constructors: `AppDatabase()` (file, via `driftDatabase(name: 'stock_inventory')`
  from `drift_flutter`) and `AppDatabase.memory()` for tests.

**Windows test gotcha — resolve it in this stage, not at stage 4 when it blocks you.**
`flutter test` runs on the Dart VM, so `sqlite3_flutter_libs` is not loaded and
`NativeDatabase.memory()` cannot find sqlite3. Add `test/support/sqlite.dart` that calls
`open.overrideForAll(...)`, pointing at a `sqlite3.dll` fetched into a gitignored
`build/` path (or Windows' own `winsqlite3.dll`), and call it from a `setUpAll`. Every
later stage's tests depend on this working.

**Done when:** `dart run build_runner build --force-jit` generates `app_database.g.dart`, and a new
`test/db/schema_test.dart` opens `AppDatabase.memory()`, asserts all 14 tables exist,
`foreign_keys` is on, and that inserting an item with a bogus `categoryId` throws.

### As built — the foreign-key map is not the one this plan drew

Stage 1 is done. `test/db/schema_test.dart` is 13 tests and runs in under a second.

**1. Sixteen tables, not fourteen.** The plan's own list came to fifteen once counted
(`team_member_stores` was described but not numbered). The sixteenth is `meta`, moved up
from Stage 2: it is part of the schema, and adding it later would mean a version bump and a
migration before the first version has ever been opened.

**2. `stock_movements.supplierId` must NOT be `ON DELETE SET NULL`.** This is the one thing
the plan got backwards, and it took reading `supplier_mutations.dart:112-121` to see it. The
rule is not "a deleted supplier must not unmake goods that moved" in the sense of keeping the
*row* — it is that **the movement keeps their id** and renders "Fournisseur supprimé".
`SET NULL` erases the id and makes the past tidier than it was. The column carries no foreign
key at all.

That turned out to be a pattern rather than a one-off. Five references are deliberately not
enforced, each because Phase 1 permits the reference to dangle and an FK would force a
behaviour change to make the constraint true:

| Column | Why no FK |
|---|---|
| `stock_movements.supplierId` | above |
| `purchase_orders.supplierId` | a supplier can be deleted once they have no *open* order, and their closed orders are kept — that history is how an owner sees who they used to buy from |
| `purchase_order_lines.itemId` | an article is only delete-blocked by an **open** order. An FK would either forbid deleting anything ever ordered, or delete lines out of a completed commande |
| `goods_receipt_lines.itemId` | same, and worse: a receipt is permanent |
| `items.defaultSupplierId` | deleting a supplier does not walk the catalogue clearing it; the screen reads a miss as "no preference" |
| `notifications.relatedItemId` / `relatedSupplierId` | the message still reads correctly once the target is gone; only the tap target disappears |

Everything else is enforced, and the two that matter are `RESTRICT`:
`items.categoryId` and `items.unitId`, so "a category in use cannot be deleted" is a fact
about the database and not only a check somebody could forget to call. The repository keeps
its own check as well — that one produces the count the dialog shows.

**This changes Stage 2's seed test.** "A broken reference now fails loudly" is true for the
enforced references only. The seed test should assert the loose ones resolve *in the seed*,
since the schema will no longer do it for us.

**3. No `converters/` folder.** drift's `textEnum<T>()` already stores an enum as its name
string, which was the whole property worth having. Hand-written `TypeConverter`s would be
the same behaviour spelled out at length. The folder is gone; a test pins the format.

**4. Two build options, both in `build.yaml` with the reasoning next to them.**
`store_date_time_values_as_text: true` — drift's integer format is whole seconds, and
receiving a delivery writes several movements in the same tick, so second precision would
turn "newest first" into ties broken by chance; it also makes Stage 10's
`strftime('%Y-%m', col)` correct without the `'unixepoch'` modifier that silently returns
1970 when forgotten. `generate_manager: false` — we do not use drift's fluent manager API
(the repositories are hand-written, and several reads are joins and grouped aggregates it
cannot express); switching it off took `app_database.g.dart` from 16 692 lines to 8 460.

**5. The Windows test gotcha is solved with the OS's own `winsqlite3.dll`**, loaded by bare
name in `test/support/sqlite.dart` and called from `setUpAll(useTestSqlite)`. No download, no
gitignored artefact, nothing to set up on a new machine. It is SQLite 3.43 against the 3.51
the app bundles; nothing in this schema is newer than 3.43, and the day something is, the
test suite is where it fails first.

**6. A trap for every stage from here: `flutter analyze` cannot see generated code.**
`app_database.g.dart` is a `part of` the database library, so it compiles against *that
file's* imports — but the analyzer excludes `**/*.g.dart`, so a missing import there is
invisible to `flutter analyze` and shows up only when something actually compiles the part.
It cost a green analyze followed by twenty compile errors in the first test run. The four
model-enum imports at the top of `app_database.dart` look unused and are not; there is a
comment saying so. **`flutter analyze` passing is not evidence that the generated code
compiles — run the tests.**

**Verified at the stage boundary:** `flutter analyze` clean; `flutter test` 404/404 green
(391 existing, 13 new); `python tool/ux_audit.py` clean; `dart run build_runner build
--force-jit` regenerates identically.

---

## Stage 2 — Mappers, seed, and bootstrap *(M)*

**Goal:** the database can be filled with the demo dataset, and the app opens it at
startup. The UI still reads mocks.

1. `lib/data/mappers/*.dart` — pure functions `Item itemFromRow(ItemRow)` /
   `ItemsCompanion itemToRow(Item)`, one file per aggregate. Orders and receipts take
   their lines as a second argument (`orderFromRows(row, lineRows)`), which is where the
   embedded-list shape is rebuilt.
2. `lib/data/seed/demo_seed.dart` — inserts the twelve current mock lists into the DB in
   FK order (stores → categories/units → suppliers → items → prices → history → movements
   → orders → lines → receipts → lines → team → notifications), in **one transaction**.
   It imports `lib/mock_data/` as its source; that import is the only thing keeping
   `mock_data/` alive from here on, and Stage 10 moves the dataset into `lib/data/seed/`.
   - `mock_reference.dart` freezes `mockNow = DateTime.now()` at library load and every
     seeded date is an offset from it. The seed must record `seededAt` in a
     `meta` key/value table so a re-seed reproduces relative dates rather than drifting.
3. `lib/data/database/bootstrap.dart` — `Future<AppDatabase> openAppDatabase()`: opens the
   file, and if the `stores` table is empty, runs the demo seed. First launch therefore
   looks exactly like the demo does today.
4. `lib/data/repositories/demo_repository.dart` — `resetDemo()`: delete all rows, re-seed,
   in one transaction. This is what *Réinitialiser la démonstration* will call
   (`sync_status_page.dart:216,271` currently calls `MockWrite.hasChanges` / `reset()`).
5. `lib/services/local_database_service.dart` — the stub becomes the real thing: it owns
   the `AppDatabase` instance and exposes it. This is the file the Phase 1 brief reserved
   for exactly this.

**Tests ported in this stage:** `mock_data_test.dart` (14 tests, referential integrity)
becomes `test/db/seed_test.dart` — seed an in-memory DB, then assert the *same* properties
against queries instead of lists: every id resolves, all three stock statuses present, one
store genuinely empty, an item with three competing suppliers exists, one where the default
is not the cheapest. Add one new assertion the list version could not make: the seed
inserts with `foreign_keys` on, so a broken reference now fails loudly.

**Done when:** `flutter test` green (old suites untouched, seed suite new), and
`test/db/seed_test.dart` proves a seeded DB matches the dataset the demo path relies on.

### As built — the seed takes its clock as an argument

Stage 2 is done. `test/db/seed_test.dart` is 22 tests; the app opens and seeds the real file
at startup while every screen still reads the mock lists.

**1. `seedDemoData(db, {DateTime? at})` — the anchor is a parameter, not a record.** The plan
asked for `seededAt` in `meta` "so a re-seed reproduces relative dates rather than drifting",
which on inspection is not something a stored timestamp can do on its own: the dataset's dates
are already resolved into `DateTime`s by the time the seed sees them, frozen against
`mockNow` at library load. So the seed shifts every date by `at - mockNow`, which re-anchors
the whole timeline — the commande sent three days before `mockNow` is sent three days before
`at`. `at` defaults to `DateTime.now()`, and the instant used is written to `meta.seededAt`.

The payoff is bigger than reproducibility. `mock_data_test.dart` opens by saying *"Dates are
anchored to `DateTime.now()`, so nothing here asserts on them."* That restriction is gone:
`test/support/db_fixture.dart` seeds at a fixed `seedInstant`, so a test can now name a date.
Stage 6 needs that — `orderIsStale` is a question about days elapsed.

**2. `test/support/db_fixture.dart` arrives here, not in stage 4.** `seed_test.dart` needed it
already, and writing it twice would be worse. `openSeededDatabase()` / `openEmptyDatabase()`,
both self-closing via `addTearDown`. It sets `dontWarnAboutMultipleDatabases` — a few tests
hold two databases at once and drift warns about that because two objects sharing an executor
race; these share nothing.

**3. `clearAllData` deletes in reverse foreign-key order rather than switching the
constraints off.** `PRAGMA foreign_keys = OFF` around a delete is a habit that eventually
gets used somewhere it hides a real bug. Reverse order is fifteen lines and cannot.

**4. `lib/services/local_database_service.dart` is deleted, not implemented.** The Phase 1
brief reserved four service stubs; this stage was meant to turn that one into "the real
thing". What it would actually contain — open the file, seed if empty, hold the instance —
is `lib/data/database/bootstrap.dart` plus stage 8's `databaseProvider`, and the opening logic
belongs with the data layer because it needs the seed. A forwarding class under
`lib/services/` would have been a second name for one thing, and a second place to look. The
other three stubs are untouched and stay for Phase 3.

**5. `databaseProvider` is pulled forward from stage 8, alone.** Without it, "the app opens
the database at startup" means opening a file and dropping the handle. `lib/data/providers.dart`
holds `databaseProvider` (no default — `main()` and every test must override it) and
`demoRepositoryProvider`, and nothing else; stage 8 still owns the per-screen
`StreamProvider.family` layer, which is the bulk of it. `main()` now awaits
`openAppDatabase()` before the first frame.

**6. Carried over from stage 1 and now covered:** the six references the schema deliberately
does not enforce get their own group in `seed_test.dart`, because they are exactly the ones
the database will not check for us — a delivery's supplier, a commande's supplier, both line
tables' article, an article's default supplier, a notification's targets.

**Still open, for stage 9:** `sync_status_page.dart` reads `MockWrite.hasChanges` to grey out
the reset button. There is no cheap equivalent — "does this database differ from the seed" is
not a query — and reintroducing a write counter to answer it would be rebuilding the thing
this phase deletes. **The reset action becomes always available.** Resetting an untouched demo
is a no-op that costs nothing, and the disabled state was a nicety, not a safeguard.

**Verified at the stage boundary:** `flutter analyze` clean; `flutter test` 426/426 green
(404 existing, 22 new); `python tool/ux_audit.py` clean.

**Native linking, checked the long way round.** That `sqlite3_flutter_libs` *links* into a
built app — as opposed to resolving as a package — is not something the test suite can show:
tests reach SQLite through `winsqlite3.dll`, a different library entirely. `flutter build
windows` cannot answer it here either, for want of a Visual Studio C++ toolchain. So the
check was run on Android instead: `flutter build apk --debug` succeeds, and the APK contains
`lib/arm64-v8a/libsqlite3.so` along with the armeabi-v7a and x86_64 builds. The plugin
compiles SQLite from source through the NDK, so that is the real thing working.

Windows and macOS remain unproven, though the plugin registrants were regenerated for both.
**Run a real `flutter build` on the machine the app is actually shipped from, before stage
9** — a linking failure found at the screen cutover looks like an app that will not start,
for reasons nothing in this document points at.

---

## Stage 3 — Read repositories *(L)*

**Goal:** every one of the 57 `MockQueries` methods has a repository equivalent. Nothing
in `lib/features/` calls them yet.

Shape, and it matters:

- **List reads return `Stream<List<T>>`** via drift `.watch()`. This is what replaces
  `mockDataRevisionProvider`: the DB pushes, screens no longer need a global "something
  changed" counter.
- **Single reads by id return `Stream<T?>`** where a screen watches one record
  (`item_detail_page`), `Future<T?>` where a form reads once.
- **Pure predicates stay synchronous and stay where they are** — `itemMatchesSearch(Item,
  String)` and `receiptReferenceOf` operate on already-loaded objects. Do not turn them
  into repository calls.

Split by aggregate so the files mirror `mock_data/mutations/`:
`store_repository`, `catalog_repository`, `item_repository`, `supplier_repository`,
`movement_repository`, `order_repository`, `account_repository`, `report_repository`.

Queries that must be **rewritten rather than translated** — these are the ones that are
N+1 or full-scan today and become real SQL:

| Today | Becomes |
|---|---|
| `inventory_list_page.dart:_visibleItems` calls `pricesForItem` **inside a `.where()`** — N+1 per row | one query with `JOIN supplier_prices` + the category/supplier/search filters in SQL |
| `valuationByCategory` / `valuationByItem` each call `stockValuation` again internally, walking the store twice | one `GROUP BY categoryId` with `SUM(quantity * averageCost)`, share-of-total computed from the same result set |
| `consumptionValue` / `wasteValue` / `shrinkageValue` walk every movement in Dart | `SUM(ABS(quantity) * unitCost)` with `WHERE type = ? AND reason IN (?) AND occurredAt BETWEEN ? AND ?` |
| `onOrderQuantity` / `openOrdersForItem` join orders × lines in Dart | join in SQL, with `lineOutstanding`'s `closedShort` rule expressed as `CASE WHEN closed_short THEN 0 ELSE MAX(0, ordered - received) END` |
| `price_comparison_report_page.dart:48-68` `_mostInterestingItem()` — scans **every item in the store** from `initState` to find the biggest overpay gap | `reportRepository.largestOverpayItem(storeId)`, one query. This is a real report query that leaked into a widget |
| `_nextReference` scans all orders for the max `CMD-YYYY-NNN` | `SELECT MAX(reference)` inside the create transaction (see Stage 6) |

Ordering contracts that are currently implicit in list insertion order and must become
explicit `ORDER BY` — the tests depend on them:

- `pricesForItem` is sorted **cheapest first**; `_promoteCheapestToDefault` relies on it.
- movements are **newest first** (`insert(0, …)` today) → `ORDER BY occurredAt DESC, id DESC`.
  The `id DESC` tiebreak matters: several tests read `mockStockMovements.first` immediately
  after a mutation, and two movements in the same millisecond are common in a receipt.
- `receiptsForOrder` is **oldest first** — `BR-2026-014/2` numbering derives from position.

**Tests:** new `test/db/queries_test.dart` — seed, then assert each derived figure against
the same expectations the current query tests use. Old suites still green and untouched.

**Done when:** every `MockQueries` member has a repository counterpart, and a checklist in
this file maps old → new one-to-one, so Stage 9 is mechanical.

### The checklist — `MockQueries` to repositories

Every read has a `Future` form; the ones a screen watches also have a `watch…` `Stream` form,
listed as `x / watchX`. Stage 9 picks the stream for anything rendered and the future for
anything a form asks once.

| `MockQueries` | Replacement |
|---|---|
| `storeById` | `StoreRepository.store / watchStore` |
| `storeByIdOrFirst` | `StoreRepository.watchStoreOrFirst` — **now nullable**, see below |
| `itemsForStore` | `ItemRepository.items / watchItemsByName` |
| `itemById` | `ItemRepository.item / watchItem` |
| `lowStockItems` | `ItemRepository.itemsByAttention(filter: lowStockOnly) / watchItems` |
| `itemsWithBarcode` | `ItemRepository.itemsWithBarcode` |
| `barcodeConflict` | `ItemRepository.barcodeConflict` |
| `itemMatchesSearch` | moved to `core/utils/item_search.dart`, still synchronous |
| `categoriesForStore` | `CatalogRepository.categories / watchCategories` |
| `categoryById` | `CatalogRepository.category` |
| `categoryNamed` | `CatalogRepository.categoryNamed` |
| `unitsForStore` | `CatalogRepository.units / watchUnits` |
| `unitById` | `CatalogRepository.unit` |
| `unitNamed`, `unitAbbreviated` | `CatalogRepository.unitNamed`, `.unitAbbreviated` |
| `itemCountInCategory`, `itemCountUsingUnit` | same names on `CatalogRepository` |
| `suppliersForStore` | `SupplierRepository.suppliers / watchSuppliers` |
| `supplierById` | `SupplierRepository.supplier / watchSupplier` |
| `pricesForItem` | `SupplierRepository.pricesForItem / watchPricesForItem` |
| `pricesForSupplier`, `itemCountForSupplier` | same names on `SupplierRepository` |
| `defaultPriceForItem`, `cheapestPriceForItem`, `priceFor`, `overpayPerUnit` | same names on `SupplierRepository` |
| `priceHistoryFor` | `SupplierRepository.priceHistoryFor / watchPriceHistory` |
| `movementsForStore`, `movementsForItem`, `recentActivity` | same names on `MovementRepository`, each with a `watch…` twin |
| `notificationsForStore` | `AccountRepository.notifications / watchNotifications` |
| `unreadNotificationCount` | `AccountRepository.unreadNotificationCount / watchUnreadCount` |
| `teamForStore` | `AccountRepository.teamForStore / watchTeamForStore` |
| `teamMemberById` | `AccountRepository.teamMember` |
| `teamMemberByEmail`, `ownerCount` | same names on `AccountRepository` |
| `stockValuation` | `ReportRepository.stockValuation / watchStockValuation` |
| `valuationByCategory`, `valuationByItem` | same names on `ReportRepository` |
| `consumptionValue`, `wasteValue`, `shrinkageValue` | same names on `ReportRepository` |
| `ordersForStore` | `OrderRepository.orders / watchOrders` |
| `orderById` | `OrderRepository.order / watchOrder` |
| `openOrders` | `OrderRepository.openOrders / watchOpenOrders` |
| `ordersForSupplier` | `OrderRepository.ordersForSupplier` |
| `openOrdersForItem` | `OrderRepository.openOrdersForItem / watchOpenOrdersForItem` |
| `onOrderQuantity` | `OrderRepository.onOrderQuantity / watchOnOrderQuantity` |
| `staleOrders` | `OrderRepository.staleOrders(storeId, {now})` |
| `suggestedItemsForSupplier` | `ItemRepository.watchSuggestedItems` |
| `itemsSuppliedBy` | `ItemRepository.itemsSuppliedBy / watchItemsSuppliedBy` |
| `receiptsForOrder` | `OrderRepository.receiptsForOrder / watchReceiptsForOrder` |
| `receiptById` | `OrderRepository.receipt` |
| `receiptReferenceOf` | `OrderRepository.receiptReferenceOf` — now a `Future` |
| `MockSettings.stalePartialOrderDays` | `StoreRepository.stalePartialOrderDays` |
| `_mostInterestingItem()` in the report widget | `ReportRepository.largestOverpayItemId` |

**Three have no counterpart, on purpose:** `categoryNameOf`, `unitAbbreviationOf` and
`supplierNameOf`. Each is a per-row display lookup, and turning them into repository calls is
exactly the shape stage 9 has to avoid — a query per row per rebuild. They become joined
columns on the row view-models stage 9 introduces. **Do not add them.**

### As built

Stage 3 is done. `test/db/queries_test.dart` is 38 tests, and its method is worth stating:
`MockQueries` is still present and still correct, and the seeded database is built from the
dataset it reads — so for anything not dependent on wall-clock time, the two implementations
must agree. Nearly every test asserts the repository against the mock rather than against a
number the suite made up. It dies with `MockQueries` in stage 10, having done its job of
getting the translation across.

**1. `customStatement` does not notify streams, and that will bite stages 4 to 6.** drift
works out which tables a statement touches by having built it; a raw statement tells it
nothing, so the write lands and no `watch` ever fires. The stream test in this stage failed
on exactly that, and took a 30-second timeout to say so. **Every repository write must go
through the typed API**, or through `customUpdate(..., updates: {table})`. Raw `customSelect`
is fine — a read has nothing to invalidate — and raw statements are fine in a test that is
not watching.

**2. A schema change: `position` on both line tables.** `PurchaseOrder.lines` and
`GoodsReceipt.lines` are ordered lists on the model and unordered child tables in SQL.
Ordering by `id` works for the demo, whose line ids happen to end in an ordinal, and would
shuffle a real commande into UUID order the moment it was saved — the person who typed the
lines would watch them rearrange. `rowid` works until somebody runs `VACUUM`. So it is a
column. Done now because the schema is still unreleased and this was the last free moment.

**3. Ordering contracts, now stated.** Every list read has an explicit `ORDER BY`; Phase 1
leaned on the order the mock lists happened to be written in, which a table does not have.
Two are behaviour changes worth flagging:

- **Categories and units are alphabetical**, where they used to appear in the order the
  dataset was authored in. Once a user creates their own, authored order is just creation
  order, which is not a property a catalogue should have. Accented names sort last under
  SQLite's default collation — as they already do under Dart's `compareTo` on the alerts
  list, so at least the app is consistent with itself.
- **Movements and notifications break ties on `id`.** Receiving a delivery writes several
  movements in one transaction, on the same instant; without a second key "the newest
  movement" is whichever one SQLite happened to return. The direction is arbitrary — the
  determinism is the point — and it does reorder two notifications that share a timestamp in
  the demo.

**4. Case folding stays in Dart**, in `core/utils/name_matching.dart` and
`core/utils/item_search.dart`. SQLite's `LOWER()` and `NOCASE` fold ASCII only, so "Épicerie"
and "épicerie" would compare as different in SQL and as the same in Dart. Since the rule is
explicitly *case-folded, not accent-folded*, the Unicode-correct spelling has to win, and the
lists being compared are one establishment's categories or units. `itemMatchesSearch` moved
out of `MockQueries` to the same shelf, with `MockQueries` forwarding to it so there is one
copy rather than two.

**5. `lineOutstanding` is deliberately written twice.** Once in Dart, once as SQL inside
`onOrderQuantity`, because that one is read per row of the inventory and alerts lists and
answering it in Dart meant loading every open commande to add up two numbers. A test holds
the two spellings to the same answer for every article in the flagship store.

**Deviation:** the plan wanted `openOrdersForItem` in SQL as well. It is not. The lines are
already loaded by the query that fetched the open commandes, so filtering them in Dart costs
nothing and lets `lineOutstanding` stay the single definition of "still owed". Duplicating a
rule earns its keep where it removes a query per row; here it would only add a second place
to get it wrong.

**6. `storeByIdOrFirst` can return null now.** Phase 1's returned a non-null `Store` and
crashed on an empty list, which could not happen with a compiled-in dataset. A database can
genuinely hold no establishments, and pretending otherwise moves the crash rather than
removing it. Stage 8's `currentStoreProvider` has to handle it.

**7. A small trap: `drift` and `matcher` both export `isNull` and `isNotNull`.** A test
importing both needs `import 'package:drift/drift.dart' hide isNotNull, isNull;`.

**Verified at the stage boundary:** `flutter analyze` clean; `flutter test` 464/464 green
(426 existing, 38 new); `python tool/ux_audit.py` clean.

---

## Stage 4 — Catalogue, item and supplier writes *(M)*

**Goal:** the three simplest aggregates write for real. Ported test suites prove the rules
survived.

- `catalog_repository`: `createCategory`, `renameCategory`, `deleteCategory`, `createUnit`,
  `updateUnit`, `deleteUnit`. Uniqueness per store, trimmed + case-folded, **no accent
  folding** (`Épicerie` ≠ `Epicerie` on purpose), self-excluded on rename. Delete refuses
  while `itemCountInCategory`/`itemCountUsingUnit` > 0 — keep the explicit check *and* the
  FK RESTRICT, because the check produces the user-facing count and the FK is the backstop.
- `item_repository`: `create`, `update`, `deleteBlockedBy`, `delete`. **`create` still
  inserts `quantity: 0` and delegates the opening balance to the movement repository** —
  in one transaction, so an item never exists without its opening movement. `update` still
  has no `quantity` parameter. Barcode uniqueness per store, self-excluded.
- `supplier_repository`: `create`, `update`, `delete`, `linkItem`, `updatePrice`,
  `setDefault`, `unlinkItem`. Exactly one `isDefault` per item (clear-then-set in a
  transaction), first link auto-defaults, cheapest promoted on unlink and on supplier
  delete, every price change writes a `PriceHistoryEntry`, no-op change (< 0.001) writes
  nothing, `pricePerUnit <= 0` refused.

**Return-value contract must survive.** Callers branch on it synchronously today
(`add_edit_item_page.dart:404` → `if (created == null) return;`). Keep the same shapes,
just wrapped: `Future<Item?>`, `Future<bool>`, `Future<ItemDeleteBlock?>`. Most handlers
are already `Future<void> _submit() async`, so Stage 9 mostly adds `await`.

**Tests ported:** `catalog_test.dart` (23) and `suppliers_test.dart` (18) → same test
names, same assertions, repository calls instead of `XMutations`, `setUp` opens a seeded
in-memory DB instead of `restoreMockData()`. Add `test/support/db_fixture.dart` providing
that per-test DB — it replaces `test/support/mock_reset.dart`.

**Done when:** both ported suites green **and** the original suites deleted in the same
commit (not before — keeping both green is impossible once the write path forks).

### As built

Stage 4 is done. `test/catalog_test.dart` and `test/suppliers_test.dart` are deleted and
`test/db/catalog_test.dart` (23), `test/db/suppliers_test.dart` (20) and
`test/db/items_test.dart` (14) stand in their place.

**1. The movement repository's writes arrived here, not in stage 5.** `item.create` inserts
the article with quantity zero and hands the opening balance to
`MovementRepository.recordOpeningBalance` — that is the plan's own instruction, and it makes
the movement writer a dependency of this stage rather than the next one. Writing half of it
now and half in stage 5 would have been worse than writing it once. Stage 5 keeps its real
job, which is porting `inventory_test.dart`.

That left the item and movement writes landing without their own suite, so
`test/db/items_test.dart` takes the three item-shaped groups out of `inventory_test.dart`
early: creating, editing and deleting. `test/inventory_test.dart` stays green and untouched
until stage 5, so those groups are covered twice for one stage — deliberate, and cheaper than
shipping the app's most consequential writes untested.

**2. `tool/ux_audit.py` gains its fifteenth check now rather than in stage 10.** "Only
`movement_repository.dart` may write `items.quantity` or `items.averageCost`" is the app's
oldest invariant, and it had a mechanical guard pointing only at the mock layer — exactly
while the replacement was being written. The new check finds each `ItemsCompanion` and reads
the call that follows it, rather than matching line by line: a companion spans several lines,
and `quantity:` on its own also appears in legitimate calls *to* the movement repository.
`item_mapper.dart` is allowed, because that is how a whole article becomes a row and it
decides nothing.

It was verified by breaking it on purpose — a `quantity: const Value(99)` added to
`item_repository.update` is caught with the file and line — and then reverted. A guard that
has only ever printed zero has not been tested.

`dart_files()` now skips `*.g.dart` and `*.drift.dart`, the same set the analyzer excludes.
`app_database.g.dart` alone builds every companion the schema can express, including the two
this check forbids by hand, so without that the guard reported two violations of itself.

**3. `meta.currentUserId` and `AccountRepository.currentUser()` arrived early too**, from
stage 7. Every movement and every price change is stamped with a person's name, so "there is
no current user" is not a state the app can be in, and the repositories needed a default the
moment they started writing. Phase 1 resolved it as `mockTeam.first` when the library loaded;
this is the same placeholder with somewhere to write it down. It falls back to the first owner
and then to the first member, so a database whose meta row went missing still writes a name
somebody recognises rather than an empty string.

**4. New ids are bare UUID v4** — `lib/data/repositories/new_id.dart`. No type prefix: the
seeded records keep their readable slugs, which are worth having in a debug dump, but a
generated id is opaque either way and prefixing it would make it look parseable when nothing
parses it.

**5. Deletes lean on the schema's cascade rather than repeating it.** `ItemRepository.delete`
is a single `DELETE FROM items`; the supplier links, their price history and the movements go
with it because the foreign keys say so. Phase 1 had four `removeWhere` calls that a future
caller could have got wrong or forgotten. What the cascade deliberately does *not* reach is
the lines of closed commandes and receipts, which keep naming the article — the reason those
columns carry no foreign key.

`SupplierRepository.delete` keeps one piece of Dart, and it is the piece a cascade cannot
know to do: every article the supplier was the default for is promoted to its cheapest
remaining price, or the article keeps its other suppliers and silently loses its auto-fill
everywhere.

**6. One ported test had to change, and it is worth knowing why.** *"allows the same name in
a different establishment"* took the first category of the Sablon list and re-created it in
Liège. With stage 3's alphabetical ordering the first one is now *Boissons*, which Liège
already has — so the test failed on a genuine collision rather than on a broken rule. It now
creates its own name in both establishments, which is what it was always trying to say. **The
rule did not change; the fixture's assumption about list order did.** Expect one or two more
of these in the remaining ports.

**Verified at the stage boundary:** `flutter analyze` clean; `flutter test` 480/480 green
(464 before, minus 41 deleted, plus 57 new); `python tool/ux_audit.py` clean across 15 checks.

---

## Stage 5 — The movement repository *(M)*

**Goal:** the one file allowed to change `Item.quantity` and `Item.averageCost`.

`movement_repository.dart` — `recordStockIn`, `recordStockOut`, `recordAdjustment`,
`recordOpeningBalance`. Each runs in a **transaction** that inserts the movement and
updates the item, because "quantity == opening balance + Σ movements" must never be
observable as false, and with a real DB there is now a window where it could be.

Rules carried over exactly:

- Sign normalisation: in `quantity.abs()`, out `-quantity.abs()`, adjustment
  `counted - system`.
- Cost computed **before** the quantity is applied, using `stock_cost.dart` unchanged, then
  stamped onto the movement as `unitCost` + `averageCostAfter`. This is what makes the
  average auditable.
- Stock may go negative. A stock-in with no `unitPrice` falls back to the current average.
- `recordOpeningBalance` returns `null` for a zero quantity.

**Concurrency note that did not exist in Phase 1:** the read-modify-write of
`items.quantity` must happen inside the transaction (`SELECT … ; UPDATE …` in the same
`transaction {}`), not read outside and written inside. Two rapid stock-outs from a
double-tapped button are now genuinely concurrent futures.

**Tests ported:** `inventory_test.dart` (37) — including the invariant test that runs an
arbitrary sequence of deliveries, usage and a correction and asserts the equation holds.
The ~8 places reading `mockStockMovements.first` become
`(await repo.movementsForItem(id).first).first`, which is why Stage 3's explicit
`ORDER BY occurredAt DESC, id DESC` matters.
`stock_cost_test.dart` (23) does not change at all.

---

## Stage 6 — The order repository *(L — the hardest stage)*

**Goal:** commandes and receiving, transactional.

`order_repository.dart` — `createDraft`, `updateDraft`, `send`, `deleteDraft`, `cancel`,
`closeShort`, `confirmReceipt`. Status gating still delegates to the predicates in
`order_status.dart` (`orderIsEditable`, `orderCanCancel`, `orderCanReceive`).

`confirmReceipt` is the reason this stage is its own stage. Today it is five sequential
list edits that cannot half-fail. As SQL it is **one transaction** doing:

1. insert the `GoodsReceipt` + its lines (append-only, never updated, never deleted);
2. for each received line, `movementRepository.recordStockIn(...)` **called inside the same
   transaction** carrying `orderId` + `receiptId` — delegated, never inlined, exactly as
   `OrderMutations` does today;
3. accumulate `quantityReceived` onto the order's lines, mark `closedShort` where the
   receiver said so, leave unordered lines out of the order;
4. recompute status via `statusAfterReceipt(lines)`;
5. per line, apply the price rule: no link → create it (and default it if the item's
   first); same within 0.001 → nothing; different → write `PriceHistoryEntry` **and**
   update `SupplierPrice`. Compared against the price **on file**, not the ordered price.

If any step throws, the whole receipt rolls back. That is the acceptance criterion, and it
gets its own test: a receipt whose third line references a deleted item must leave stock,
order status and price history **completely** unchanged.

Two smaller fixes that belong here:

- `_nextReference` currently scans all orders and **ignores its `storeId` argument** —
  references are account-global. Preserve that behaviour (changing it would renumber the
  demo), but move the max-scan **inside** the create transaction so two drafts created in
  the same second cannot take the same number.
- `confirmReceipt` does `MockQueries.orderById(orderId)!` — a bare non-null assertion.
  With a real DB an order can genuinely be gone; return a typed failure instead.

**Tests ported:** `orders_test.dart` (36) — the specification. Same names, same three-ways
assertion that sending moves no stock. Plus the new rollback test above.
`receipt_document_test.dart` (15) needs only its `setUp` swapped; the PDF layer reads
models, which have not changed.

---

## Stage 7 — Account, stores and settings *(S)*

- `account_repository.dart`: `invite`, `updateMember`, `removeMember`, `isLastOwner`,
  `createStore`, `updateStore`, `markRead`, `markAllRead`. Email unique across the team
  (self-excluded), the last owner cannot be removed, `vatNumber` still distinguishes `null`
  (leave) from `''` (clear), a new store starts genuinely empty.
- **`MockSettings.stalePartialOrderDays` moves onto the `stores` row.** It is read from
  three widgets and written from one today; it becomes a column, and `staleOrders(storeId)`
  reads it in the same query instead of from a mutable global.
- **`mockCurrentUser` (`mockTeam.first`, resolved once at library load) becomes
  `currentUserProvider`**, backed by a `meta` row holding the current member id and
  defaulting to the first owner. It is the implicit actor stamped on every movement and
  price-history entry, so it cannot just disappear. Real auth is still Phase 3 — this is
  the placeholder made explicit rather than accidental.

**Tests ported:** `account_test.dart` (12).

At the end of this stage the **entire data layer is done and tested, and the app still runs
on mocks.** That is deliberate: everything up to here is additive and low-risk.

---

## Stage 8 — Provider layer *(M)*

**Goal:** the bridge between repositories and widgets, built and tested before a single
screen is touched.

- `lib/data/providers.dart`:
  - `databaseProvider` — overridden in `main()` with the opened DB, and in tests with
    `AppDatabase.memory()`. `ProviderScope(overrides: [...])` is the single injection point
    for the whole app and the whole test suite.
  - one provider per repository;
  - `StreamProvider.family` per screen-level query, keyed on `storeId` (or a small record
    for two-key queries like price history's item+supplier). This maps **one-to-one** onto
    the existing call sites, because every query already takes `storeId` first.
- `currentStoreProvider` — the `ShellRoute` builder currently does a synchronous
  `MockQueries.storeByIdOrFirst(...)` (`router.dart:107-115`) and it gates every
  store-scoped page. It becomes async, so `AppScaffold` needs a loading scaffold: render
  the rail and top bar with skeleton content rather than a blank screen, so switching
  stores does not flash empty chrome.
- A house rule, written into this file, for how screens render `AsyncValue`:
  `data` → the screen; `loading` → `SkeletonList`/`SkeletonGrid` matching the real layout
  (never the bare spinner — `loading_state.dart:10` already says so); `error` → `ErrorState`
  with a retry that invalidates the provider. One helper widget so 23 screens do not each
  invent it.
- `offline_banner.dart`: `pendingChangesProvider` currently hardcodes `3`. With no outbox
  in Phase 2 it becomes `0` and the banner reads honestly; the provider stays for Phase 3.

**Done when:** a widget test pumps a screen-sized harness against an in-memory DB, asserts
skeleton → data, and asserts an injected failure renders `ErrorState`.

---

## Stage 9 — Screen cutover *(L)*

**Goal:** all 43 files under `lib/features/` read and write through repositories. The mock
layer is no longer reachable from the UI.

**Be honest about this stage:** during it the app compiles but is not *coherent* — a
converted form writes to the DB while an unconverted screen still reads mocks, so figures
disagree until the last screen lands. Do it on one branch, land it as one merge. Within the
branch, convert in this order (dependency-light first, and it matches the demo path):

| Order | Feature | Notes |
|---|---|---|
| 1 | `stores/`, `settings/` | store selector, store switcher, sync page (demo reset button → `demoRepository.resetDemo()`) |
| 2 | `catalog/` | smallest, proves the pattern end to end including the inline "+ Créer" sheets |
| 3 | `inventory/` | includes the two hard files below |
| 4 | `stock_movement/` | 5 files, all forms |
| 5 | `suppliers/` | |
| 6 | `orders/` | 11 files, heaviest |
| 7 | `alerts/`, `dashboard/`, `reports/`, `search/`, `team/` | mostly read-only |

Three shapes of work, and the second is the one that will surprise you:

1. **`ConsumerWidget` screens (23 files).** Drop `ref.watch(mockDataRevisionProvider)`,
   `ref.watch(someStreamProvider(storeId))`, render the `AsyncValue`. Mechanical.
2. **Leaf widgets that query inside `build()` and have no `ref`.** `item_detail_view.dart`
   makes **16** `MockQueries` calls and is a plain `StatelessWidget`; `movement_row.dart`
   (4), `suggested_items_panel.dart` (4), `item_row.dart`, `order_row.dart`,
   `supplier_price_row.dart`, `already_on_order_badge.dart`, `receive_line_row.dart`,
   `store_card.dart` are the same shape. **Do not** make each row a `FutureBuilder` — that
   is one query per row per rebuild. Instead give each list a **row view-model**
   (`ItemRowView`, `MovementRowView`) built once by a repository query that joins the
   category name / unit abbreviation / supplier name in SQL, and pass plain data down.
   This is the single largest chunk of work in Phase 2.
3. **Forms (~20 plain `StatefulWidget`).** Convert to `ConsumerStatefulWidget` and `await`
   the repository call. Handlers are already `Future<void> _submit() async`, so the change
   is usually one `await` plus a `if (!mounted) return;` before the snackbar and pop —
   which did not previously need to exist and is easy to forget on 20 forms. Grep for it
   as an acceptance check.

**Widget test suites in this stage** (`router_test.dart` 140 effective, `navigation_test.dart`
47, `components_test.dart` 13, `widget_test.dart` 2):

- Add a `setUp` that opens `AppDatabase.memory()`, seeds it, and pumps
  `ProviderScope(overrides: [databaseProvider.overrideWithValue(db)])`. Neither file has
  any data setup today — they were safe only because the data was compiled in.
- **`router_test.dart:38-40` and `navigation_test.dart:52-54` read `mockItems.first.id`
  outside any test body, at route-table construction time.** `group()`/`testWidgets()`
  registration cannot await. Replace with the seed's known constant ids (`ItemIds.poulet`
  etc. already exist as compile-time constants) — that is the fix, not a `setUpAll`.
- Every route assertion needs `pumpAndSettle()` **after** the stream delivers. Prefer
  seeding synchronously into an in-memory DB (fast, no I/O) so one `pumpAndSettle()` still
  suffices; if it does not, the router walk needs an explicit pump loop.
- `router_test.dart` still earns its keep here: French labels run 15–25% longer than
  English and it caught eight real overflow bugs across Phase 1.5–1.6. Loading skeletons
  are new layouts — run it at all three viewports against the skeleton state too.

---

## Stage 10 — Teardown, tooling and docs *(M)*

1. **Delete `lib/mock_data/`** except the seed source. Move the twelve dataset files to
   `lib/data/seed/dataset/` (they are now demo fixtures, not an app layer) and delete
   `mock_queries.dart`, all of `mutations/`, `mock_write.dart`, `mock_settings.dart`,
   `mock_reports.dart` (its valuation/comparison constants are already dead; only the two
   frozen trend lists and `mockPotentialAnnualSaving` are still referenced — see item 4).
   `unused_import: error` makes this self-policing: anything still importing the barrel
   fails `flutter analyze`.
2. **Delete `test/mock_write_test.dart` (10 tests).** It tests `_Seed` and the revision
   counter — infrastructure that no longer exists. Its *intent* survives as two new tests
   in `test/db/`: a reset restores values (not just row counts), and generated ids never
   collide with seeded ones.
3. **Repoint `tool/ux_audit.py`.** Its 14 checks (the README says twelve — stale) include
   three that encode "where writes are allowed" as literals:
   - `MUTATION_LAYER = 'lib/mock_data/mutations/'` → `'lib/data/repositories/'`
   - `COST_WRITERS` (line 189) → repositories + `stock_cost.dart`
   - the scan root `'lib/mock_data'` appears **4×** (lines 153, 173, 193, 236) → `'lib/data'`

   Two checks need **rewriting, not repointing**, because they are regexes over the `mock`
   naming convention that is about to disappear:
   - check 10 (`mockItems\[...\] =`) → "no write to the `items` table outside
     `lib/data/repositories/movement_repository.dart`", i.e. flag `update(items)` /
     `into(items)` / `.write(` outside the allowed file. This is the *most important*
     invariant in the app and must not lose its mechanical guard.
   - check 13 (`mock[A-Z]\w*` + 8 mutating methods) → any `into(...)`/`update(...)`/
     `delete(...)` on a drift table outside `lib/data/repositories/`.

   Checks 11 (`averageCost =`) and 12 (`pricePerUnit` × `quantity` — stock valued at a
   purchase price) are semantic and survive untouched; only their scan roots widen.
   Add a **15th check**: no `lib/features/` file imports `lib/data/database/` — screens
   talk to repositories, never to drift directly.
4. **The two frozen trend charts.** `README.md:31-36` promises "Phase 2 aggregates them
   properly". `mockUsageTrend` / `mockWasteTrend` are still hardcoded and
   `mockPotentialAnnualSaving` is still the headline figure on the reports dashboard
   (`reports_dashboard_page.dart:83`). With movements in SQL these become real
   `GROUP BY strftime('%Y-%m', occurredAt)` queries. The honest caveat stays true: the
   seeded movement log only covers a few weeks in detail, so a six-month series will be
   mostly zero. Either extend the seed's movement history to six months, or narrow the
   charts to the window the data supports and label it. **Pick one and say so on screen** —
   shipping a flat-zero chart reads as a bug.
5. **Docs.** `README.md` — new status section ("Phase 2 complete — the app persists"),
   the migration table replaced by the repository map, the stale "332 tests" and "twelve
   checks" figures corrected, and the demo path updated with one new step: *close the app,
   reopen it, the delivery is still there.* `DOMAIN_MODEL.md` — its "Where this lives in
   the code" table (lines 803-815) repointed at repositories.

---

## Verification

Run at the end of every stage, not only at the end:

```powershell
flutter analyze                 # unused_import and unawaited_futures are ERRORS here
flutter test                    # must be green at every stage boundary
python tool/ux_audit.py         # from the repo root — its paths are relative
dart run build_runner build --force-jit
```

End-to-end, by hand, once Stage 9 lands — this is the demo path from `README.md:66-102`,
with the one step that could not exist before:

1. Launch → store selector → **Brasserie du Sablon** → dashboard shows a stock value.
2. **Commandes → CMD-2026-017 → Réceptionner la livraison.** Drop the Riz quantity below
   what was ordered; change the Blanc de poulet price 12,80 → 14,50 and confirm the >15%
   warning. Confirm.
3. **Inventaire → Blanc de poulet**: quantity moved, price history gained an entry, the
   movement links back to the receipt, and the item's average cost moved by CUMP — not to
   the delivery price.
4. **Kill the app completely and relaunch.** Everything above is still there. *This is the
   whole point of Phase 2 and the only step that proves it.*
5. **Taverne Saint-Gilles** from the switcher → still genuinely empty, every empty state
   real.
6. **Paramètres → Synchronisation → Réinitialiser la démonstration** → back to the seed,
   and step 4 again confirms the reset also persisted.
7. Rotate to portrait and repeat two screens — `router_test.dart` covers this, but the
   skeleton states are new layouts it has not seen before.

Performance check worth doing once, because it is the thing a real DB can regress: open the
inventory list on the seeded store and confirm no jank. The old `_visibleItems` did an N+1
`pricesForItem` per row; the replacement is one joined query, so it should be *faster* than
Phase 1 — if it is not, the join did not land.

---

## Risks, in the order they will actually bite

| Risk | Mitigation |
|---|---|
| sqlite3 not found under `flutter test` on Windows | Solved in **Stage 1**, before anything depends on it |
| Stage 9 is a long incoherent branch | Strict feature order, `flutter analyze` green at every commit, one merge |
| Leaf row widgets become per-row queries | Row view-models built by a joined query — called out explicitly in Stage 9 |
| `pumpAndSettle()` no longer a sufficient sync point | In-memory seeded DB keeps resolution synchronous-ish; explicit pump loop if not |
| A receipt half-applying | Single transaction + an explicit rollback test in Stage 6 |
| `mockNow`-relative dates drifting on re-seed | `seededAt` in a `meta` table, Stage 2 |
| Scope creep into sync | `sync_service`/`api_service`/`auth_service` stay two-line stubs. Phase 3 |
