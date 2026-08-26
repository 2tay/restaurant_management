# How the Data Works (Models, Relations and Rules)

This file explains the **logic** of the app: what each model is, how models are
connected, and what rules the app follows when something is written.
No UI here — no screens, no widgets. Just the data and the rules.

Read it top to bottom. Each part builds on the one before it.

---

## Step 1 — The one big idea

Most inventory apps put a `price` field on the product. This app does **not**.

Why: one product (chicken breast) can be bought from **three different
suppliers** at **three different prices**. If price lived on the product, you
could only store one of them, and comparing suppliers would be impossible.

So the rule is:

> **Price belongs to the pair (item + supplier), not to the item.**

That single decision is the reason the model looks the way it does. Everything
else follows from it.

The second big idea:

> **Only a stock movement can change an item's quantity.**

Nothing else. Not the item edit form, not an order, not a receipt directly.
Every change of quantity leaves a line in the movement log. This is what makes
the log trustworthy:

```
item.quantity == opening balance + sum of all its movements
```

If any screen could set a quantity directly, that equation would break and the
history would look complete while being wrong — worse than having no history.

The same writer also maintains each item's **average cost**, for the same
reason. And that leads to the third idea, which follows from the first:

> **A purchase price and a stock cost are different numbers.**

See Step 5a — it is the rule that keeps the stock valuation honest.

---

## Step 2 — The container: Store

Everything belongs to a store.

`Store` = one restaurant location (name, address, phone, created date).

An owner account can have several stores. Almost every other model carries a
`storeId`, which means: this row is only visible inside that store.

Models that carry `storeId`: `Item`, `Category`, `UnitOfMeasure`, `Supplier`,
`StockMovement`, `PurchaseOrder`, `GoodsReceipt`, `NotificationItem`.

Models that do **not** carry `storeId` (they inherit it from their parent):
`SupplierPrice`, `PriceHistoryEntry`, `PurchaseOrderLine`, `GoodsReceiptLine`.

`TeamMember` is different: it holds a **list** of `storeIds`, because one person
can work in several stores.

---

## Step 3 — The catalogue: Category and Unit

Before you can create a product, you need two small reference tables.

**`Category`** — "Fruits & Légumes", "Viandes", "Boissons".
Fields: `id`, `storeId`, `name`.

**`UnitOfMeasure`** — how you count the product.
Fields: `id`, `storeId`, `name` ("Kilogramme"), `abbreviation` ("kg").

Both are created by the user inside the app, never hardcoded. A Belgian kitchen
counts beer in `bac` and vegetables in `caisse`; no fixed list would guess that.

Two rules apply to both:

1. **Names are unique inside a store**, ignoring case and spaces. "Boissons" and
   "boissons " are the same category with a typo. For units, the *abbreviation*
   is also checked, because two units both showing "cs" would make every
   quantity in the app ambiguous.
2. **You cannot delete one that is in use.** Items point at a category and a
   unit by `id`. Deleting one in use would leave those items pointing at
   nothing.

Note: accents are **not** folded. "Épicerie" and "Epicerie" are treated as
different names, so a user can rename one into the other to fix a typo.

---

## Step 4 — The product: Item

`Item` = one stocked product.

| Field | Meaning |
|---|---|
| `id` | internal id |
| `storeId` | which store owns it |
| `name` | "Blanc de poulet" |
| `categoryId` | → `Category` |
| `unitId` | → `UnitOfMeasure` |
| `quantity` | how much is on hand **right now**, in that unit |
| `lowStockThreshold` | when to start warning |
| `updatedAt` | last time the quantity or details changed |
| `averageCost` | what one unit of the stock **on hand** cost, in EUR. Null = unknown |
| `defaultSupplierId` | supplier pre-selected when receiving (optional) |
| `barcode` | optional, unique inside the store |
| `note` | free text |

**There is no price field. On purpose.** See Step 1.

**`averageCost` is not an exception to that.** A price and a cost answer two
different questions pointing in opposite directions in time — see Step 5a.

### Stock status (calculated, not stored)

```
quantity <= 0                    → outOfStock   ("Rupture de stock")
quantity <= lowStockThreshold    → lowStock     ("Stock faible")
otherwise                        → inStock
```

This is computed from the two numbers every time it is needed, so it can never
be stale.

### Barcode

Optional, and usually absent — meat, fish, bread and produce arrive loose with
nothing to scan. Roughly half the catalogue (drinks, packaged goods) has one.

- Empty input is stored as `null`, never as `""`, so "no barcode" is one value
  and not two.
- Unique inside a store. When editing an item, the uniqueness check ignores the
  item itself, otherwise saving an unchanged item would fail against itself.
- Lookup by barcode returns a **list**, not a single item — because "a case and
  a single bottle of the same beer" is the likely next requirement, and a
  list-shaped lookup absorbs that without rewriting every caller.

---

## Step 5 — The supplier and the price link

`Supplier` = one company you buy from. Belongs to one store.
Fields: `id`, `storeId`, `name`, `contactName`, `email`, `phone`, address, `note`.

Supplier names are **not** unique. Two branches of the same butcher is a real
situation; blocking it would invent a rule the business does not have.

### `SupplierPrice` — the heart of the model

This is the **link table** between an item and a supplier, and the **only place
a price lives**.

| Field | Meaning |
|---|---|
| `id` | internal id |
| `itemId` | → `Item` |
| `supplierId` | → `Supplier` |
| `pricePerUnit` | in EUR, per one of the item's units |
| `effectiveDate` | when this price started applying |
| `isDefault` | is this the supplier normally used for this item |

The relation is **many-to-many**:

```
Item  1 ────< SupplierPrice >──── 1  Supplier
```

One item can have many `SupplierPrice` rows (one per supplier).
One supplier can have many `SupplierPrice` rows (one per item they sell you).

### Rules on the default supplier

- **At most one default per item.** Setting a new default clears the old one
  first.
- **The first supplier linked to an item automatically becomes the default**,
  even if the caller did not ask. An item with prices but no default has no
  auto-fill anywhere, which looks like a broken feature.
- **If the default is removed, the cheapest remaining supplier is promoted.**
  Otherwise the item silently keeps its suppliers but loses auto-fill on every
  order line and stock-in, and nothing on screen explains why.
- Linking an item to a supplier that is already linked **fails**. That is an
  edit, not a new link, and the edit path is the one that writes history.

### Deleting a supplier

Blocked while they have an **open order** (sent or partial) — deleting would
orphan a document that is sitting in someone's inbox, plus any stock movements
it already produced.

When deletion is allowed:
- their `SupplierPrice` rows are deleted,
- their `PriceHistoryEntry` rows are deleted,
- items where they were the default get the cheapest remaining supplier promoted,
- **their `StockMovement` rows are kept**, and
- **their closed orders are kept**.

Why keep the movements? A movement is the record of goods that really moved. The
supplier going away does not unmake that. The movement keeps the id and renders
as "Fournisseur supprimé" — which is true — instead of being erased, which
would not be.

---

## Step 5a — Price is not cost

This is the second big idea, and it is the one most people get wrong.

| Question | Direction | The number |
|---|---|---|
| "What will it cost me to buy more?" | **Future** | `SupplierPrice.pricePerUnit` |
| "What is the stock in my fridge worth?" | **Past** | `Item.averageCost` |

They are different numbers and they must never be swapped.

### Why this matters — the bug this rule exists to prevent

The app used to value stock at `quantity × the default supplier's price`. That
is wrong, and it gets worse the longer the app is used:

- You hold 100 kg of chicken bought at 8 €/kg → worth **800 €**
- A delivery arrives: 50 kg at 10 €/kg → that cost **500 €**
- Truth: 150 kg, **1 300 €** spent
- Old app: 150 × 10 = **1 500 €** ❌

It silently revalued the old 100 kg from 8 € to 10 €, inventing 200 € that
nobody ever spent — on the one screen an owner reads to find out what they are
holding. A price *drop* invented a loss the same way.

### The method: weighted average cost (CUMP)

One cost per item. Remixed when stock comes in, untouched when it goes out.

**Stock in** — the only thing that moves the cost:

```
newAverageCost = (oldQuantity × oldAverageCost + inQuantity × inPrice)
                 / (oldQuantity + inQuantity)
```

The old stock keeps the cost it was bought at. Only the arriving units come in
at the new price. In the example: `(800 + 500) / 150 = 8.6667 €/kg`, and
`150 × 8.6667 = 1 300 €`. Correct.

**Stock out** — never moves the cost. Consuming stock cannot change what the
stock still in the fridge cost you. What it *does* give you is a number that did
not exist before: `quantity × averageCost` is the money that left with it.

**Adjustment** — never moves the cost either. No invoice was involved. Units
found join at the current average; units missing leave at it, and that product
is the shrinkage in euros.

### The three edge cases

| Situation | Rule | Why |
|---|---|---|
| Nothing on hand | Cost becomes the delivery price | Nothing to average against, and the maths already agrees |
| **Negative** stock | Cost is **reset** to the delivery price | The old baseline is already known-wrong (a delivery went unrecorded). Averaging against it spreads the error, and can produce a negative average |
| Cost unknown (`null`) | Item contributes **0** to the valuation | Understating beats inventing — the same rule the valuation already followed |

### Where the first cost comes from

An article's opening balance can carry a purchase cost, entered on the create
form next to the starting quantity. It is optional. Left empty, the cost stays
unknown and the article is left out of the valuation until a real delivery tells
it what stock costs.

There is deliberately **no fallback to a supplier price**, because at creation
there is none: `defaultSupplierId` records a preference, not a `SupplierPrice`
link, and the link cannot exist for an article that did not exist a moment ago.

### What did *not* change

Everything about purchasing still reads `SupplierPrice`, and correctly so:
order line auto-fill, the stock-in price prefill, the price comparison report,
the overpay figure, and the price history a receipt writes. A delivery at a new
price **still** updates the supplier's price on file. The fix was never "stop
updating the price" — it was "stop letting the purchase price decide what the
old stock was worth".

---

## Step 6 — Price history

`PriceHistoryEntry` = one recorded change of one supplier's price for one item.

| Field | Meaning |
|---|---|
| `itemId`, `supplierId` | which pair this is about |
| `oldPrice`, `newPrice` | the change |
| `changedAt` | when |
| `changedByName` | who |

It is scoped to the **pair**, not to the item. The question it answers is:
"what has Metro charged us for chicken breast over the last six months?"

History is written in exactly two places:

1. Someone edits the price by hand (`updatePrice`).
2. A delivery arrives at a different price than the one on file (see Step 9).

Setting the same price again writes nothing. Prices of `0` or less are refused.

Case 2 is the important one: it means **price history maintains itself**. Prices
update as deliveries arrive, not when someone remembers to sit down and edit
them.

---

## Step 7 — Stock movements: the only way quantity changes

`StockMovement` = one change to one item's quantity.

| Field | Meaning |
|---|---|
| `id`, `storeId`, `itemId` | what it is about |
| `type` | `stockIn`, `stockOut` or `adjustment` |
| `quantity` | **signed**: + for in, − for out, signed by direction for an adjustment |
| `occurredAt` | when |
| `userName` | who recorded it |
| `supplierId` | stockIn only |
| `unitPrice` | stockIn only — the price actually paid |
| `reason` | stockOut only |
| `systemQuantity` | adjustment only — what the app believed |
| `countedQuantity` | adjustment only — what the count found |
| `unitCost` | the cost per unit **this** movement applied |
| `averageCostAfter` | the item's average cost once this movement landed |
| `orderId` | the commande, if this came from one |
| `receiptId` | the receipt that generated it, if any |
| `note` | free text |

Only some fields are filled, depending on `type`. One table with nullable fields
keeps the history list trivial to render.

`unitCost` and `averageCostAfter` are filled on **every** type. They are what
make the average cost auditable: you can read down an item's history and watch
the cost move from 8.00 to 8.67 on the day of a delivery, and see exactly which
delivery did it. Same reasoning as an adjustment storing both counts instead of
only their difference — two numbers explain themselves, one does not.

On a stock out or an adjustment, `|quantity| × unitCost` is the money value of
what left. That is what lets a waste line finally answer *how many euros went in
the bin*, not just how many kilos.

### The three types

**`stockIn`** — a delivery arrived. Carries the supplier and the price paid.
Two ways it can happen:
- from receiving a commande → `orderId` and `receiptId` are set,
- manual, someone bought 5 kg of tomatoes at the market → both are `null`.

Both paths are legitimate; both land in the same log.

**`stockOut`** — stock was consumed or lost. Carries a reason:

| Reason | Meaning |
|---|---|
| `sale` | sold to a customer — the normal case |
| `waste` | thrown away: offcuts, dropped, burnt |
| `spoilage` | expired or spoiled |
| `transfer` | moved to another store on the same account |

The quantity is stored **negative**, whatever sign the caller passes, so the log
always adds up.

**Nothing stops stock-out taking an item below zero, on purpose.** Refusing
would make staff either lie to the app or stop using it. Negative stock is a
useful signal in itself: it means a delivery was never recorded. The app warns,
then lets it through; an adjustment is how it gets fixed.

**`adjustment`** — a physical count disagreed with the system, so the system was
corrected. It stores **both numbers**, not just the difference, because "we
thought 40, we counted 31" is the useful record and "−9" alone is not. The
stored `quantity` is `counted − system`, so the log still sums correctly.

### What each type does to the cost

| Type | Quantity | Average cost |
|---|---|---|
| `stockIn` | + | **remixed** — old stock keeps its cost, new units join at the price paid |
| `stockOut` | − | untouched |
| `adjustment` | ± | untouched — *except* the opening balance, below |

A stock-in with no `unitPrice` recorded falls back to the item's current average,
leaving the cost where it was. An unrecorded price is not a price of zero, and
treating it as one would drag the average towards nothing and quietly destroy
the item's value.

### Opening balance

When you create an item with 40 kg already in stock, the app does **not** write
40 onto the item. It creates the item with `quantity: 0`, then records an
**adjustment from 0 to 40**.

Two reasons:
1. Creating an item with stock in it *is* a stock change; setting the number
   directly would leave the movement log incomplete from day one.
2. The new item's history opens with a line explaining where the stock came
   from, instead of an unexplained 40 with no entries — which reads as a bug.

The opening balance is also **the one adjustment allowed to set a cost**, since
there is no earlier cost to preserve. That is written as a rule — *an adjustment
may set a cost that is not yet known, and may never change one that is* — rather
than as a special case for one caller.

### What this means for editing an item

The item edit form has **no quantity field**. Changing stock from a routine edit
screen would be an untraceable stock change hidden inside an everyday action.
The form shows the quantity as a fact and links to the adjustment screen, which
exists for exactly this and leaves a movement behind.

---

## Step 8 — Purchase orders (commandes)

`PurchaseOrder` = a document sent to **exactly one** supplier.

| Field | Meaning |
|---|---|
| `id` | internal id |
| `storeId` | which store |
| `supplierId` | exactly one supplier |
| `reference` | human number, `CMD-2026-014` — what staff quote on the phone |
| `status` | see below |
| `createdAt` | when the draft was started |
| `sentAt` | when it was sent — `null` while a draft |
| `closedAt` | when it became final (received or cancelled) |
| `lines` | list of `PurchaseOrderLine` |
| `note` | free text |

Single-supplier is structural, not a convention: a commande is a document you
send to somebody, and "somebody" must be one company. It is also what lets the
line editor filter the item picker and auto-fill prices.

`PurchaseOrderLine`:

| Field | Meaning |
|---|---|
| `itemId` | → `Item` |
| `quantityOrdered` | what you asked for |
| `quantityReceived` | accumulates across deliveries; starts at 0 |
| `unitPrice` | auto-filled from the supplier's current price, then editable |
| `closedShort` | the receiver accepted a short delivery and closed the line |

`unitPrice` is editable because negotiation happens: the ordered price is what
the supplier agreed to, not what is on file.

### The status flow

```
draft ──send──> sent ──receive──> partial ──receive──> received
  │                │                 │                    ▲
  │              cancel              └──── closeShort ─────┘
  │                ▼
  └── delete    cancelled
```

| Status | Meaning |
|---|---|
| `draft` | being built. Fully editable and deletable — nothing was sent |
| `sent` | the supplier has it. **Locked** |
| `partial` | some lines received, some outstanding |
| `received` | fully received, or closed short. Final |
| `cancelled` | cancelled before anything arrived. Final |

**The rule the whole feature hangs on:**

> **No status change moves stock. An order is a document. Only a receipt moves
> stock.**

Creating an order for 50 kg of tomatoes does not put 50 kg on the shelf.

### Transition rules

- **Editable only while `draft`.** Once sent, the supplier holds a copy, and an
  order that quietly disagrees with the document in their inbox is worse than
  no order at all.
- **Delete only a `draft`.** Nothing outside the app knows it existed, so there
  is nothing to audit. Sent orders are *cancelled* instead, which leaves the
  record standing.
- **Cancel only while `sent` and nothing received.** Once goods are through the
  door they have created stock movements, and cancelling would orphan them.
  Closing short is the correct exit at that point.
- **Close short** marks the remaining lines `closedShort` and moves the order to
  `received`. It does **not** trim `quantityOrdered` down to what arrived.

That last point matters: ordered 10, received 8, closed short → the line still
says 10 were ordered. Rewriting it to 8 would erase the only record that this
supplier under-delivered, which is exactly the figure an owner needs.

### Calculated figures (never stored)

```
lineTotal        = quantityOrdered × unitPrice
lineOutstanding  = 0 if closedShort, else max(0, ordered − received)
lineShortfall    = closedShort ? max(0, ordered − received) : 0
lineIsSettled    = closedShort OR received >= ordered

orderTotal       = sum of lineTotal
orderOutstanding = sum of lineOutstanding
orderIsOpen      = status is sent or partial
orderIsEditable  = status is draft
orderCanReceive  = orderIsOpen AND at least one line not settled
orderCanCancel   = status is sent AND every line has received == 0
statusAfterReceipt = all lines settled ? received : partial
daysOpen         = now − (sentAt ?? createdAt)
orderIsStale     = status is partial AND daysOpen > store threshold (default 7)
```

`daysOpen` counts from **when it was sent**, not from the last delivery: an
order half-delivered three weeks ago and topped up yesterday is still an order
that has been open three weeks.

---

## Step 9 — Goods receipts: the only path that moves stock through an order

`GoodsReceipt` = one delivery actually arriving against a commande.

| Field | Meaning |
|---|---|
| `orderId` | which commande |
| `storeId` | which store |
| `receivedAt` | when the van arrived |
| `receivedByName` | who stood at the door and checked it in |
| `lines` | list of `GoodsReceiptLine` |
| `note` | free text |

One order can have **many** receipts — a supplier can deliver in several trips.

`GoodsReceiptLine`:

| Field | Meaning |
|---|---|
| `itemId` | → `Item` |
| `quantityOrdered` | what was **still outstanding on that day** |
| `quantityReceived` | what actually turned up |
| `actualUnitPrice` | the price on the delivery note |
| `closedShort` | short delivery, and the receiver said the rest is not coming |
| `wasUnordered` | the driver brought something not on the order |
| `note` | "2 cageots abîmés, repris par le chauffeur" |

`quantityOrdered` is **copied onto the receipt** instead of being read back from
the order later. That is deliberate: the order gets received again and its own
figures move, but the receipt must keep saying what was outstanding *on the
day*, or the discrepancy record quietly rewrites itself.

Unordered items are **allowed**. Refusing would just send staff to the manual
stock-in screen and lose the link to the delivery. But it is flagged on the line
and on the receipt: an unordered item arriving is exactly the kind of thing that
should never be invisible.

### What confirming a receipt does, in order

1. **Writes the `GoodsReceipt`.** Permanent: never edited, never deleted. A
   correction is a fresh stock adjustment, so the trail stays readable.
2. **Creates one `stockIn` movement per received line**, carrying `orderId` and
   `receiptId`, and moves the item's quantity. Lines with 0 received are
   skipped.
3. **Adds the received quantities onto the order's lines** and marks any line
   the receiver closed short. Unordered lines are not folded into the order —
   they were never on it.
4. **Recomputes the order status**: `received` if every line is settled,
   otherwise `partial`.
5. **Handles the price**, per line:
   - no price on file for this item+supplier → create the `SupplierPrice` link
     (and make it the default if the item has no other supplier),
   - price on file is the same (within 0.001) → do nothing,
   - price on file is different → write a `PriceHistoryEntry` **and** update the
     `SupplierPrice` to the new price and date.

Step 5 compares against the price **on file**, not against the ordered price.
Normally the two are the same (the order auto-fills from the file), but where
they have drifted, the file is what the comparison report reads, so the file is
what must end up correct.

### Receipt-line outcomes

```
wasUnordered           → unordered
received < ordered     → short
received > ordered     → over
received == ordered    → complete
```

Anything other than `complete` is a **discrepancy** worth looking at twice.
Over-delivery is allowed but flagged, because it affects cost.

A unit price moving more than **15%** asks the receiver to confirm before
saving. Below that, the change is recorded silently. 15% catches the two cases
worth interrupting for — a real increase the owner must know about, and a typo —
while letting normal fresh-produce drift through without a dialog every
delivery. If the old price is 0 or less there is no percentage to move by, so
nothing is flagged (otherwise every first delivery would be).

---

## Step 10 — The full traceability chain

This is the payoff of all the rules above. Every number on screen can be walked
back to its cause, in both directions:

```
Item.quantity
   ↑ sum of
StockMovement (orderId, receiptId, supplierId, unitPrice)
   ↑ generated by
GoodsReceipt (receivedAt, receivedByName)
   ↑ against
PurchaseOrder (reference, sentAt)
   ↑ addressed to
Supplier
```

And on the money side:

```
SupplierPrice (current price for item+supplier)   ← what the NEXT unit costs
   ↑ updated by
GoodsReceipt line at a different price
   ↑ which also wrote
PriceHistoryEntry (oldPrice → newPrice, when, who)
```

And the cost side, which runs parallel to it and must never be confused with it:

```
Item.averageCost                                  ← what the CURRENT units cost
   ↑ remixed by
StockMovement.unitCost / averageCostAfter  (stock in only)
   ↑ which is also what values
consumed / wasted / shrunk stock, in euros
```

---

## Step 11 — Derived numbers (calculated, never stored)

These are computed from the data on demand. Storing them would let them go
stale and contradict the screen two taps away.

| Number | How |
|---|---|
| Stock status | `quantity` vs `lowStockThreshold` |
| Stock valuation | Σ (`item.quantity` × `item.averageCost`) — see Step 5a |
| Consumed value | Σ (`|quantity|` × `unitCost`) over stock-out movements |
| Waste value | the same, filtered to `waste` and `spoilage` |
| Shrinkage value | the same, over downward adjustments |
| Overpay per unit | default supplier price − cheapest supplier price |
| On-order quantity | Σ `lineOutstanding` across all **open** orders for that item |
| Low-stock list | items at or below threshold, worst first |
| Suggested order lines | this supplier's items that are at or below threshold |

Two details worth knowing:

- **Items with no cost on file contribute 0 to the valuation**, not a guessed
  price. Understating is the safer direction: a valuation built partly on
  invented numbers is worse than one that is visibly incomplete.
- **Low-stock alerts fire on what is physically in the store**, not on
  on-hand + on-order. Goods in a van do not cook dinner. But an item that is low
  *and already ordered* is displayed differently from one that is low and nobody
  has acted — that is what `onOrderQuantity` is for.

---

## Step 12 — Deleting things: what blocks what

| You delete | Blocked when | Cascades to | Kept |
|---|---|---|---|
| `Category` | any item uses it | — | — |
| `UnitOfMeasure` | any item uses it | — | — |
| `Item` | it is on an **open** order | its `SupplierPrice`, `PriceHistoryEntry`, `StockMovement` | — |
| `Supplier` | they have an **open** order | their `SupplierPrice`, `PriceHistoryEntry` | their `StockMovement`, their closed orders |
| `SupplierPrice` (unlink) | never | — | the pair's `PriceHistoryEntry` |
| `PurchaseOrder` | anything except `draft` | its lines | sent orders are cancelled instead |
| `GoodsReceipt` | **always** — never deletable | — | everything |

Deleting an item does destroy history, which sits uneasily next to "a confirmed
receipt is permanent". The difference is that this is an explicit, confirmed,
named act, and the alternative is worse: movements and prices pointing at an
article that no longer exists render as "—" with no way to work out what they
used to say. The confirmation dialog states the counts, which is what makes it
honest.

---

## Step 13 — Supporting models

**`TeamMember`** — someone with access.

| Field | Meaning |
|---|---|
| `fullName`, `email` | who; email is unique across the team |
| `role` | `owner`, `manager` or `staff` |
| `storeIds` | which stores they can see (an owner holds all of them) |
| `isActive` | false while an invitation is still outstanding |
| `invitedAt`, `lastActiveAt` | timeline |

| Role | Can do |
|---|---|
| `owner` | everything on every store, including billing and team |
| `manager` | everything on their assigned stores, except account settings |
| `staff` | record deliveries and usage, read inventory. No deleting items, no supplier management, no reports |

Only three roles on purpose: a restaurant is not an enterprise, and a
permissions matrix nobody understands is worse than none. The app also refuses
to remove the last `owner` — an account nobody can administer is not a state
worth being able to reach by accident.

**`NotificationItem`** — one entry in the notification centre.
Kinds: `lowStock`, `outOfStock`, `priceChange`, `largeAdjustment`, `delivery`.
Carries `relatedItemId` / `relatedSupplierId` so it can deep-link to the thing
it is about.

**`ValuationRow`, `TrendPoint`, `PriceComparisonRow`** — shapes for the reports.
They are not real entities; they are pre-computed results so the aggregation
never happens inside a widget.

---

## Step 14 — The whole map

```
                          ┌─────────┐
                          │  Store  │
                          └────┬────┘
        ┌──────────────┬───────┼────────┬──────────────┐
        │              │       │        │              │
   ┌────▼─────┐  ┌─────▼────┐  │  ┌─────▼────┐   ┌─────▼──────┐
   │ Category │  │   Unit   │  │  │ Supplier │   │ TeamMember │
   └────┬─────┘  └─────┬────┘  │  └─────┬────┘   └────────────┘
        │              │       │        │
        └──────┬───────┘       │        │
               │               │        │
          ┌────▼───────────────▼──┐     │
          │        Item           │     │
          │ (quantity, threshold) │     │
          └───┬───────────────┬───┘     │
              │               │         │
              │        ┌──────▼─────────▼──────┐
              │        │    SupplierPrice      │  ← the price lives HERE
              │        │  (item + supplier)    │
              │        └──────────┬────────────┘
              │                   │
              │            ┌──────▼─────────────┐
              │            │ PriceHistoryEntry  │
              │            └────────────────────┘
              │
      ┌───────▼────────┐         ┌──────────────────┐
      │ StockMovement  │◄────────│  GoodsReceipt    │
      │  (the ONLY     │ creates │  (permanent)     │
      │   quantity     │         └────────┬─────────┘
      │   writer)      │                  │ against
      └────────────────┘         ┌────────▼─────────┐
                                 │  PurchaseOrder   │
                                 │  (one supplier)  │
                                 └──────────────────┘
```

---

## Step 15 — The rules in one list

1. Price belongs to the **item + supplier pair**, never to the item.
   - A **purchase price** and a **stock cost** are different numbers: the price
     is what the next unit will cost, the cost is what the units on hand were
     paid for. Valuation uses the cost; ordering uses the price.
   - Cost is **remixed only on stock-in**, and only over the units that
     arrived. Stock out and adjustments never move it.
2. Exactly **one default supplier per item**; the first link becomes it, and the
   cheapest is promoted if it disappears.
3. **Only a `StockMovement` changes `Item.quantity`.** No exceptions.
4. Creating an item with stock records an **opening balance adjustment**, not a
   direct write.
5. **An order never moves stock.** Only a receipt does.
6. A **draft** is the only editable and deletable order.
7. A sent order can be cancelled **only while nothing has arrived**.
8. Closing short **keeps** `quantityOrdered` — the gap is the record of
   under-delivery.
9. A confirmed **receipt is permanent** — corrections are new adjustments.
10. A receipt at a new price **updates the price on file and writes history**
    automatically.
11. Stock **may go negative** — it is a real signal, not an error to hide.
12. Anything referenced by something else **cannot be deleted** while that is
    still open.
13. Every derived number (status, valuation, outstanding, overpay) is
    **calculated, never stored** — except `quantity` and `averageCost`, which
    are running totals kept on the item for speed and **rebuildable from the
    log**, because both depend on the order movements happened in.

---

## Where this lives in the code

| Concept | Files |
|---|---|
| The models themselves | `lib/models/` |
| Stock status rule | `lib/core/utils/stock_status.dart` |
| Stock cost arithmetic | `lib/core/utils/stock_cost.dart` |
| Order and receipt rules | `lib/core/utils/order_status.dart` |
| Reads / derived queries | `lib/mock_data/mock_queries.dart` |
| The only quantity writer | `lib/mock_data/mutations/movement_mutations.dart` |
| Order and receipt writes | `lib/mock_data/mutations/order_mutations.dart` |
| Supplier and price writes | `lib/mock_data/mutations/supplier_mutations.dart` |
| Item writes | `lib/mock_data/mutations/item_mutations.dart` |
| Category and unit writes | `lib/mock_data/mutations/catalog_mutations.dart` |
