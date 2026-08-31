# stock_inventory

Multi-store stock and inventory management for restaurants, built with Flutter for
**Android and iOS tablets** (landscape-first).

The application UI is **French** (`fr_BE`) — the client is a Belgian restaurant. Code,
comments, and documentation are in English.

---

## Status: Phase 2 complete — the app persists

**What you do in the app is still there tomorrow.** Every screen reads and writes a local
SQLite database through drift. Creating an article, receiving a delivery, recording usage,
renaming a category, changing a price, inviting a colleague: all of it is written to a file
on the device, and all of it survives closing the app, killing it, and rebooting the tablet.

The first launch seeds the demo dataset, so a fresh install looks exactly like the Phase 1
demo did — and **Paramètres → Synchronisation → Réinitialiser la démonstration** puts it
back, which now means re-seeding the file rather than restoring an in-memory snapshot.

Nothing about the domain rules changed. They moved into `lib/data/repositories/`, one file
per aggregate, and the tests that pinned them followed. What a receipt does to stock and price history, what counts as on order, how a
weighted-average cost advances — all of it means the same thing it did, and now it means it
after a restart.

**Still fake, deliberately:** login, export and sync. Those screens say so on themselves.
There is no server, so there is nothing to sync with; the offline banner reports zero
pending changes, which is true rather than decorative.

**No longer frozen:** the usage and waste trend charts are a real aggregation over the
movement log, and the potential-annual-saving headline is the actual gap between what the
establishment pays and the best price on offer. The charts are **weekly** rather than
monthly, and deliberately so — the seeded history covers a few weeks, and a six-month series
over it would be five empty columns and one tall one, which reads as a broken chart rather
than as a young dataset.

| Phase | Scope | Status |
|---|---|---|
| 1.0–1.7 | UI, design system, navigation, and the domain rules in memory | Done |
| 2 | Local-first SQLite storage via drift | Done |
| 3 | Sync, remote API, real authentication | Not started |

Phase 2's eleven stages, and what each one actually cost, are in
[`phase2.md`](phase2.md) — every stage carries an "As built" section recording where the
plan was wrong.

The original brief is in [`.claude/phase1.md`](.claude/phase1.md).

---

## Getting started

```bash
flutter pub get
flutter run
```

Requires Flutter 3.38+ (Dart 3.10+). The app opens on the login screen; any credentials
get you in, because nothing is authenticated.

### The demo path

Worth walking in this order — it is the order that tells the story:

1. **Log in** → the store selector. Three stores; note the alert badges.
2. **Brasserie du Sablon** → the dashboard. Stock value, what needs reordering, recent activity.
3. **Inventaire** → master–detail. Select **Blanc de poulet**.
4. On the item detail, the **Fournisseurs et prix** section shows three suppliers at three
   different prices, and calls out that the default supplier costs 1,35 € more per kg than
   the cheapest. This is the point of the product.
5. **Historique des prix** on that supplier → six months of increases, 11,20 € to 12,80 €.
6. **Rapports → Comparaison des prix** → the same finding as a report, opening on the item
   with the largest gap.
7. **Commandes** → the orders list. Every status is represented, and the Boucherie order is
   flagged stale — partial for nine days, past the seven-day threshold.
8. **CMD-2026-017** (Grossiste Central, *Envoyée*) → **Réceptionner la livraison**. This is
   the walkthrough that sells the feature:
   - quantities arrive pre-filled with what is outstanding, because that is what usually
     turns up
   - drop the **Riz** quantity below what was ordered → the short-delivery control appears
     inline, defaulted to **Clôturer l'écart**
   - change the **Blanc de poulet** price from 12,80 € to 14,50 € → confirming asks you to
     verify it, because that is a 13% jump past the threshold
   - confirm → stock rises, a stock movement appears carrying the order reference, and the
     chicken's price history gains an entry
9. Back on **Inventaire → Blanc de poulet**: the quantity has moved, **Historique des prix**
   has the new entry, and the movement links back to the receipt it came from.
10. **Kill the app completely and reopen it.** Everything above is still there — the
    quantity, the movement, the price history entry, the commande's new status. This is the
    whole point of Phase 2 and the only step that proves it.
11. **Alertes** → each low item now says whether anything is already on order. **Créer les
    commandes** groups them by supplier and pre-fills a draft.
12. **Taverne Saint-Gilles** from the store switcher → a brand-new empty store, so every
    empty state is real rather than described.
13. **Paramètres → Synchronisation** → toggle offline mode to show the offline banner, and
    **Réinitialiser la démonstration** to put everything back before the next walkthrough.
    Reopen the app once more: the reset persisted too.

Barcodes are woven through rather than being their own step: about half the catalogue has
one (beverages and packaged dry goods; nothing fresh). Copy one from a beverage's detail
screen, paste it into the inventory search, and it finds the item.

### Fonts

The type scale expects **Inter**, which is not committed. Download the `.ttf` files
(Regular / Medium / SemiBold / Bold) into `fonts/` and uncomment the `fonts:` block in
`pubspec.yaml`. Without them the app falls back to Roboto and looks noticeably more generic.

`google_fonts` is deliberately not used — it fetches over the network at runtime, which is
wrong for an app whose whole premise is working offline in a kitchen.

---

## Project layout

Feature-first, so Phase 2 can add `data/` and `domain/` next to `presentation/` inside each
feature without touching UI code.

```
lib/
  app/          MaterialApp, router, route paths
  core/         theme, formatters, constants, responsive helpers
  features/     one folder per feature, presentation/ only
  shared/        cross-feature widgets (buttons, dialogs, states, shell)
  models/        immutable plain Dart classes — shape only, no logic
  data/          everything to do with storage
    database/    drift schema, the database class, migrations
    mappers/     row <-> model, one file per aggregate
    repositories/ the write and read layer — one file per aggregate
    view_models/ what one screen needs, resolved in one query
    seed/        the demo dataset and the code that writes it
    providers.dart  the bridge: one provider per screen-level query
  services/      Phase 3 stubs — empty classes, no logic
  l10n/         .arb translations + generated AppLocalizations
  dev/          development-only reference. Not product — see below.
tool/
  ux_audit.py   re-runnable check against the UX rules below
```

### The theme gallery

`lib/dev/theme_gallery_page.dart` renders every design-system primitive and shared
component on one page, interactively. Reachable at **`/dev/gallery`**, linked from nothing.

It was originally going to be deleted at handoff. It is kept because it is the fastest way
to see what components exist and how they behave, and re-deriving that from 35 screens is
worse. **A production build should drop `lib/dev/` and its route.** Nothing outside that
folder imports it, so removing it is a two-line change.

---

## How the data layer fits together

```
screen  →  provider  →  repository  →  drift  →  SQLite file
```

Nothing skips a step. A screen names the query it wants — `itemRowsProvider(...)`,
`orderDetailProvider(...)` — and receives plain data with every name already resolved. It
never holds a database, never writes a table, and cannot: `tool/ux_audit.py` fails the build
if a file under `features/` imports `data/database/` or drift itself.

| Folder | Owns |
|---|---|
| `data/database/` | The schema — 14 tables, real foreign keys, `PRAGMA foreign_keys = ON`, a migration strategy from version 1 |
| `data/mappers/` | Row ↔ model, one file per aggregate. Models stay plain Dart with no persistence annotations |
| `data/repositories/` | Every query and every write. **`movement_repository.dart` is the only file that changes an item's quantity or average cost** |
| `data/view_models/` | What one screen needs, in one query. A row in a list is handed text, not ids |
| `data/seed/` | The demo dataset, and the transaction that writes it on a first launch |
| `data/providers.dart` | One provider per screen-level query, keyed the way the screen keys it |

**Queries are streams.** A write anywhere re-runs every query whose tables it touched, and
the screens watching them rebuild. There is no change counter and nothing to remember to
notify — the database says what changed.

### Where Phase 3 plugs in

Three stubs in `lib/services/` still mark the seams:

| File | Phase 3 responsibility |
|---|---|
| `sync_service.dart` | Offline queue + conflict resolution |
| `api_service.dart` | Remote API client |
| `auth_service.dart` | Real authentication |

`local_database_service.dart` is no longer a stub — it owns the open `AppDatabase`.

Two things are already shaped for what comes next. `currentUserProvider` resolves the acting
member from a `meta` row rather than from a constant, so signing in becomes a write to that
row rather than a refactor of everything that stamps a movement. And `pendingChangesProvider`
reports zero because there is no outbox; Phase 3 fills it from the real one and the offline
banner starts telling the truth about a queue instead of about an absence.

The rules those writes implement — the status transitions, what a receipt does to stock and
price history, what counts as on order — are pinned by `test/db/orders_test.dart`. That file
is the specification; the screens are the cheap part.

Store scoping is structural rather than stateful — the store id is in the route path
(`/store/:storeId/inventory`), so no screen can render without knowing which store it is
for, and store switching is just navigation.

---

## Conventions

- **No hardcoded user-facing strings.** Everything goes through
  `AppLocalizations.of(context)` — every key carries a translator description. See
  [`lib/l10n/README.md`](lib/l10n/README.md). Adding Dutch is a translation job, not a
  refactor.
- **No formatting by hand.** Currency (`12,50 €`) and dates (`22/08/2026`) come from `intl`
  with the `fr_BE` locale, via `core/utils/formatters.dart`.
- **`intl` is pinned to exactly `0.20.2`** — `flutter_localizations` from the SDK requires
  it. Widening that constraint breaks `flutter pub get`.
- **All static data lives in `data/seed/dataset/`.** A hardcoded list inside a widget is
  a bug. Nothing but the seed reads it.
- **Models carry no logic** — no `fromJson`, no persistence annotations.
- Run `flutter analyze` and `flutter test` before committing. Both are clean; lints are
  strict and `unused_import` is an error.

---

## Domain rules the UI enforces

1. **An item has no single cost.** Price is an attribute of the *item–supplier link*, since
   one product can come from several suppliers at different prices. `Item` has no price
   field at all — the wrong model is impossible to write. The add/edit form explains the
   absence on screen, because anyone who has used another inventory app will look for it.
2. **Supplier prices change over time**, and every change is a history entry scoped to the
   item–supplier *pair*. "What has this supplier charged us for chicken" is answerable;
   "what has chicken cost" is not.
3. **Categories and units are created in-app.** Every such dropdown carries an inline
   "+ Créer" that opens a sheet without leaving the form — a cook who needs a "botte" unit
   mid-form should not have to abandon it. The sheet returns the record it created, and the
   form selects it. Names are unique per store ignoring case and space ("Boissons" and
   "boissons " are one category with a typo), and a unit's abbreviation is checked as well
   as its name, because the abbreviation is what appears beside every quantity in the app.
   **Neither can be deleted while anything uses it** — items reference them by id, so
   removing one underneath them would leave articles rendering as "—" with no way to
   recover what they said. Tapping delete explains the count and the fix rather than
   offering a confirmation that then quietly fails.
4. **Store scoping**: once a store is selected, every screen shows that store's data only.
   A new store starts genuinely empty — categories, units, items and suppliers are all
   per-store, so what the user sees next is every empty state in the app doing its job.
5. **Every change to an item's quantity is a stock movement.** One file writes quantity —
   `data/repositories/movement_repository.dart` — and everything comes through it: receiving a
   delivery, a manual stock-in, usage mid-service, a physical count, and the opening balance
   on a brand-new article. So `quantity == opening balance + Σ movements` holds by
   construction, and the history is a complete record rather than a partial one that looks
   complete. Two consequences worth knowing:
   - **Quantity is read-only on the edit item form.** Dragging a stepper from 40 to 35 there
     would be an untraceable stock change hidden in a routine screen. The form states the
     quantity and links to the adjustment screen, which asks for the counted figure and
     leaves a record.
   - **Stock can go negative.** Recording 10 kg out when 6 are on hand records 10, and the
     item reads −4. Refusing would make staff either lie to the app or stop using it, and
     negative stock is itself the signal that a delivery went unrecorded. The form warns
     first; the adjustment screen is the fix.
6. **An order never changes stock — only a receipt does.** Ordering 50 kg of tomatoes does
   not put 50 kg on the shelf; the goods are not there yet. Stock moves when a delivery
   arrives and somebody confirms what actually came through the door. Every screen respects
   this, and `test/orders_test.dart` asserts it three ways.
7. **A commande goes to exactly one supplier**, so the supplier is step one of creating one
   rather than a field halfway down the form. Everything after depends on it: the item
   picker is filtered to what that supplier sells, and every price auto-fills from them.
8. **A sent order is locked.** The supplier holds a copy; an order that quietly disagrees
   with the document in their inbox is worse than no order. Only drafts are editable, and
   only drafts can be deleted outright — a sent order is cancelled, which leaves a record.
9. **Closing an order short records the shortfall, it does not rewrite the order.** Ordered
   10, received 8, closed: the line still says 10 were ordered. That two-unit gap is the
   only evidence the supplier under-delivered, and it is what an owner needs.
10. **Confirmed receipts are permanent** — never edited, never deleted. Corrections go
   through a stock adjustment so both the original and the correction stay visible.
11. **Prices are captured at receiving.** A delivery note that disagrees with the ordered
    price writes a price-history entry and updates that supplier's current price, which is
    how price history stays current without anyone maintaining it by hand. A move of more
    than `OrderRules.significantPriceChange` (15%) asks for confirmation first — that is
    usually either a real increase the owner must know about, or a typo.
12. **A barcode is optional and unique per store.** Most restaurant stock — produce, meat,
    fish, bread — has none, so the field is labelled optional and its row is hidden on items
    without one. Lookups are written to return a *collection*, never a single item, so
    "several barcodes per item" stays a model change rather than a rewrite.

---

## UX rules, and how they are enforced

The brief's users are standing, moving fast, with wet hands, mid-service. That drove:

- Minimum tap target 48dp; buttons and inputs 56dp; stepper buttons and table rows 64dp
- Nothing renders below 13pt
- Status is **never** colour alone — every stock badge pairs colour with a distinct icon
  shape and a text label
- Every destructive action confirms first, and the dialog **names the record**
- Every action that changes something fires an identical snackbar
- Every list has a designed empty state, and distinguishes "nothing here yet" from "your
  filters matched nothing"

`python tool/ux_audit.py` re-checks the mechanical parts of that list — plus that every
colour comes from `app_colors.dart`, every text style from `app_typography.dart`, every
padding value from the spacing scale, and that no screen navigates with a raw `context.go()`.

Six of the fifteen checks are about semantics rather than style, and they are the ones worth
knowing about:

- **no single-object barcode lookups** — a `firstWhere` on a barcode anywhere is flagged,
  because it is the shape that makes "several barcodes per item" expensive later
- **no database writes outside `data/repositories/`** — every guard the repositories hold
  (the movement behind a quantity change, the price history behind a price, the transaction
  around a delivery) is bypassed by anything that reaches a table directly
- **no feature code importing `data/database/` or drift** — the same rule from the other
  side. A screen that cannot name a table cannot write one
- **`items.quantity` and `items.averageCost` written only by `movement_repository.dart`** —
  checked by finding each `ItemsCompanion` and reading the call that follows it, because a
  companion spans several lines and `quantity:` also appears in perfectly legitimate calls
- **`averageCost` assigned only in the repository layer** — a running total is safe only
  while exactly one thing advances it
- **no quantity multiplied by a supplier price** — the bug the valuation exists to avoid: a
  supplier price is what the *next* unit costs, so multiplying it by stock on hand revalues
  goods bought weeks ago at this morning's price

Fifteen checks, currently zero violations. Re-run it after adding screens.

## Navigation

The convention lives in `lib/app/navigation.dart` and is not optional:

- **`goSection(path)`** — the sidebar's ten destinations, and anything meaning "leave here
  entirely". Replaces the stack.
- **`pushScreen(path)`** — anything the user comes back from. Stacks, so back works.
- **`backTo(fallback)`** — pops when it can, otherwise lands on a sensible parent. The
  fallback matters: a deep link opens a screen with an empty stack.

Every pushed screen carries a labelled back control top-left ("Retour à Inventaire") and,
when more than one level deep, breadcrumbs. Root screens deliberately carry neither.

Two screens use tabs that switch in place rather than navigating — the order detail's
Lines / Receipts and the supplier's Fiche / Commandes. They are two views of one record, not
two records, so they share `SectionTabs` for the look but take a callback instead of a path.

Forms use `FormScaffold`, which owns three rules so no screen re-implements them: Cancel
bottom-left and submit bottom-right, the action bar pinned, and unsaved input confirmed
before it is lost — through the back control, the Cancel button, and the Android system
back gesture alike.

---

## Testing

```bash
flutter test
```

524 tests, and a full run takes about four minutes — most of it the route walk, which
seeds a database per test. The ones that earn their keep:

- **`navigation_test.dart`** pins the navigation contract: all 15 root screens show no back
  control and all 24 pushed screens do; push-then-pop returns you where you were and five
  cycles leave the stack as it started; switching section clears anything pushed on top; the
  sidebar highlights the right section from a nested screen; a dirty form raises the discard
  dialog and a clean one does not; and dialog buttons are checked by measured screen
  position, not by assumption.

- **`router_test.dart`** walks every route three times — at the 1280×800 baseline, at
  1024×600, and in portrait — asserting nothing throws or overflows. French labels run
  15–25% longer than the English a layout was designed against, and this caught six real
  overflow bugs during the build, including a navigation rail that silently grew to 380dp
  to fit "Mouvements de stock" and stole 148dp from every screen. It caught two more in
  Phase 1.6: `SectionHeader` laid its action button out unbounded, so "Associer un
  fournisseur" ran off the 434dp detail pane the moment content above it shifted, and the
  low-stock row gained one column too many to survive portrait.
- **`db/seed_test.dart`** checks referential integrity across the hand-written dataset —
  against a seeded database, so the schema's own foreign keys catch some of it and this
  catches the rest, including the six references that carry no key by design. It asserts the
  demo-critical properties too: all three stock statuses present, one establishment empty, an
  article with three competing suppliers, another where the default is not the cheapest. And
  that a generated id can never collide with a seeded one, which stopped being merely tidy
  the moment ids outlived the process.
- **`components_test.dart`** pins the component behaviour the brief depends on — the status
  badge never using colour alone, the stepper accepting `2,5`, the dropdown's inline
  "+ Créer".
- **`db/queries_test.dart`** is a differential suite. It asks the database a question and
  asks `test/support/dataset_queries.dart` — the Phase 1 read layer, kept in the test tree —
  the same question, and fails when they disagree. That is the strongest available evidence
  that porting fifty-odd queries from Dart list scans into SQL changed nothing, because an
  expected number is only ever as right as whoever typed it.
- **`provider_layer_test.dart`** pins the bridge: that the shell draws chrome rather than a
  blank screen while its establishment resolves, that a write reaches a watching widget with
  nothing in between, that the skeleton does not flash when it does, and that an error beats
  a still-loading sibling when several queries are folded together.
- **`db/catalog_test.dart`** pins the two catalogue rules — unique names, no deleting what is
  in use — including the cases that are easy to get backwards: a rename must not collide
  with itself, a refused write must not half-apply, and the same name in a different store
  is fine because categories are per-store. It finishes by deleting every category and every
  unit it can and asserting no item was left pointing at nothing.
- **`db/inventory_test.dart`** pins the invariant the whole app rests on:
  `quantity == opening balance + Σ movements`, checked after an arbitrary sequence of
  deliveries, usage and a correction. Also that editing an item cannot change its quantity,
  that a stock-out is allowed to take an item to −4, that deleting an item on an open order
  is refused, and that deleting every item in the store leaves no orphaned movement.
- **`db/suppliers_test.dart`** pins the link rules — an item never has two defaults, removing
  the default promotes the cheapest remaining one, a price change writes history for the
  pair, and deleting a supplier keeps the movements and closed orders that name them, since
  a movement records goods that really moved.
- **`db/account_test.dart`** covers team, stores and notifications, including the two rules
  worth having: the last owner cannot be removed, and a new store starts genuinely empty.
- **`db/orders_test.dart`** is the one that matters most, because the ordering rules are the
  part of this app with the most behaviour. Each test gets its own seeded in-memory
  database: that sending an order moves no stock but does count
  towards "on order", that a sent order refuses edits and a partially received one refuses
  cancellation, that receiving generates one stock movement per line carrying its order and
  receipt references, that closing short settles the line without inventing stock and stops
  it counting as on the way, that a changed price writes history and an unchanged one does
  not, and that the seeded dataset actually covers every status and every receipt outcome
  the walkthrough needs.

Dates in the dataset are offsets from a single anchor, so the demo always looks current. The
seed takes that anchor as an argument, which is why the suites *can* assert on dates: they
seed at a fixed instant and "sent three days ago" becomes a date a test can name.

The one thing worth knowing before writing a widget test here: `pumpAndSettle` never returns
while a skeleton is on screen, because `SkeletonBlock` pulses on a repeating controller. Pump
a fixed duration instead when you need to look at a loading state.

---

## Out of scope for Phase 2

Real authentication, sync, network calls, real CSV export, and recipe/BOM costing (out of
the MVP entirely). The bon de réception is a real PDF; the export dialogs on the reports are
not.

One thing to check before shipping to a platform other than Android: `sqlite3_flutter_libs`
links a native library per platform, and only the Android build has been run end to end from
this repository. `flutter build windows` and `flutter build macos` should be exercised once
on the machine the app ships from.
