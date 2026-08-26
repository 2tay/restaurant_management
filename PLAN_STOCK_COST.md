# Implementation Plan — Real Stock Cost (Weighted Average)

> **Status: implemented.** All fourteen stages are done, including Stage 8,
> which the plan allowed to be deferred. 375 tests pass (up from 332) and
> `tool/ux_audit.py` is clean.
>
> Two things went differently from the plan, both noted in place below:
>
> * **Stage 5 has no supplier-price fallback.** The plan said an absent opening
>   cost should fall back to the default supplier's price. It cannot: at
>   creation there is no `SupplierPrice` link to read, because
>   `defaultSupplierId` is a preference, not a link. An absent opening cost
>   leaves the cost unknown, which is the honest answer.
> * **Stage 8 replaced three constants rather than adding to them.**
>   `mockUsageLast30Days`, `mockWasteShareLast30Days` and
>   `mockWasteValueLast30Days` are gone; the reports dashboard and usage report
>   now compute those figures from the log.
>
> The rules described here are the current behaviour. `DOMAIN_MODEL.md` is the
> reference; this file is kept as the record of why.

**The bug:** stock valuation is `quantity × current supplier price`. When a
delivery arrives at a new price, that price is applied to **all** stock on hand,
including the units bought last week at the old price. The app invents (or
destroys) value that never existed.

**The fix:** stop using one number for two jobs.

```
SupplierPrice.pricePerUnit  → what the NEXT unit will cost  → orders, comparison, overpay
Item.averageCost            → what the CURRENT units cost   → valuation, COGS, waste value
```

**Method:** Weighted Average Cost (CUMP). One cost number per item, remixed on
every stock-in, untouched by every stock-out.

Stages are ordered so the app compiles and the test suite passes at the end of
each one. Nothing here changes how a screen looks except where stated in
Stage 9.

---

## Design decisions taken up front

These are settled so no stage has to stop and ask.

| Question | Decision | Why |
|---|---|---|
| Average or FIFO layers? | **Weighted average** | Restaurant goods are interchangeable, no lot tracking. FIFO needs a layer table and painful correction handling for precision nobody will use. |
| Store the cost or derive it? | **Store on `Item`, snapshot on every movement** | It is path-dependent — it depends on the *order* of movements — so deriving it means replaying the whole log on every read. Same shape as `quantity`: stored for speed, rebuildable from the log. |
| Cost unknown — 0 or null? | **`double?`, null means unknown** | An item with no cost contributes **0** to valuation. Understating beats inventing — the rule the app already follows. |
| Does a stock-out change the cost? | **Never** | Consuming stock cannot change what the remaining stock cost you. This is the property the whole method rests on. |
| Does an adjustment change the cost? | **Never** | No invoice is involved. The gap moves in or out at the current average. |
| Negative stock on a stock-in? | **Reset: `averageCost = deliveryPrice`** | The old baseline is already known-wrong. Averaging against it spreads the error. |
| Rounding | **Never round the stored value.** Round at display only. | Rounding a running average compounds the error over months. |
| Comparing two costs | **`(a - b).abs() < 0.001`** | Same epsilon the price code already uses. |

---

## Stage 0 — Lock down current behaviour first

**Files:** `test/inventory_test.dart`, `test/orders_test.dart`

Before touching anything, add tests that pin the invariants that must survive
this change:

- `item.quantity == sum of its movements` (already tested — confirm it passes)
- Receiving a commande produces exactly one `stockIn` movement per received line
- `MockWrite.reset()` restores everything

**Done when:** `flutter test` is green and you have a baseline.

This stage exists because Stage 3 is a refactor of the receiving path. Without a
green baseline you cannot tell a refactor mistake from a cost-logic mistake.

---

## Stage 1 — Model fields

**File:** `lib/models/item.dart`

Add:

```
final double? averageCost;   // cost of one unit of the stock on hand, EUR. Null = unknown.
```

- Add to the constructor as an optional named parameter.
- Add to `copyWith`.
- **Careful:** `copyWith` uses `x ?? this.x`, which cannot *clear* a value to
  null. Follow the pattern already used for `barcode` in
  `item_mutations.dart` — a separate `clearAverageCost` flag — or accept that
  it is never cleared once set. Cost only becomes unknown at creation, so the
  simple version is fine; just do not silently pretend otherwise.
- Document it in the class doc next to the existing "there is no price field"
  note, because a reader will otherwise think the rule was abandoned. It was
  not: this is cost, not price.

**File:** `lib/models/stock_movement.dart`

Add:

```
final double? unitCost;          // cost per unit applied by THIS movement
final double? averageCostAfter;  // the item's average once this movement landed
```

- `unitCost` on a `stockIn` equals the price paid. On a `stockOut` or
  `adjustment` it is the average cost at that moment.
- `averageCostAfter` is what makes the average auditable. Without it the number
  changes on its own and nobody trusts it — the same reasoning that makes an
  adjustment store *both* counts instead of only the difference.

**Done when:** the project compiles. Nothing reads the new fields yet.

---

## Stage 2 — The cost engine, as pure functions

**New file:** `lib/core/utils/stock_cost.dart`

This is where the arithmetic lives — one place, no side effects, trivially
testable. It sits beside `stock_status.dart` and `order_status.dart`, which play
exactly this role already.

Four functions:

**`costAfterStockIn({oldQuantity, oldAverageCost, inQuantity, inUnitPrice})`**

```
if oldQuantity <= 0 or oldAverageCost == null → return inUnitPrice
oldValue = oldQuantity × oldAverageCost
newValue = oldValue + (inQuantity × inUnitPrice)
newQty   = oldQuantity + inQuantity
return newQty <= 0 ? inUnitPrice : newValue / newQty
```

**`costAfterStockOut(oldAverageCost)`** → returns it unchanged. It exists as a
named function anyway, so the rule is stated in code rather than implied by an
absence.

**`costAfterAdjustment(oldAverageCost)`** → likewise unchanged.

**`valueOf(quantity, averageCost)`** → `averageCost == null ? 0 : quantity × averageCost`.
Negative quantity gives a negative value, which is correct and visible.

**Done when:** `test/stock_cost_test.dart` covers, at minimum:

| Case | Expect |
|---|---|
| 100 @ 8.00 + 50 @ 10.00 | 150 @ **8.666…**, value **1300** |
| 0 @ null + 50 @ 10.00 | 50 @ **10.00** |
| −5 @ 8.00 + 20 @ 10.00 | 15 @ **10.00** (reset rule) |
| 150 @ 8.667, out 20 | 130 @ **8.667** (unchanged) |
| 150 @ 8.667, counted 140 | 140 @ **8.667**, loss ≈ **86.67 €** |
| any quantity, null cost | value **0** |

The first row is the bug. When it passes, the bug is dead in the engine; the
rest of the plan is wiring.

---

## Stage 3 — Make the single writer actually single (refactor, no behaviour change)

**File:** `lib/mock_data/mutations/order_mutations.dart`

There is a problem today: `OrderMutations._recordStockIn` builds a
`StockMovement` and edits `mockItems` **itself**, duplicating what
`MovementMutations.recordStockIn` does. Two writers means the cost logic would
have to be implemented — and maintained — twice.

**Change:** delete `_recordStockIn`'s body and call
`MovementMutations.recordStockIn(...)` instead, passing `orderId`, `receiptId`,
`supplierId`, `unitPrice`, `occurredAt` and `userName`.

Two details:

- `MovementMutations._record` does `insert(0, …)` and calls `MockWrite.changed()`
  per movement. Receiving a 12-line delivery now bumps the revision 12 times
  instead of once. Harmless (the notifier is a counter and screens just re-read),
  but if it ever matters, batch it later — do **not** keep a second writer to
  avoid it.
- Receipt lines with `quantityReceived <= 0` are already skipped before this
  call. Keep that.

**Done when:** `flutter test` is still green and `tool/ux_audit.py` still passes.
No numbers on screen have changed. This stage is pure structure, and doing it
separately is what keeps Stage 4 small.

---

## Stage 4 — Apply cost in the one writer

**File:** `lib/mock_data/mutations/movement_mutations.dart`

`_applyToItem` currently does one thing: add the delta to the quantity. It now
does two.

Rewrite it to:

1. Read the item's current `quantity` and `averageCost`.
2. Pick the new cost by movement type, using `stock_cost.dart`:
   - `stockIn` → `costAfterStockIn(...)` with the movement's `unitPrice`
   - `stockOut` / `adjustment` → unchanged
3. Write back `quantity + delta`, the new `averageCost`, and `updatedAt`.
4. Return the applied `unitCost` and `averageCostAfter` so `_record` can stamp
   them onto the movement before it is filed.

**Ordering matters:** the cost must be computed from the quantity **before** the
delta is applied. Getting this backwards produces numbers that look plausible
and are wrong — the worst kind of bug here. Write the test in Stage 2 first so
this is caught immediately.

**Missing `unitPrice` on a stock-in.** The parameter is optional today. If it is
null, fall back to the item's current `averageCost` (a free delivery is not a
thing; an unrecorded price is). If both are null, leave the cost unknown rather
than treating it as zero — zero cost would quietly wipe out the item's value.

**Done when:** the Stage 2 scenarios pass end-to-end through
`MovementMutations`, not just through the pure functions.

---

## Stage 5 — Where the first cost comes from

**File:** `lib/mock_data/mutations/item_mutations.dart`

`ItemMutations.create` currently creates the item at `quantity: 0` and then
records an opening balance. It now also has to decide the starting cost, in this
order:

1. A `openingUnitCost` passed by the caller (new optional parameter).
2. Otherwise the default supplier's current price, via
   `MockQueries.defaultPriceForItem(...)`, if `defaultSupplierId` was set.
3. Otherwise **null** — cost unknown, item contributes 0 to valuation.

Route it through the movement, not around it: pass the cost as the opening
balance's `unitPrice` so the item's cost is set by its first movement like every
other change. `MovementMutations.recordOpeningBalance` needs a `unitCost`
parameter forwarded to `recordAdjustment`.

> **Note the one deliberate exception here:** an opening balance is an
> `adjustment`, and Stage 4 says adjustments never change the cost. The opening
> balance is the single case where an adjustment *sets* it, because there is
> nothing to preserve — the item has no history. Implement it as "if
> `averageCost` is null, an adjustment may set it", which states the exception
> as a rule rather than as a special case for one caller.

**File:** `lib/features/inventory/presentation/pages/add_edit_item_page.dart`

Add an optional **"Coût d'achat unitaire"** field next to the existing starting
quantity stepper (around line 244–270). Create-only, exactly like the quantity
field — never on the edit form, for the same reason quantity is not there.

If left empty, rule 2 or 3 applies. Do not block saving on it.

---

## Stage 6 — Point the valuation at the right number

**File:** `lib/mock_data/mock_queries.dart` (around line 465)

Change `_valueOf`:

```
// before
final price = defaultPriceForItem(item.id) ?? cheapestPriceForItem(item.id);
return price == null ? 0 : item.quantity * price.pricePerUnit;

// after
return valueOf(item.quantity, item.averageCost);
```

That one line is the fix landing. `stockValuation`, `valuationByCategory` and
`valuationByItem` all call `_valueOf` and need no other change.

Update the doc comment above `stockValuation`: it currently says "at each item's
default supplier price", which becomes false. Say what it now is — the cost
actually paid for the stock on hand — and why that is not the same as the
purchase price.

**Two knock-on details:**

- `valuationByItem` filters `where((row) => row.totalValue > 0)`. Items with
  unknown cost drop off the list, same as items with no supplier did before.
  Behaviour is unchanged; just know it is deliberate.
- `lib/mock_data/mock_reports.dart` holds legacy constants that its own comment
  says are superseded. Check nothing still reads them; delete what does not.

**Do not touch:** `overpayPerUnit`, `defaultPriceForItem`, `cheapestPriceForItem`,
the price comparison report, the order line auto-fill, or the stock-in price
prefill. Those are all "what will the next unit cost" and are already correct.

---

## Stage 7 — Seed the demo data

**File:** `lib/mock_data/mock_items.dart`

Every seeded item needs an `averageCost`. Without it the whole demo values at 0
and the dashboard reads as broken.

**Do not** try to replay `mockStockMovements` to derive it. The seeded log covers
about three weeks and does not reach back to each item's opening balance, so a
replay would produce confident nonsense.

Instead, write a literal `averageCost` per item, chosen **deliberately below the
current default supplier price** for a handful of items — the ones whose prices
were seeded as having risen recently. That way the demo shows the fix doing
something: valuation is visibly *not* `quantity × today's price`, which is the
whole point being demonstrated.

**File:** `lib/mock_data/mock_stock_movements.dart` — leave alone. The seeded
movements do not need `unitCost` / `averageCostAfter` populated; those fields are
nullable and the history screen shows them only when present.

**Phase 2 note worth writing into the file:** against real storage the log *will*
be complete from each item's first day, so a replay migration is the correct way
to backfill there. Every `stockIn` already stores its `unitPrice`, so the data
needed is present. This is a seed-only shortcut, not the migration strategy.

---

## Stage 8 — The figures this unlocks

**File:** `lib/mock_data/mock_queries.dart`

Now that a movement carries `unitCost`, real money figures become available for
the first time:

- **`consumptionValue(storeId, {from, to})`** — Σ `|quantity| × unitCost` over
  `stockOut` movements. Cost of goods sold.
- **`wasteValue(storeId, {from, to})`** — the same, filtered to `waste` and
  `spoilage` reasons. **This is the number the owner will care about most**: the
  euros they threw in the bin this month. It has never been computable before.
- **`shrinkageValue(storeId, {from, to})`** — Σ over `adjustment` movements with
  a negative quantity.

Surface waste value on the usage report
(`lib/features/reports/presentation/pages/usage_report_page.dart`), which today
shows quantities only.

This stage is optional for fixing the bug and is the reason to have done the
rest. Ship it in the same pass if there is room.

---

## Stage 9 — The minimum UI

Small and factual. No new screens.

| File | Change |
|---|---|
| `lib/features/inventory/presentation/widgets/item_detail_view.dart` | Show "Coût moyen du stock" next to the existing default/cheapest price block (~line 48). Two numbers side by side is what teaches the user the difference. |
| `lib/features/stock_movement/presentation/widgets/movement_row.dart` | Show `unitCost` on the row when present. |
| `lib/features/reports/presentation/pages/stock_valuation_report_page.dart` | Add a one-line caption: valued at cost paid, not at current purchase price. |
| `lib/features/inventory/presentation/pages/item_price_history_page.dart` | Leave alone — it is about supplier prices, which have not changed meaning. |

---

## Stage 10 — Strings

**File:** `lib/l10n/app_fr.arb`, then regenerate.

New keys, French first (the app is French-only today):

| Key | FR |
|---|---|
| `itemFormOpeningCost` | Coût d'achat unitaire |
| `itemFormOpeningCostHelp` | Optionnel — sinon le prix du fournisseur par défaut est utilisé |
| `itemAverageCost` | Coût moyen du stock |
| `valuationAtCost` | Valorisé au coût d'achat réel |
| `movementUnitCost` | Coût unitaire |
| `reportWasteValue` | Valeur des pertes |

`tool/add_arb_keys.py` exists for this — use it rather than hand-editing.

---

## Stage 11 — Make the rule mechanical

**File:** `tool/ux_audit.py` (around line 164)

The existing check catches `mockItems[…] =` outside the mutation layer. Extend
the same idea to cost:

- Flag any assignment to `averageCost` outside
  `lib/mock_data/mutations/` and `lib/core/utils/stock_cost.dart`.
- Flag any `pricePerUnit` read inside a function whose name contains `valuation`
  or `value` — that is precisely the mistake being fixed, and it will be
  reintroduced by someone who does not know the history.

A rule that only lives in a document gets broken in six months. This one gets
broken in CI instead.

---

## Stage 12 — Tests

**New file:** `test/stock_cost_test.dart` — the pure-function table from Stage 2.

**Extend `test/inventory_test.dart`:**

- Creating an item with a starting quantity and a cost sets `averageCost`
- Creating one with no cost and no default supplier leaves it null, and the item
  contributes 0 to the valuation
- A stock-out leaves `averageCost` untouched
- An adjustment leaves `averageCost` untouched
- Stock going negative then receiving resets the cost to the delivery price

**Extend `test/orders_test.dart`:**

- **The headline test:** seed 100 @ 8.00, receive 50 @ 10.00, assert valuation is
  **1300**, not 1500. Name it after the bug so nobody deletes it by accident.
- Receiving still writes the price history entry and updates `SupplierPrice`
  (Stage 3's refactor must not have broken it)
- A partial receipt across two deliveries at two prices averages across all
  three states correctly

All of these use `restoreMockData()` from `test/support/mock_reset.dart` in
`setUp`, like every existing suite.

---

## Stage 13 — Update the documentation

**File:** `DOMAIN_MODEL.md`

- **Step 4** — add `averageCost` to the `Item` field table.
- **Step 5** — sharpen the "no price on the item" note: price is still not on the
  item; *cost* is, and they are different questions.
- **Step 7** — add `unitCost` and `averageCostAfter` to the movement table, plus
  the three cost rules (in remixes, out never moves it, adjustment never moves
  it).
- **Step 11** — rewrite the valuation row: `quantity × averageCost`.
- **Step 15** — add the rules: *cost is remixed only on stock-in*, and *purchase
  price and stock cost are two different numbers*.

---

## Order of work, and what is safe to defer

| Stage | Must ship together | Note |
|---|---|---|
| 0–2 | Yes | Engine + tests. Nothing user-visible. |
| 3 | Yes | Refactor. Must land before 4 or the logic gets written twice. |
| 4–7 | Yes | This is the fix. Shipping 6 without 7 values the demo at 0. |
| 9–10 | Yes | Without the item-detail number, users see a valuation change with no explanation. |
| 11–13 | Yes | Cheap, and the audit rule is what stops the regression. |
| 8 | **Can defer** | Pure gain, no dependency. Ship it when there is room. |

**Rough shape:** Stages 0–7 are the real work. Stages 9–13 are half a day
between them. Stage 8 is a separate, smaller pass.

---

## Risks, named

| Risk | Mitigation |
|---|---|
| Cost computed from the post-delta quantity | Stage 2's tests fail loudly. Write them before Stage 4. |
| Stage 3's refactor silently breaks price-history writing on receipt | Explicit test in Stage 12. |
| Demo valuation drops to 0 | Stage 7 is not optional. |
| `copyWith` cannot clear `averageCost` to null | Known and accepted — cost is only unknown at creation. Do not pretend it is clearable. |
| Someone reintroduces `pricePerUnit` into a valuation later | Stage 11's audit rule. |
| The valuation figure changes and looks like a new bug to the client | It is a correction, not a regression. Say so in the release note, with the 100 @ 8 + 50 @ 10 example — it explains itself in one line. |

---

## Acceptance: one scenario decides it

```
Given  100 kg of chicken at 8.00 €/kg     → valuation 800 €
When   a delivery of 50 kg at 10.00 €/kg is received
Then   quantity is 150 kg
And    averageCost is 8.666… €/kg
And    valuation is 1 300 €          (today it says 1 500 €)
And    the supplier price on file is 10.00 €/kg
And    a price history entry records 8.00 → 10.00
```

The last two lines matter as much as the third: the purchase price **must** still
update to 10.00 €. The fix is not "stop updating the price" — it is "stop letting
the purchase price decide what the old stock was worth".
