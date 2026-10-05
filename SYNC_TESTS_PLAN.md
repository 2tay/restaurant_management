# Plan: real-restaurant sync tests (many tablets, offline, conflicts)

## Context

`SYNC_PLAN.md` says Phases 0–10 are built and tested locally, and Phase 11 (testing and release)
is next. The existing tests mostly check **one rule at a time with two tablets**
(`test/db/sync_pull_test.dart`, `sync_conflicts_test.dart`, `sync_service_test.dart`,
`stock_ledger_test.dart`, `photo_sync_test.dart`). Most of the conflict tests are about staff.

A real restaurant is messier: 3 or 4 tablets (kitchen, bar, office PC, manager's phone), Wi-Fi
that drops in the cold room, a tablet that stays offline all evening, two people touching the
same product, deliveries received twice. The goal is to **write every realistic case as an
automated test**, run them, and get a clear list of what works and what does not.

**Out of scope (as asked):** staff management: employees, pointage/attendance, journées,
payroll, credentials and PIN rules. Those already have `sync_personnel_full_test.dart`.

**Rule for the work:** tests describe what a restaurant owner would expect. If the app does
something else, the test is **not** bent to match. It goes in the Findings list (end of this
plan), and we decide together: fix the app, or accept and document the behaviour.

---

## Step 0: Test tools to build first

### 0.1 Make the fake server follow the real server's rules

What I found: `test/support/fake_account_backend.dart` only copies the "paid day" rules. The
real `push_changes` (`supabase/migrations/…_employees.sql`, the newest version) also refuses:

- `deleted`: an edit to a row that is already deleted on the server (**delete wins**),
- `status_backwards` / `status_closed`: an order status going backwards, or changing a closed
  order,
- `store_changed`: a row moving to another store.

Without these, the fast tests would say "OK" for cases the real server refuses. Add them to
`pushChanges` in the fake, with the same reason codes and the same "send back the server's row"
(`restore`) behaviour the paid-day rule uses. Read `order_status_rank` in the SQL file and copy
its order exactly.

### 0.2 Two new "network trouble" switches on the fake server

- `loseAnswerOnce`: the server **saves** the batch, then the answer is lost (throws a network
  error). The tablet thinks it failed and will send again. This happens when Wi-Fi drops at the
  wrong second.
- `offlineDevices` (a set of device ids): any call from those devices fails with a network error.
  This lets one tablet be "offline" while the others keep working, inside the same test.

### 0.3 A small "restaurant" helper: `test/support/restaurant_tablets.dart`

Built on the code already used in `sync_pull_test.dart` (`newDevice`, `firstDay`, `SyncRunner`):

- `Restaurant.open(tablets: ['cuisine', 'bar', 'bureau'])`: one fake server, N tablets, each its
  own in-memory database, all on the same account; the first one creates the establishment,
  a category, a unit, a supplier and a few products, then everybody syncs.
- `tablet.offline()` / `tablet.online()`: uses the switch from 0.2.
- `tablet.sync()`: one pass; `restaurant.syncAll()`: passes on every online tablet, again and
  again, until nobody sends or receives anything (max 5 rounds, fails if it never settles).
- **`restaurant.expectAllTheSame()`: the most important check.** It reads every synced table
  (except staff tables) on every tablet and fails if any row differs, plus the stock quantity
  and average cost of every product. A sync that "works" but leaves two tablets showing
  different numbers is the worst bug, and this catches it in every test.
- `restaurant.expectNothingWaiting()`: outbox empty on every tablet.
- `tablet.toCheck()`: the "À vérifier" list (`SyncErrorRepository`), so a test can check the
  user was told about a refused change.

Every scenario below ends with `syncAll()` + `expectAllTheSame()` + `expectNothingWaiting()`,
on top of its own checks. I won't repeat that in each test.

---

## Step 1: The test scenarios

Each test has a short **story** (what happens in the restaurant) and **we check** (what must be
true after). Tablet names: **Cuisine**, **Bar**, **Bureau** (office PC), **Téléphone** (the
manager's phone).

### Group A: Everyday sharing, everyone online
File: `test/db/sync_restaurant_basics_test.dart`

- **A1. A new product reaches every tablet.** Bureau creates "Saumon" with a photo-less card.
  We check: Cuisine, Bar and Téléphone all show it with the same name, unit, category, threshold.
- **A2. An edit reaches every tablet.** Bureau changes the low-stock threshold of "Tomates".
  We check: the new threshold everywhere, and the old one nowhere.
- **A3. A delete reaches every tablet.** Bureau deletes a supplier with no products.
  We check: it disappears from every list, but the row still exists, marked deleted.
- **A4. A chain of changes in a row.** Bureau creates a category, a unit, a supplier, then a
  product using all three, then a stock-in, all before syncing.
  We check: the other tablets receive them in the right order (parents before children), and
  no tablet ever shows a product with a missing category or unit.
- **A5. Changes from everyone at once.** In the same minute Cuisine does a stock-out, Bar
  creates a category, Bureau edits a supplier phone.
  We check: after syncing, all three changes are on all tablets.
- **A6. Nothing echoes back.** After A5, each tablet syncs twice more.
  We check: no tablet sends or receives anything new (no endless ping-pong).

### Group B: One tablet goes offline, the others carry on
File: `test/db/sync_restaurant_offline_test.dart`

- **B1. Kitchen loses Wi-Fi during service.** Cuisine goes offline, does 10 stock-outs over the
  evening. Meanwhile Bar does 5 stock-outs online.
  We check: when Cuisine comes back, every product's stock = start − all 15 stock-outs, on
  every tablet.
- **B2. The offline tablet still sees what it had.** Cuisine offline: lists, products, stock,
  orders all still open and show the last known data. The pending count shows 10.
- **B3. The offline tablet misses changes, then catches up.** Bureau creates 3 products and
  deletes 1 while Cuisine is offline.
  We check: when Cuisine reconnects, it gets the 3 new products and the delete.
- **B4. Two tablets offline at the same time.** Cuisine and Bar both offline, both work, come
  back in different orders (Bar first, then Cuisine; then repeat the test with Cuisine first).
  We check: same final result whatever the reconnection order.
- **B5. Every tablet offline, then all back.** The whole restaurant's internet is down for
  the evening; each tablet works alone; internet returns.
  We check: everything merges, nothing is lost, stock is right.
- **B6. Offline for a long time.** Cuisine offline for "a week" (fake clock), 300 changes on
  Cuisine and 300 on the others.
  We check: it all sends in batches of 100 and receives in pages, and ends the same everywhere.
- **B7. Wi-Fi going on and off.** Cuisine goes offline / online every two passes while working.
  We check: no change is sent twice, none is lost.
- **B8. A tablet off for the night.** Cuisine is closed (database kept, app restarted next
  morning, i.e. a new `SyncRunner` on the same database) with 5 changes not sent.
  We check: the 5 changes are still waiting the next morning and go out on the first sync.

### Group C: Stock math when tablets disagree
File: `test/db/sync_restaurant_stock_test.dart`

- **C1. Two deliveries at once.** Cuisine and Bar both offline, each records a stock-in of 5 kg
  of "Tomates", at different prices.
  We check: 10 kg added on every tablet, and the same average cost everywhere.
- **C2. Two stock-outs at once.** Each takes out 3 kg offline. We check: 6 kg removed everywhere.
- **C3. Taking out more than there is.** Stock is 10. Cuisine takes out 8, Bar takes out 8, both
  offline.
  We check: both movements are kept (nobody's work is thrown away), the stock shows −6 the
  same everywhere, and a low-stock / out-of-stock alert appears. (If the app hides or blocks
  this, it is a Finding.)
- **C4. A count after a stock-out on another tablet.** Bar takes out 3 kg at 18:00, Cuisine
  counts 10 kg at 18:30 (offline, so it never saw the 3 kg go).
  We check: final stock 10 (the count saw the shelf after the stock-out).
- **C5. A stock-out after a count.** Cuisine counts 10 at 18:00, Bar takes out 3 at 18:30.
  We check: final stock 7.
- **C6. Two counts at once.** Cuisine counts 10 at 18:00, Bar counts 12 at 18:05, both offline.
  We check: the later count (12) is the result everywhere.
- **C7. Movements arrive in the wrong order.** Bar's older movement (yesterday) arrives after
  Cuisine's newer one (today).
  We check: the stock is replayed by real time (`occurredAt`), and the average cost is the same
  as if they had arrived in order.
- **C8. A stock-out on a product deleted elsewhere.** Bureau deletes "Persil", Cuisine (offline)
  takes out 1 bunch of it.
  We check: the product stays deleted everywhere (delete wins), the stock-out is either refused
  and listed in "À vérifier", or kept hidden. No tablet shows the product back.
- **C9. The opening balance.** Bureau creates a product with an opening stock; Cuisine does a
  stock-in before receiving it.
  We check: when both have everything, the quantity = opening + stock-in.
- **C10. Big replay check.** 3 tablets, 500 random movements (in, out, count) with random
  offline periods, random sync order (fixed random seed so a failure can be repeated).
  We check: every tablet ends with the same stock as replaying all movements on one database.

### Group D: The same product changed on two tablets
File: `test/db/sync_restaurant_conflicts_test.dart`

- **D1. Same field, both online.** Bureau and Téléphone both rename "Tomate" a few seconds apart.
  We check: the last one to reach the server wins, the same everywhere.
- **D2. Different fields, both offline.** Bureau changes the threshold, Téléphone changes the
  category of the same product.
  We check: what happens today (non-staff tables send the whole row, so one of the two changes
  may be lost). This is likely a Finding: the owner would expect both changes kept.
- **D3. An old offline edit arrives late.** Cuisine (offline since yesterday) changed the
  threshold to 5. Today Bureau changed it to 8 and synced. Cuisine reconnects.
  We check: what wins today (rule: last to arrive, so 5). Record it; we decide if an old edit
  should overwrite a newer one.
- **D4. Edit against delete.** Bureau deletes a supplier; Bar (offline) edits its phone.
  We check: the supplier stays deleted everywhere, Bar's edit is refused, Bar's "À vérifier"
  explains it in French, and Bar's screen no longer shows the supplier.
- **D5. Delete on both.** Both tablets delete the same product offline.
  We check: no error, no "À vérifier" entry, deleted everywhere.
- **D6. Same new product on two tablets.** Cuisine and Bar both create "Basilic" offline.
  We check: two products exist (different ids). Note whether the app warns (like the duplicate
  category notice). If not, it is a Finding.
- **D7. Same barcode on two tablets.** Both give the same barcode to two different products
  offline.
  We check: both accepted, and `barcodeConflict` shows the clash on every tablet.
- **D8. Edit during sending.** Bar edits a product while its previous change is on its way to
  the server (`duringPush` already exists).
  We check: the newer edit stays queued and goes out next, the older one does not overwrite it.

### Group E: Orders and deliveries
File: `test/db/sync_restaurant_orders_test.dart`

- **E1. An order made on the PC is received in the kitchen.** Bureau creates and sends an order;
  Cuisine receives it fully.
  We check: order "closed" everywhere, stock up on every tablet, the receipt is on every tablet.
- **E2. Part received on one tablet, the rest on another.** Cuisine receives half; later Bar
  receives the other half.
  We check: order goes partial → closed, both receipts kept, stock right.
- **E3. The same delivery received twice.** Cuisine and Bar are both offline and both confirm
  the full delivery of the same order (two people, one van).
  We check: what happens today. Receipts are add-only, so the stock may be counted twice.
  Expected by the owner: the double is at least shown ("reçu en trop" / "À vérifier"). Likely a
  Finding.
- **E4. A draft edited after it was sent.** Bureau sends the order; Téléphone (offline) still
  edits the draft lines.
  We check: the server refuses the backwards status, Téléphone gets the sent order back and is
  told in "À vérifier"; the supplier order stays as sent.
- **E5. Cancelled on one tablet, received on another.** Bureau cancels; Cuisine (offline)
  receives goods for it.
  We check: what happens today (cancelled and partial have the same rank on the server, so the
  last one wins). The goods must not vanish from stock. Record the result as a Finding to
  decide.
- **E6. A draft deleted while it is sent elsewhere.** Bureau deletes the draft; Téléphone
  (offline) sends it.
  We check: delete wins, the order disappears everywhere, Téléphone is told.
- **E7. Closed short on one, received on another.** Bureau "closes short"; Cuisine (offline)
  receives the rest.
  We check: status stays closed (`status_closed`), the receipt and the stock are kept.
- **E8. An order to a supplier deleted elsewhere.** Bar deletes a supplier; Bureau (offline)
  creates an order for it.
  We check: what happens (order kept with a deleted supplier, or refused). The order screen
  must not crash on any tablet.
- **E9. Received price updates price history.** Cuisine receives at a new price.
  We check: the supplier price and price history are the same on every tablet.

### Group F: Suppliers, categories, units, settings
File: `test/db/sync_restaurant_catalog_test.dart`

- **F1. Same category name on two tablets.** Both create "Épices" offline.
  We check: both exist, the "Fusionner" notice appears on every tablet; merging on one tablet
  moves the products and the merge reaches the others.
- **F2. Merge on one tablet while the other adds a product to the old category.**
  We check: the product ends in the kept category on every tablet, nothing is orphaned.
- **F3. Same for units** (two "Kilogramme", merge, product added meanwhile).
- **F4. A category deleted while used elsewhere.** Bureau deletes "Herbes" (empty on Bureau);
  Cuisine (offline) creates a product in it.
  We check: no tablet shows a product with no category, and the user is told.
- **F5. Same supplier linked to a product twice.** Both link "Metro" to "Tomates" offline.
  We check: one link stays (the newest), the product keeps a default supplier.
- **F6. The default supplier changed on both.** We check: one default only, the same everywhere.
- **F7. Store settings changed on both.** Bureau changes the stale-order days, Téléphone the
  notification settings, offline.
  We check: what is kept (whole row, last wins). Possible Finding like D2.
- **F8. A busy day marked on one and unmarked on the other.** We check: last one wins,
  calendar the same everywhere.

### Group G: Alerts (notifications)
File: `test/db/sync_restaurant_alerts_test.dart`

- **G1. A low-stock alert made on one tablet shows on all.** We check: one alert, everywhere.
- **G2. Both tablets cause the same alert offline.** Cuisine and Bar both take "Tomates" under the
  threshold offline.
  We check: how many alerts the owner sees after sync (ideal: one). Likely a Finding if two.
- **G3. Receiving rows never creates alerts.** Bar receives Cuisine's stock-out.
  We check: Bar does not create a second alert itself.
- **G4. Read on one tablet.** The manager marks an alert read on Téléphone.
  We check: what the other tablets show (read or still unread), and that it does not come
  back as unread later.
- **G5. Alert after a rebuild.** C3-style negative stock after merge: an alert exists and makes
  sense (no alert left saying "low" when the stock is fine, and the reverse).

### Group H: Product photos (not employee photos)
File: add to `test/db/photo_sync_test.dart`

- **H1. A photo added on Bureau appears on Cuisine** (exists; keep, run with 3 tablets).
- **H2. Photo added offline.** Bureau offline adds a photo; comes back.
  We check: the photo goes up, then shows on the others.
- **H3. Photo replaced on two tablets at once.** We check: one photo wins everywhere, the losing
  file is removed from the server, no tablet shows a broken image.
- **H4. Photo on a product deleted elsewhere.** We check: no upload loops forever, no crash.
- **H5. Photo arrives before the row / row before the photo.** We check: placeholder, then the
  photo, without a restart.

### Group I: Network trouble during a sync
File: `test/db/sync_restaurant_network_test.dart`

- **I1. The answer is lost.** (switch 0.2) The server saved Cuisine's 3 stock-outs but the answer
  never came. Cuisine sends again.
  We check: the stock-outs are counted **once**, not twice. Very important.
- **I2. Connection drops in the middle of receiving.** (`failPullAfterPages` exists) Then a
  product changes on the server before the retry.
  We check: the download resumes, nothing skipped, nothing doubled.
- **I3. Some changes refused, others accepted, in one batch.** (`rejectWhen`)
  We check: the good ones are saved, the bad ones go to "À vérifier", the queue empties, the
  tablet shows the server's version of the refused rows.
- **I4. The server is down for a long time.** Several failed passes.
  We check: the retry waits grow (5 s, 15 s, 1 min, 5 min) and the state says "Hors ligne",
  with the right pending count.
- **I5. Live update.** Bureau changes something; Cuisine's controller gets the live signal.
  We check: Cuisine pulls without waiting for the 5-minute timer.
- **I6. A tablet changes things while it is receiving.** A user edits a product on Cuisine while
  a big pull is being applied.
  We check: the local edit is not overwritten by the pull, and is sent after.
- **I7. More than one page and more than one batch.** 1,200 rows. We check: all arrive, cursor
  correct, second sync receives 0.

### Group J: Tablets joining, leaving, signing out
File: `test/db/sync_restaurant_devices_test.dart`

- **J1. A new tablet joins in the middle of service.** Cuisine and Bar have been working for a
  week; a new "Terrasse" tablet joins.
  We check: it gets everything (products, stock, orders, receipts, deleted rows stay hidden)
  with the right stock numbers.
- **J2. A new tablet joins while another is offline.** Terrasse joins while Cuisine is offline
  with changes. We check: Terrasse gets Cuisine's changes when Cuisine comes back.
- **J3. The owner removes a lost tablet.** Bar is removed while offline with 4 changes.
  We check: Bar stops syncing and says why; its 4 changes are not sent; the others are fine.
- **J4. Session expired.** Bureau's session expires with 6 changes waiting.
  We check: "Se reconnecter" appears, nothing is wiped, after reconnecting the 6 changes go out.
- **J5. Sign out with changes waiting.** We check: the warning shows the count, and after
  confirming, the local data is gone.
- **J6. A demo tablet never sends.** A tablet in demo mode works next to the real ones.
  We check: nothing from it ever reaches the server.
- **J7. A tablet with its own old data joins an account that has data.** We check: backup file
  made, account data replaces it, nothing from the old data leaks to the server.

### Group K: Wrong clocks
File: inside `sync_restaurant_conflicts_test.dart`

- **K1. One tablet's clock is 2 hours behind.** Bar's clock is wrong; Bar and Cuisine edit the same
  product. We check: the winner is decided by arrival order at the server, not by the wrong
  clock.
- **K2. Wrong clock and stock counts.** Bar (clock 1 day behind) does a count. We check: what the
  stock replay does with the count's wrong time (it sorts by `occurredAt`). Record as a Finding
  if the result surprises a person.
- **K3. Clock jumps (summer time / reset).** We check: no crash, stamps stay in UTC.

### Group L: Real server check (local Supabase)
File: `test/integration/sync_restaurant_test.dart`, run with
`flutter test test/integration/sync_restaurant_test.dart --concurrency=1 --dart-define-from-file=config/local.json`

A short version of the most important cases on the **real** server, to prove the fake server
from Step 0.1 tells the truth: B1 (offline stock-outs, 3 tablets), C1, C4, D4 (delete wins),
E3 (double delivery), E4 (status backwards), E7 (closed stays closed), I1 if it can be done
(else skipped with a note). Same pattern as `test/integration/sync_conflicts_test.dart`.

---

## Step 2: Manual test with real tablets (later, needs the cloud project)

A one-page checklist added to `SYNC_PLAN.md` Step 11.2, built from B1, B5, C3, D4, E3, H2, J1,
J3: real Windows PC + Android tablet, Wi-Fi turned off by hand. Not automated.

---

## Step 3: Run and report

1. Run each new file, then the whole `test/db` suite, then `flutter analyze`.
2. Run the integration file against `supabase start`.
3. Write **`SYNC_TESTS.md`** in the repo (easy English, like `SYNC_PLAN.md`): the list of
   scenarios, and a **Findings** table: test id, what happened, what the owner would expect,
   proposal (fix / accept and document). Failing tests for open findings are marked `skip:` with
   the finding id, so the suite stays green and nothing is forgotten.
4. No app code changes in this work, except if you say so for a finding.

Cases I already expect to become findings (from reading the code): D2 and F7 (whole-row "last
wins" can drop a change on another field), D3 (an old offline edit overwrites a newer one), E3
(double delivery), E5 (cancel vs receive), G2 (duplicate alerts), K2 (count with a wrong clock).

## Files

- Change: `test/support/fake_account_backend.dart` (server rules, `loseAnswerOnce`,
  `offlineDevices`).
- New: `test/support/restaurant_tablets.dart`; `test/db/sync_restaurant_*_test.dart`
  (basics, offline, stock, conflicts, orders, catalog, alerts, network, devices);
  `test/integration/sync_restaurant_test.dart`; `SYNC_TESTS.md`.
- Add to: `test/db/photo_sync_test.dart` (Group H).
- Reuse: `SyncRunner`, `SyncApplier`, `StockLedger`, `OutboxRepository`, `SyncErrorRepository`,
  repositories in `lib/data/repositories/`, `openEmptyDatabase` in `test/support/db_fixture.dart`.

## Verification

- `flutter test test/db/sync_restaurant_*` all pass (or skipped with a finding id).
- `flutter test test/db test/password_hash_test.dart`: the old 499 tests still pass.
- `supabase test db` (49) and the integration file pass against the local server.
- `flutter analyze`: "No issues found".
- Commit on the current branch and push (as usual).
