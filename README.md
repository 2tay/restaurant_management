# stock_inventory

Multi-store stock and inventory management for restaurants, built with Flutter for
**Android and iOS tablets** (landscape-first).

The application UI is **French** (`fr_BE`) — the client is a Belgian restaurant. Code,
comments, and documentation are in English.

## Status — Phase 1 (UI only)

Phase 1 is a **demo-ready prototype, not a functioning app**. Every screen renders from
static mock data in `lib/mock_data/`. There is no database, no networking, no persistence
and no business logic. Phase 2 adds local-first storage and sync.

The full brief is in [`.claude/phase1.md`](.claude/phase1.md).

| Stage | Scope | Status |
|---|---|---|
| 0 | Dependencies, l10n pipeline, folder skeleton, lints | Done |
| 1 | Design system — palette, typography, spacing, theme | Done |
| 2 | Models + mock data | Not started |
| 3 | go_router shell + navigation | Not started |
| 4 | Shared component library | Not started |
| 5 | Screens (~40) | Not started |
| 6 | Polish pass | Not started |
| 7 | Phase 2 stubs + handoff | Not started |

## Getting started

```bash
flutter pub get
flutter run
```

Requires Flutter 3.38+ (Dart 3.10+).

### Fonts

The type scale expects **Inter**, which is not committed. Download the `.ttf` files
(Regular / Medium / SemiBold / Bold) into `fonts/` and uncomment the `fonts:` block in
`pubspec.yaml`. Without them the app falls back to Roboto.

`google_fonts` is deliberately not used — it fetches over the network at runtime, which is
wrong for an app whose whole premise is working offline in a kitchen.

## Project layout

Feature-first, so Phase 2 can add `data/` and `domain/` next to `presentation/` inside each
feature without touching UI code.

```
lib/
  app/          MaterialApp + router wiring
  core/         theme, formatters, constants, responsive helpers
  features/     one folder per feature, presentation/ only in Phase 1
  shared/       cross-feature widgets (buttons, dialogs, states, shell)
  models/       immutable plain Dart classes — shape only, no logic
  mock_data/    ALL static data. Never inline fake lists in a widget.
  services/     Phase 2 stubs — empty classes, no logic
  l10n/         .arb translations + generated AppLocalizations
  dev/          development-only. NOT shipped — removed at handoff.
```

### The theme gallery

`lib/dev/theme_gallery_page.dart` renders every design-system primitive on one page. Until
the router lands in Stage 3 it is the app's `home`, so `flutter run` opens straight into it.

It exists so contrast, hue separation and type sizing get judged once, before forty screens
bake the mistakes in. Nothing under `features/` may import from `lib/dev/`.

## Design system

Defined in `lib/core/theme/`. Two rules the code deliberately enforces:

- **Teal is for actions, green is for "en stock".** Different hues on purpose. If the primary
  button and the in-stock badge share a hue, the status signal stops carrying meaning.
- **Status is never colour alone.** Every status pairs a colour with an icon and a label —
  roughly 1 in 12 men has a red/green colour vision deficiency, and the app's core signal is
  red/amber/green.

Sizing floors live in `AppSizing`: 48dp minimum tap target, 56dp buttons and inputs, 64dp
table rows and stepper buttons. Nothing renders below 13pt.

## Conventions

- **No hardcoded user-facing strings.** Everything goes through
  `AppLocalizations.of(context)`. See [`lib/l10n/README.md`](lib/l10n/README.md).
- **No formatting by hand.** Currency (`12,50 €`) and dates (`22/08/2026`) come from
  `intl` with the `fr_BE` locale, via `core/utils/formatters.dart`.
- **`intl` is pinned to exactly `0.20.2`** — `flutter_localizations` from the SDK requires
  it. Widening that constraint breaks `flutter pub get`.
- **Models carry no logic** — no `fromJson`, no persistence annotations.
- Run `flutter analyze` before committing; lints are strict and the tree is clean.

## Domain rules the UI must reflect

1. An item has **no single cost**. Price is an attribute of the *item–supplier link* — one
   product can have several suppliers, each at their own price.
2. Supplier prices **change over time**, and every change is a history entry.
3. Categories and units are **created in-app**, not hardcoded. Every such dropdown offers
   an inline "+ Créer".
4. Once a store is selected, all data is **scoped to that store**.
