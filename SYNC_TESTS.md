# Sync tests: a real restaurant with several tablets

Written 2026-10-05, branch `feat/sync-personnell-system`. The plan is in `SYNC_TESTS_PLAN.md`.
Staff management (employees, pointage, payroll, PIN) is left out on purpose. It has its own
tests (`test/db/sync_personnel_full_test.dart`).

## The short answer

The sync is in good shape for everyday use. Changes reach every tablet, nothing is lost
offline, stock adds up when several tablets work offline at the same time, a deleted row stays
deleted, and the order rules work. **104 scenarios now (96 fast, 8 on the real server). 90 pass. 14 still show a
real problem**, listed below as findings F1 to F14. Two of them mattered most for a
restaurant, and **are now fixed**: **F7** (one delivery confirmed on two tablets doubled the
stock with no warning) and **F6** (two part deliveries of one order on two tablets: the order
showed the wrong quantity received). See "Fixed" below. 12 findings remain open.

| Where | Scenarios | Pass | Known problem (skipped) |
|---|---|---|---|
| `test/db/sync_restaurant_*_test.dart` (fake server, fast) | 96 | 82 | 14 |
| `test/integration/sync_restaurant_test.dart` (real local Supabase) | 8 | 8 | 0 |
| `test/db` + `test/password_hash_test.dart` + `test/sync_screens_test.dart` | 747 | 733 | (the 14 above) |

The real-server file runs the most important cases again (offline stock on 3 tablets, delete
wins, status going backwards, cancelled and closed orders, double delivery). The real server
gives the same answers as the fake one.

## How to run

```
flutter test test/db/sync_restaurant_*                     # the 88 scenarios, ~15 s
flutter test test/db/sync_restaurant_* --dart-define=KNOWN_ISSUES=true   # also run the 16 known problems
supabase start
flutter test test/integration/sync_restaurant_test.dart --concurrency=1 --dart-define-from-file=config/local.json
```

A test for a known problem uses `skip: knownIssue('F7: …')`. It is skipped in the normal run,
so the suite stays green. With `KNOWN_ISSUES=true` it runs and fails. When a finding gets
fixed, its test starts passing; then remove the `knownIssue` from it.

## The test tools

- **`test/support/restaurant_tablets.dart`**: `Restaurant.open()` creates a restaurant with 3
  tablets (Cuisine, Bar, Bureau) on one fake server: an establishment, a category, a unit,
  Metro as supplier, and Tomates (10 kg), Oignons (20 kg) and Saumon (5 kg). Each tablet can
  go `offline()` and `online()` by itself. `settle()` syncs every tablet until nothing
  moves, then checks that **every tablet holds exactly the same rows** in every business
  table, stock included, and that nothing waits to be sent. Every scenario ends with it.
- **`test/support/fake_account_backend.dart`** now follows the real server's rules: delete
  wins (`deleted`), an order's status cannot go back (`status_backwards`), a closed or
  cancelled order stays closed (`status_closed`), and a row cannot move to another store
  (`store_changed`). Before, it only had the paid-day rules, so the fast tests could pass
  where the real server refuses. New switch: `loseAnswerOnce`, where the server saves the
  batch but the answer never reaches the tablet.

## What works (all passing)

- **Everyday sharing (A1–A6):** new, edited and deleted rows reach every tablet. A chain
  (category, unit, supplier, product, stock-in) arrives parents first. Nothing echoes back
  and forth.
- **Offline (B1–B8):** the kitchen offline all evening, two tablets offline (either one back
  first), the whole restaurant offline, a week offline with 300 movements, Wi-Fi going on and
  off, the app closed overnight. Nothing lost, nothing counted twice, the same result
  everywhere.
- **Stock math (C1–C10):** two deliveries at two prices (right average cost), two stock-outs,
  stock going below zero (both kept, alert made), a count before or after a stock-out on
  another tablet, two counts, movements arriving out of order, and 300 random movements on 3
  tablets with random Wi-Fi cuts, which give the same stock as one tablet doing them all.
- **Conflicts (D1, D4–D8, K1, K3):** the last change sent wins and is the same everywhere. An
  edit to a deleted supplier is refused and listed under « À vérifier ». Deleting on both
  tablets gives no error. Duplicate products and barcodes are kept and visible. An edit made
  while the previous one is on its way is not lost. A tablet with a wrong clock does not win
  because of it.
- **Orders (E1, E2, E4–E9, E11, E12):** received on another tablet, in two parts, a draft
  edited after it was sent (refused, told), cancelled against received (goods kept, told),
  closed short against received (stays closed, goods kept), a draft deleted while sent
  elsewhere (deleted, told), an order for a deleted supplier (no screen breaks), new prices
  from a delivery, a receipt never sent before its order.
- **Catalog and alerts (F1, F3, F5, F8, G1, G3–G5):** a duplicate category is pointed out on
  every tablet and one merge fixes it everywhere, the same for units. A supplier linked twice
  ends as one link. A busy day is the same everywhere. A low-stock alert shows everywhere,
  receiving a stock-out does not make a second one, and an alert read on one tablet is read
  everywhere.
- **Photos (H1, H2, H3b, H4):** a photo reaches every tablet, also when added offline. Two
  tablets replacing one photo end with the same photo everywhere. A photo on a deleted
  product leaves no upload stuck.
- **Network trouble (I1, I1b, I2, I3, I4, I6, I7):** **a lost answer does not count the
  stock-outs twice**. An interrupted download resumes without skipping or repeating. One
  refused change does not block the others. Failed passes are counted and nothing is lost.
  An edit made while the tablet is receiving is kept. 600 changes go in batches of 100.
- **Tablets (J1–J4, J6):** a new tablet joining after a week gets everything with the right
  stock, even while another tablet is offline. A removed tablet stops and sends nothing. An
  expired session loses nothing. A demo tablet sends nothing.

## Fixed

**F6 and F7, fixed on 2026-10-05** (`lib/data/repositories/order_ledger.dart`, called by
`SyncApplier.apply` after each page, next to the stock rebuild):

- **F6:** after receiving any order, order line, receipt or receipt line, the tablet works out
  each line's "received so far" from the order's receipts, and the status of an open order
  from its lines (a received or cancelled order is never touched). This is quiet, like the
  stock rebuild: every tablet computes the same thing, so nothing is sent. The server's copy
  of the line can stay out of date; no screen reads it. Receiving on the tablet itself still
  works as before, and a test checks that both give the same numbers.
- **F7:** each receipt line keeps what was still expected when the van arrived. Two receipts
  that saw the same expected quantity and together bring in more than it are flagged:
  - an alert « Réception en double ? Tomates », naming the order, how much each tablet
    recorded and who. It has the same id on every tablet, so it shows once; it opens the
    product, where a count corrects the stock;
  - a note under « À vérifier » on each tablet, shown once there; « Compris » makes it go
    away for good.

  Nothing is undone: a second van is possible, and only a person can tell. 4 kg + 3 kg
  against 10 expected, or a second delivery recorded after the first one was seen, is not
  flagged.

New tests: the 7 in the "F6, F7" group of `sync_restaurant_orders_test.dart`, the dismissed
note, and the real-server E2b and E3.

**Seen on the way, not caused by this work:** 3 older real-server tests fail on this branch
with or without the fix (`existing_data_test`, `sync_pull_test`, `sync_push_test`: a PIN
login answers "wrong password" after the sync). They come from the staff and credential
changes and should be looked at separately.

## Findings

Ordered by how much they matter in a restaurant. "Test" names the scenario that shows it
(catalog tests F1–F8 are scenario names, not findings).

| # | What happens | What the owner expects | Test | Weight | Proposal |
|---|---|---|---|---|---|
| **F7** ✅ fixed | Two tablets offline both confirm the **same delivery**. Both receipts are kept, so the stock goes up twice (10 kg → 30 kg instead of 20). Nothing warns anyone. Same on the real server. | The double is caught, or at least shown in « À vérifier ». | E3, E3b, real E3 | High | When receiving rows, if an order's receipts add up to more than was ordered, put a « Réception en double ? » note in « À vérifier » with a link to the order. Do not undo it automatically: a real second delivery is possible. |
| **F6** ✅ fixed | Two part deliveries of one order on two tablets offline (4 kg and 3 kg). Stock is right (+7), but the order line says **3 received**: the line is one row, and the last tablet's number replaces the other. The order can show the wrong status. | The order says 7 received. | E2b | High | Each tablet recomputes a line's received quantity from the receipts it holds, like the stock is recomputed from movements. |
| **F3** | Products, suppliers, settings and other non-staff rows send the **whole row**. Two tablets offline change two different fields of the same product (threshold on one, category on the other): one change is lost. The same goes for two different settings of the establishment. | Both changes kept. | D2, catalog test F7 | Medium | Use the "only the changed fields" sending already built for staff rows (`changed_columns`) for every table. |
| **F12** | The server saved a change but the answer was lost. Meanwhile another tablet changed the same field. The first tablet then **sends its old change again** and undoes the newer one. | The newer change stays. | I1c | Medium | The server remembers each tablet's last accepted entry (device + outbox id) and answers "already done" to a resend instead of applying it again. |
| **F13** | When the server refuses a change (`deleted`, `status_*`, `invalid`), the tablet keeps its own version. Usually the next download fixes it, but not always: if the tablet was edited while it was receiving a delete, it **keeps showing the deleted product for good**. | The tablet shows what the server has. | I3b, I6b | Medium | Send the server's row back with every refusal (`restore`, already done for paid days) and write it on the tablet. |
| **F9** | A product filed offline under a category that another tablet **deleted or merged away** ends up with a missing category. | The product lands in the kept category (merge) or the category comes back (delete). | catalog tests F2, F4 | Medium | On receiving a deleted category that still has live products: if it was merged, move them; if not, bring the category back and note it in « À vérifier ». |
| **F11** | Two tablets offline each pick a **different default supplier** for one product. Both stay "default". | One default. | catalog test F6 | Medium | When receiving, if a product has two defaults, keep the most recently changed one, the same rule as the duplicate supplier link. |
| **F8** | Two tablets offline create an order each: **both get number CMD-2026-001**. | Different numbers. | E10 | Medium | Add a short tablet code to the number, or renumber the duplicate when it is received, noted in « À vérifier ». |
| **F4** | A change made offline yesterday reaches the server after today's change and **wins**, because the last change to arrive wins. | Today's change stays, or at least someone is told. | D3 | Medium | After F3, use the `base` values (already sent for staff rows) to spot "this replaced a change you never saw" and note it in « À vérifier ». |
| **F5** | Stock is replayed by the time on each tablet. A tablet whose clock is a day behind records a delivery after a count made on another tablet; the delivery is dated before the count, so the count **swallows it** (10 kg instead of 15). | The delivery counts. | K2, K2b | Medium | Warn on the sync page when a tablet's clock is far from the server's time; on Android the clock is usually right. |
| **F10** | Two tablets offline both take Tomates under the threshold: the owner gets **two "Stock faible" alerts**. | One alert. | G2 | Low | Give a low-stock alert an id built from the product and the day, like signalements (`AccountRepository.signalId`), so both tablets make the same row. |
| **F1** | After a stock rebuild, a product's "last changed" stamp (`items.updated_at`) is different on each tablet: the rebuild stamps only where the figures moved. Stock figures are right. | Same everywhere. | conflicts test F1 | Low | Do not change `updated_at` in `StockLedger.rebuildItem`. |
| **F14** | Two tablets replace one product photo at the same time: the losing file **stays on the server** for good. | Removed. | H3 | Low | A clean-up pass that removes server photos no row names any more. |
| **F2** | A deleted product's stock figures are not rebuilt, so they can differ between tablets. Nobody can see them. | — | (left out of the comparison) | Very low | Accept. |

A side note on F7: in that scenario « À vérifier » also showed three "duplicate supplier link"
notes, one per tablet, because both receipts linked Metro to Tomates. That part is correct, but
it is noise for the user next to a problem that goes unflagged.

## Mistakes found on the way that were not app bugs

- The fake server sent booleans back as 0/1, but the real server sends `true`/`false`, and
  the app reads `is_read == true`. An alert read on one tablet looked unread elsewhere, in the
  fake only. The test link now converts them as Postgres does.
- Two of my first tests dated movements before the products' opening stock, so the opening
  count absorbed them. The tests now use dates after the opening. That behaviour is what F5
  describes when it comes from a wrong clock.
- I4 first expected no counted attempts while offline. The app counts each failed pass, which
  is right.

## Not covered here, already covered elsewhere

- Live updates starting a pass, and the retry delays: `test/db/sync_pull_test.dart` and
  `sync_service_test.dart` (the controller groups).
- Signing out with changes waiting, and a device with its own data joining an account:
  `test/db/device_access_test.dart`, `existing_data_test.dart` and
  `test/integration/existing_data_test.dart`.
- The manual test on real tablets (Phase 11, Step 11.2) still has to be done once the cloud
  project exists. Use B1, B5, C3, D4, E3, H2, J1 and J3 as the checklist.
