# Alerts & Notifications

How the two screens work, end to end. Alerts answer **"what do I order today?"**.
Notifications answer **"what changed while I wasn't looking?"**.

Both live under `lib/features/alerts/` and share a tab bar, so one is always one tap
from the other.

---

## 1. Where they sit

**Alertes is the first entry in the sidebar**, above Tableau de bord, and the only rail
entry that carries a count. It is what this establishment opens the app for.

- Rail order and the badge: `lib/shared/widgets/app_sidebar.dart` (`_destinations`)
- The badge number: `alertsCountProvider` in `lib/data/providers.dart`
- The bell in the sidebar header counts **unread notifications**, which is a different
  number: `unreadCountProvider`

The badge is derived from the same stream the Alertes screen reads, so a movement that
clears an alert updates the rail and the list in the same frame. No extra query.

---

## 2. Alerts — step by step

### Step 1 — What counts as an alert

One rule: **`quantity <= lowStockThreshold`**. That's it.

Two severities come out of it (`stockStatusOf` in `lib/core/utils/stock_status.dart`):

| Severity | Condition |
|---|---|
| Rupture | `quantity <= 0` |
| Stock bas | `0 < quantity <= lowStockThreshold` |

The alert fires on what is **physically in the store**. Stock already ordered does *not*
clear it — goods in a van do not cook dinner.

### Step 2 — Where the rows come from

`lowStockAlertsProvider` → `ItemRepository.watchLowStockAlerts(storeId)`.

One drift query returns everything a row needs, already joined:

- the article, its category and its unit
- **`onOrderQuantity`** — how much is on its way across every `sent` / `partial` commande
- the **default supplier**, so the row can offer a one-tap order

Worst first. The query watches the tables that ordering and receiving write to, so the
list is live.

### Step 3 — Filtering (all on one row)

```
[Toutes 15][Ruptures 3][Stock bas 12] │ [Couverture ▾][Fournisseur ▾][✕]  …  [Tri ▾][▤▦]
```

Left to right: **which ones**, **narrowed how**, then **ordered and drawn how**.

- **Severity tabs** carry the count *with the other filters already applied* — "Ruptures 3"
  means three after the supplier and coverage narrowing. That is why there is no separate
  result count anywhere on the page.
- **Couverture** splits the list into *Rien en commande* / *En commande*. This is the
  distinction the screen exists for: low-and-already-handled needs nothing from you today.
- **Fournisseur** only lists suppliers that actually appear, plus *Sans fournisseur*.
- **Tri** sits apart from the filters because it reorders and never hides — so it is not
  counted as an active filter and is not cleared with them.
- The row **scrolls sideways** instead of wrapping. A long supplier name must not push the
  whole list down.

All filtering happens **in memory** over the list the query already returned — no round
trip per tap. See `lib/features/alerts/presentation/alerts_filter.dart`.

### Step 4 — Reading a row

Three zones, one line:

```
☐  Blanc de poulet              6 / 8 kg                    [Commander]
   Viandes · Grossiste Central  ▬▬▬▬▬▬░░░  manque 2 kg · 20 kg en route
```

| Zone | Says |
|---|---|
| **Who** | article, then category · default supplier |
| **How bad** | level, coverage bar, and the shortfall in two words |
| **What to do** | one button |

The **coverage bar**: solid = what's on the shelf, pale = what's on order, both as a
proportion of the **threshold** (not of max stock — the question is "are we back above the
line", not "is the shelf full").

Deliberately absent, because each was a repeat:

- no status badge — `0 / 8 kg` already says it, and the section heading names it
- no "Rien en commande" — it was on almost every row. Silence means nothing is coming.
- the button says `Commander`, not `Commander chez Grossiste Central` — the supplier is
  already on the row

**Colour is used only where it is the sole signal.** The left edge is reserved for
ruptures; the figure is emphasised by weight, not tint; teal means selection and nothing
else.

### Step 5 — Ordering from the screen

1. Tick rows (or tick nothing — the button then acts on everything currently shown).
2. A bar appears at the bottom: *"7 produits · 2 fournisseurs"*.
3. Tap **Créer les commandes**.
4. A sheet lists one entry per supplier. Pick one.
5. A draft commande opens, pre-filled with that supplier's low articles.

**Why one commande per supplier:** a commande goes to exactly one supplier. A single
"order everything" button would produce a document nobody can send.

Articles with no default supplier are left out of the sheet — a group that cannot become a
document is not worth offering. The sheet shows a **line count per supplier and no total
quantity**, because the articles under one supplier are measured in kilos, crates and
litres, and adding them would be a meaningless number.

Selection holds **item ids, not rows**. The list underneath is a live stream; holding stale
copies would order against quantities that have since moved.

---

## 3. Notifications — step by step

The feed used to be decorative: ten seeded rows that nothing ever added to. It is now
driven by real events.

### Step 1 — Something happens

A repository finishes a write successfully, then calls the engine
(`lib/data/notifications/notification_engine.dart`).

| Event | Hook | Fires when | Kind |
|---|---|---|---|
| Stock crosses the threshold | `MovementRepository._record` | was **above**, now at or under | `lowStock` |
| Stock hits zero | same | now `<= 0` (wins over `lowStock`) | `outOfStock` |
| Big count discrepancy | `recordAdjustment` | `abs(delta) >= 1` **and** `>= 20%` of the system quantity | `largeAdjustment` |
| Supplier price moved | `SupplierRepository.updatePrice` | the price actually changed | `priceChange` |
| Delivery received | `OrderRepository.confirmReceipt` | one per receipt, not per line | `delivery` |

### Step 2 — Three rules decide whether it is written

**1. The preference is checked first.** A kind switched off produces **no row at all** —
not a hidden row. A suppressed notification that still sat unread on the bell would be the
opposite of what the switch promises.

**2. Only crossings are notified.** An article already under its threshold moves every
service. Notifying each time would let one struggling product own the whole feed. The
deduplication lives in the query: nothing is written if the same kind about the same
article already exists inside the window (**12 h**, or **2 min** for deliveries). The
existing row is **not refreshed**, so its timestamp keeps saying when the situation
started.

**3. A feed failure never fails the write.** Every entry point swallows its own errors. A
delivery that was received *is* received; a feed entry that could not be filed is not a
reason to roll it back. This is the only place in the codebase where an exception is
deliberately dropped.

> **One exception worth knowing:** an opening balance goes through `recordAdjustment` with
> a system quantity of zero. It is exempt — a count from nothing is not a discrepancy, and
> without the exemption every new article would be greeted with a warning.

The write itself is `AccountRepository.emit(...)`, and it runs **inside the caller's
transaction** — so a rolled-back movement takes its notification with it.

### Step 3 — Preferences

Four switches, per establishment, in **Paramètres → Notifications**.

| Switch | Default |
|---|---|
| Stock faible | on |
| Changement de prix | on |
| Ajustement important | on |
| Livraisons | **off** |

Stored as four columns on the `stores` table (**schema v8**). Each switch writes on its
own, so a screen left open on another tablet cannot revert a change it never saw.

Deliveries ship off because whoever is at the back door with the crates already knows.

### Step 4 — Reading the feed

- Grouped under **Aujourd'hui / Hier / the date**.
- Filtered by **type** (Stock / Prix / Ajustements / Livraisons), each carrying its count so
  you can see whether a filter is worth applying before it returns nothing.
- Unread entries have a filled left edge and a heavier title — a bold font alone is too
  subtle at arm's length.
- **Mark one read without opening it**: the check button on desktop, swipe on touch.
  Before this the only way to silence the bell was to navigate to the page it pointed at.
- Tapping an entry marks it read **and** deep-links to the article or supplier it is about.

---

## 4. File map

| What | Where |
|---|---|
| Alerts screen | `lib/features/alerts/presentation/pages/low_stock_alerts_page.dart` |
| Filter / sort / selection state | `lib/features/alerts/presentation/alerts_filter.dart` |
| Coverage bar | `lib/features/alerts/presentation/widgets/coverage_bar.dart` |
| Notification feed | `lib/features/alerts/presentation/pages/notifications_page.dart` |
| The engine | `lib/data/notifications/notification_engine.dart` |
| `emit` + dedupe, read/unread | `lib/data/repositories/account_repository.dart` |
| Alert query | `lib/data/repositories/item_repository.dart` (`watchLowStockAlerts`) |
| Preference columns | `lib/data/database/tables/stores.dart`, migration in `app_database.dart` |
| Preferences screen | `lib/features/settings/presentation/pages/notification_preferences_page.dart` |
| Sidebar order + badge | `lib/shared/widgets/app_sidebar.dart` |
| Strings | `lib/l10n/app_fr.arb` (`alerts*`, `notifications*`) |

---

## 5. Checking it works

```bash
flutter test test/db/notification_engine_test.dart   # the engine's rules
flutter test test/db/migration_test.dart             # schema v8 + defaults
flutter test test/section_tabs_test.dart             # no overflow, phone + large text
flutter test test/navigation_test.dart               # Alertes first, and badged
```

By hand, on the seeded demo:

1. Record a stock-out that pushes an article under its threshold → the bell count goes up
   and the entry appears under *Aujourd'hui*.
2. Do it again on the same article → **no second notification**. That is the dedupe.
3. Turn off *Stock faible*, repeat on another article → nothing is created. Restart the
   app → the switch is still off.
4. Change a supplier price → *Hausse de prix* with the old and new figures.
5. Tick three articles from two suppliers on Alertes → **Créer les commandes** offers two
   groups and pre-fills the draft.
