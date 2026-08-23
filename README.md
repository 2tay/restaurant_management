# stock_inventory

Multi-store stock and inventory management for restaurants, built with Flutter for
**Android and iOS tablets** (landscape-first).

The application UI is **French** (`fr_BE`) — the client is a Belgian restaurant. Code,
comments, and documentation are in English.

---

## Status: Phase 1.6 complete — UI, plus the ordering rules in memory

Still a **demo-ready prototype, not a functioning app**. Every screen renders from data in
`lib/mock_data/`. There is no database, no networking, no persistence and no repositories.

**Almost nothing you do is saved, with one deliberate exception.** Forms confirm and
navigate; they change no data. The exception is the ordering flow added in Phase 1.6:
sending a commande, receiving a delivery and closing an order short really do run, against
the mock lists, **in memory for as long as the app is open**. A hot restart puts everything
back.

That exception exists because the feature is not demonstrable otherwise — the entire point
of receiving a delivery is that stock goes up and the price history gains an entry, and a
screen that shows a success message while nothing moves teaches the client the wrong thing
about what they are buying. The rules live in `mock_data/mock_mutations.dart` and are the
ones Phase 2 will reimplement against real storage.

| Stage | Scope | Status |
|---|---|---|
| 0 | Dependencies, l10n pipeline, folder skeleton, lints | Done |
| 1 | Design system — palette, typography, spacing, theme | Done |
| 2 | Models + mock data | Done |
| 3 | go_router shell + navigation | Done |
| 4 | Shared component library | Done |
| 5 | Screens (37 routes across 35 page files) | Done |
| 6 | Polish pass + UX audit | Done |
| 7 | Phase 2 stubs + handoff | Done |
| 1.5 | Navigation fixes + UI polish pass | Done |
| 1.6 | Purchase orders + receiving, item barcode | Done |

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
10. **Alertes** → each low item now says whether anything is already on order. **Créer les
    commandes** groups them by supplier and pre-fills a draft.
11. **Taverne Saint-Gilles** from the store switcher → a brand-new empty store, so every
    empty state is real rather than described.
12. **Paramètres → Synchronisation** → toggle offline mode to show the offline banner.

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
  features/     one folder per feature, presentation/ only in Phase 1
  shared/       cross-feature widgets (buttons, dialogs, states, shell)
  models/       immutable plain Dart classes — shape only, no logic
  mock_data/    ALL static data, the lookups over it, and the in-memory writes
  services/     Phase 2 stubs — empty classes, no logic
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

## Where Phase 2 plugs in

Four empty stubs in `lib/services/` mark the seams:

| File | Phase 2 responsibility |
|---|---|
| `local_database_service.dart` | Local-first storage (drift/isar) |
| `sync_service.dart` | Offline queue + conflict resolution |
| `api_service.dart` | Remote API client |
| `auth_service.dart` | Real authentication |

**The migration path is `mock_data/mock_queries.dart` and `mock_data/mock_mutations.dart`.**
Screens never touch the mock lists directly. Reads go through `MockQueries.itemsForStore(...)`,
`MockQueries.onOrderQuantity(...)` and so on; the writes Phase 1.6 added go through
`MockOperations.send(...)`, `MockOperations.confirmReceipt(...)` and friends. Replace both
with repositories returning the same shapes and the call sites barely move.

`MockOperations.revision` is a change counter that screens watch through
`mockDataRevisionProvider`, so a receipt confirmed on one screen is visible on the one
underneath it. Phase 2 swaps it for whatever change stream the storage layer exposes.

The rules those writes implement — the status transitions, what a receipt does to stock and
price history, what counts as on order — are pinned by `test/orders_test.dart`. That file is
the specification; the screens are the cheap part.

The models are already Phase 2 ready: immutable, no `fromJson`, no persistence annotations,
no methods with logic. Add serialization alongside them rather than inside them.

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
- **All static data lives in `mock_data/`.** A hardcoded list inside a widget is a bug.
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
   mid-form should not have to abandon it.
4. **Store scoping**: once a store is selected, every screen shows that store's data only.
5. **An order never changes stock — only a receipt does.** Ordering 50 kg of tomatoes does
   not put 50 kg on the shelf; the goods are not there yet. Stock moves when a delivery
   arrives and somebody confirms what actually came through the door. Every screen respects
   this, and `test/orders_test.dart` asserts it three ways.
6. **A commande goes to exactly one supplier**, so the supplier is step one of creating one
   rather than a field halfway down the form. Everything after depends on it: the item
   picker is filtered to what that supplier sells, and every price auto-fills from them.
7. **A sent order is locked.** The supplier holds a copy; an order that quietly disagrees
   with the document in their inbox is worse than no order. Only drafts are editable, and
   only drafts can be deleted outright — a sent order is cancelled, which leaves a record.
8. **Closing an order short records the shortfall, it does not rewrite the order.** Ordered
   10, received 8, closed: the line still says 10 were ordered. That two-unit gap is the
   only evidence the supplier under-delivered, and it is what an owner needs.
9. **Confirmed receipts are permanent** — never edited, never deleted. Corrections go
   through a stock adjustment so both the original and the correction stay visible.
10. **Prices are captured at receiving.** A delivery note that disagrees with the ordered
    price writes a price-history entry and updates that supplier's current price, which is
    how price history stays current without anyone maintaining it by hand. A move of more
    than `OrderRules.significantPriceChange` (15%) asks for confirmation first — that is
    usually either a real increase the owner must know about, or a typo.
11. **A barcode is optional and unique per store.** Most restaurant stock — produce, meat,
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

Phase 1.6 added two invariants to it that are about semantics rather than style:

- **no single-object barcode lookups** — a `firstWhere` on a barcode anywhere is flagged,
  because it is the shape that makes "several barcodes per item" expensive later
- **no stock writes outside `mock_mutations.dart`** — a screen assigning into `mockItems`
  would bypass the movement log, and the movement log is the single source of truth for
  stock levels

Eleven checks, currently zero violations. Re-run it after adding screens.

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

247 tests. The five that earn their keep:

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
- **`mock_data_test.dart`** checks referential integrity across the hand-written dataset,
  and asserts the demo-critical properties: all three stock statuses present, one store
  empty, at least one item with three competing suppliers, at least one where the default
  supplier is not the cheapest.
- **`components_test.dart`** pins the component behaviour the brief depends on — the status
  badge never using colour alone, the stepper accepting `2,5`, the dropdown's inline
  "+ Créer".
- **`orders_test.dart`** is the one that matters most, because the ordering rules are the
  part of this phase with actual behaviour. It runs them against the in-memory layer and
  restores the mock lists afterwards: that sending an order moves no stock but does count
  towards "on order", that a sent order refuses edits and a partially received one refuses
  cancellation, that receiving generates one stock movement per line carrying its order and
  receipt references, that closing short settles the line without inventing stock and stops
  it counting as on the way, that a changed price writes history and an unchanged one does
  not, and that the seeded dataset actually covers every status and every receipt outcome
  the walkthrough needs.

Dates in the mock data are anchored to `DateTime.now()` so the demo always looks current;
nothing asserts on them.

---

## Out of scope for Phase 1

Real authentication, any persistence, sync, network calls, repositories or business logic
layers, real PDF/CSV export, and recipe/BOM costing (out of the MVP entirely).
