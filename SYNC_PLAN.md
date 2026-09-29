# Synchronisation and multi-device plan (Phase 3)

This file explains, step by step, how we add a server and multi-device sync to the app.
It is written before any code. Each phase has ordered steps. Do the phases in order: each one
depends on the ones before it.

## Where we start

Today the app works **only on one device**. All data lives in a local SQLite database, managed
with drift (`lib/data/database/`). Screens never touch the database directly. They go through
repositories (`lib/data/repositories/`). Login is fake. The sync screen and the offline banner
say that nothing syncs.

Things that already help us:

- Every new record gets a random UUID (`lib/data/repositories/new_id.dart`). Two devices will
  never create the same ID.
- Every write goes through a repository, inside a transaction.
- Stock movements, receipts and price history are "add only" records. They are easy to merge.
- The database already has a real migration system (`schemaVersion` is 14).
- Empty placeholders exist for the work: `lib/services/sync_service.dart`,
  `lib/services/api_service.dart`, `lib/services/auth_service.dart`.
- The offline banner has a `pendingChangesProvider` that returns 0. It will show the real number.

Things that block sync today:

1. Most tables do not record when a row was last changed. Only `Items` has `updatedAt`.
2. Some deletes remove the row completely (products, suppliers, categories, units, order lines,
   credentials, busy days). Other devices can never learn about the delete.
3. The stock quantity and average cost are stored on the product and changed with `+` and `-`
   on each device (`movement_repository.dart`, method `_record`). If two offline devices each
   add 5 kg, copying the final number would lose one of the additions.
4. Child tables (order lines, receipt lines, attendance sessions and pauses, supplier prices,
   price history, credentials) have no `storeId`. The server cannot easily check who may see them.
5. Passwords use `fakePasswordHash` and employee PINs are stored as plain text. That is fine
   on one device, but not once the data goes to a server.
6. Product and employee photos are local files. Other devices cannot see them.
7. The demo seed uses readable IDs like `item-tomates`. Two accounts using the demo would
   collide on the server.

## Where we want to end

- One restaurant account, many devices. The kitchen tablet, the manager's phone and the office
  PC show the same data.
- Each device keeps working offline. When the network comes back, it sends its changes and
  receives the others.
- A real login for owners and managers. Employees keep the fast PIN login on shared tablets.
- The server checks permissions. A store only ever sees its own data.
- Photos are shared between devices.
- The sync screen shows the truth: pending changes, last sync time, errors.
- If a device is lost, logging in on a new device brings back everything.

## The big design, in one page

Read this once before starting. Every phase below builds one piece of it.

- **The local database stays the source of truth for the screen.** Screens keep reading from
  drift, exactly like today. They never wait for the network.
- **Outbox (sending).** When a synced table changes, a SQLite trigger writes a line into an
  `outbox` table, inside the same transaction. A trigger cannot be forgotten, unlike a manual
  call in each repository. A background service sends the outbox to the server.
- **Pull (receiving).** The server gives every change a growing number called `server_seq`.
  Each device remembers the last number it saw and asks for "everything after N".
- **Applying pulled changes** writes rows directly into drift, with triggers switched off for
  that moment, so received changes are not sent back.
- **Derived values are not synced.** The stock quantity and the average cost are recomputed on
  each device from the movements. Movements merge safely, so the result is always right.
- **Conflicts.** By default the last change that reaches the server wins, per row. Some data
  gets special rules, checked on the server (order status, payroll, clock-in).
- **Deletes become a flag** (`deletedAt`). A deleted row stays in the database, hidden from the
  screens, so the delete can travel to other devices.

---

## Phase 0: Decisions and setup

Goal: agree on the tools and prepare the project. No app code changes.

**Step 0.1: Confirm the backend.**
We use Supabase. It gives in one service: a Postgres database, user login, file storage,
live updates ("realtime") and server functions. It has an official Flutter package,
`supabase_flutter`. If we ever change the backend, only Phases 3, 4, 5 (sending part), 6
(receiving part) and 8 change. Phases 1, 2 and 7 stay the same, because they are local.

**Step 0.2: Create two Supabase projects.**
One for development ("dev") and one for real users ("prod"). Never test on prod.

**Step 0.3: Decide how the app gets the server address and key.**
Pass them at build time with `--dart-define` (for example `SUPABASE_URL` and
`SUPABASE_ANON_KEY`). Do not write them in the code. Add a small `lib/core/config/env.dart`
that reads them. Write the commands in `README.md`.

**Step 0.4: Create a `supabase/` folder in the repo.**
It will hold the server database migrations (SQL files) and server functions, managed with the
Supabase CLI. This way the server schema is versioned in git like the app.

**Step 0.5: Write down the account model.**

- An **organization** is one restaurant business. It owns one or more **stores**.
- A **member** is a person with a real login (email and password). A member belongs to an
  organization with a role: owner or manager.
- An **employee** (the existing `Employees` table) is staff. Employees do not need an email
  login. They use their PIN on a device where a member has already signed in.
- A **device** is one installation of the app. It gets a random ID the first time it starts.

**Step 0.6: Decide what happens to the demo.**
The demo data never goes to the server. A device in demo mode works fully offline, like today.
Signing in with a real account starts from real (empty or uploaded) data. See Phase 9.

**Done when:** both Supabase projects exist, the `supabase/` folder is committed, and this plan
is agreed.

---

## Phase 1: Make the local database ready for sync

Goal: fix the six blockers listed above, **still with no network**. Everything in this phase
can be tested with the existing in-memory database tests (`test/db/`). This is the most
important phase: it is hard to change later, when real users have data.

> **Status: built** (branch `14-sync-phase-1`, schema version 15). The "As built" notes under
> some steps say where the result differs from the first plan, and why.

**Step 1.1: Make the list of synced tables and local-only tables.**

- Synced: `Stores`, `Categories`, `Units`, `Items`, `Suppliers`, `SupplierPrices`,
  `PriceHistory`, `StockMovements`, `PurchaseOrders`, `PurchaseOrderLines`, `GoodsReceipts`,
  `GoodsReceiptLines`, `Notifications`, `Employees`, `EmployeeCredentials`, `PayrollPeriods`,
  `Attendances`, `AttendanceSessions`, `AttendancePauses`, `BusyDates`.
- Local only: `Meta` (session, device ID, sync cursors), and the new `Outbox` table.

Write this list in `lib/data/database/README.md`. Every future table must be put in one list.

**Step 1.2: Add sync columns to every synced table (schema version 15).**
Add to each synced table:

- `updatedAt` (date and time, required). Set to "now" on every insert and update.
- `deletedAt` (date and time, nullable). Set when the row is deleted.

For existing rows, the migration fills `updatedAt` with `createdAt` when it exists, or the
migration time otherwise. Add the migration in `app_database.dart` under `if (from < 15)`, then
regenerate drift code and the schema dump (`drift_schema_v15.json`), like previous versions.

**Step 1.3: Add `storeId` to child tables.**
Add a `storeId` column to `PurchaseOrderLines`, `GoodsReceiptLines`, `AttendanceSessions`,
`AttendancePauses`, `SupplierPrices`, `PriceHistory` and `EmployeeCredentials`. The migration
fills it from the parent row (order, receipt, attendance, session, item, employee). Update the
mappers in `lib/data/mappers/` and the repositories that insert these rows. The server needs
this column to check permissions quickly.

**Step 1.4: Set `updatedAt` automatically.**
Do not rely on each repository remembering it. Add one helper used by every write (or a SQLite
trigger `AFTER UPDATE` that sets `updatedAt` when it did not change). Pick one way and use it
everywhere. Read the time through `clock.now()` like the rest of the app, so tests can fix it.

> **As built:** both. Inserts use a client default that reads `clock.now()`. Updates use one
> `AFTER UPDATE` trigger per table (`lib/data/database/sync_triggers.drift`). The stamp is
> **stored in UTC**: SQLite's `localtime` depends on how the library was built, and the Windows
> one returns nothing, so the trigger could not write local time.

**Step 1.5: Replace hard deletes with soft deletes.**
In each repository that calls `_db.delete(...)` on a synced table, set `deletedAt` instead:
`catalog_repository.dart`, `item_repository.dart`, `supplier_repository.dart`,
`order_repository.dart`, `credential_repository.dart`, `calendar_repository.dart`.
Keep the product image file deletion for now. Phase 8 moves it to cloud storage.

**Step 1.6: Hide deleted rows in every read query.**
Every select on a synced table must add `deletedAt IS NULL`. Go through each repository one
by one. Add a test per repository: "a deleted row no longer appears in lists".
Tip: search for `_db.select(` and check every result.

**Step 1.7: Make stock quantity and average cost "derived".**
Create one function, for example `rebuildItemStock(itemId)`, in a new file
`lib/data/repositories/stock_ledger.dart`. It:

1. Reads all movements of the item, sorted by `occurredAt`, then by `id` to break ties.
2. Replays them from zero, using the same cost rules as today (`lib/core/utils/stock_cost.dart`
   and `_costOf` in `movement_repository.dart`). Reuse that code, do not copy it.
3. Writes the final `quantity` and `averageCost` on the item, and the `unitCost` and
   `averageCostAfter` on each movement.

Then `_record` in `movement_repository.dart` keeps working as today for speed on the same
device, but Phase 6 will call `rebuildItemStock` after receiving movements from other devices.
Add a test that checks: "replaying all movements gives the same numbers as the live path" on the
full demo dataset.

> **As built:** `StockLedger` in `stock_ledger.dart`, with `rebuildItem`, `rebuildItems` and
> `rebuildStore`. It does not replay from zero. The demo seed and older installs have a movement
> history that does not add up to the stock, so each article now has a **baseline**
> (`baselineQuantity`, `baselineAverageCost`) and each movement an `inBaseline` flag. The
> replay starts from the baseline and skips flagged movements. Version 15 and the seed set the
> baseline to the stock the article already held. The cost rule moved to one shared function,
> `appliedCostOf`, used by both the live path and the replay.

**Step 1.8: Make stock counts safe offline.**
A stock count (adjustment) stores the difference, not the counted number. So two devices can
merge them. Check that this is true in `recordAdjustment` and write a test: device A counts 10
while device B takes out 3 at the same time. After both are replayed, the result is what a
person would expect. Write the chosen rule in a comment.

> **As built:** the difference alone gives a wrong answer in one case. If B took 3 out
> **before** A counted, A's count of 10 already saw the shelf without those 3, and adding the
> difference would take them off twice. So the replay treats a count as **absolute at its
> own time**: it sets the stock to the counted number and rewrites the movement's difference.
> 3 out before the count gives 10, and 3 out after the count gives 7. Both cases are tested.

**Step 1.9: Use real password hashing, and hash PINs.**
Replace `fakePasswordHash` with a real slow hash (for example Argon2id or PBKDF2 with a salt,
from a maintained Dart package). Also store employee PINs as a hash, not as plain text. Add a
migration step that converts existing values. Credentials must be safe before they leave the
device, because they will be synced so an employee can log in on any tablet of the store.

> **As built:** passwords use PBKDF2-HMAC-SHA256 with a random salt
> (`lib/core/utils/password_hash.dart`, `crypto` package). Version 15 rehashes the old values,
> so every existing password still works. **PINs are not hashed.** In this app the PIN is an
> identifier, like a national ID number: the employee list, the cards and the selectors show
> it, and search matches on it. Hashing it would remove it from those screens. It is not a
> secret, so it syncs as plain text like a name.

**Step 1.10: Give each device an ID.**
Add a `deviceId` key to `MetaKeys` (`lib/data/database/meta_keys.dart`). On first start,
create it with `newId()` and never change it. It is local only.

**Step 1.11: Run all tests, fix what breaks.**
Update `test/db/migration_test.dart` for version 15. Update the seed if needed
(`lib/data/seed/`). `flutter analyze` and `flutter test` must be clean.

**Done when:** version 15 migrates old databases correctly, deletes are soft everywhere, the
stock rebuild test passes, and credentials are hashed. The app still works exactly like before
for the user.

---

## Phase 2: The outbox (recording changes to send)

Goal: every change to a synced table is recorded in a queue, ready to send. Still no network.

> **Status: built** (schema version 16). What differs from the first plan:
>
> - **No `operation` column.** Deletes are soft since Phase 1, so a delete is an ordinary
>   entry whose payload has `deleted_at` set.
> - **The switch is a `meta` key, `syncQuiet`,** set and removed by `SyncQuiet.run` inside
>   the same transaction as the quiet writes. A crash rolls it back with them, so the queue
>   can never stay switched off.
> - **One entry per row is an upsert** on (table, row key) that keeps the entry's place, the
>   row's first change. Deleting and re-adding would move an edited parent behind its
>   children.
> - **The triggers are generated** by `tool/generate_outbox_triggers.py` from the schema
>   dump, into `lib/data/database/outbox_triggers.drift`. Each trigger reads the row back
>   from its table, so the entry holds the final row whatever order the triggers run in.
> - **The demo queues changes** (option 2): the count moves during a walkthrough. The seed
>   is quiet, and the demo reset empties the queue.

**Step 2.1: Create the `Outbox` table (schema version 16).**
Columns:

- `id`: an auto-increment number. It keeps the order of changes.
- `tableName`: which table changed.
- `rowId`: the ID of the changed row. For `BusyDates`, which has no single ID, use
  `storeId|day`.
- `storeId`: the store of the row.
- `operation`: `upsert` or `delete`.
- `payload`: the full row as JSON, at the moment of the change.
- `createdAt`: when it was recorded.
- `attempts` and `lastError`: filled in Phase 5 when sending fails.

**Step 2.2: Add a "sync is applying" switch.**
Create a tiny local table (or a temp table) with one value: `applying = 0 or 1`. Phase 6 sets
it to 1 while writing rows received from the server. The triggers check it, so received rows
are not put in the outbox again.

**Step 2.3: Write the triggers.**
For every synced table, create `AFTER INSERT` and `AFTER UPDATE` triggers that insert a line in
`Outbox` when `applying = 0`. Build the payload with SQLite's `json_object(...)`.
Do **not** include derived columns in the payload: `Items.quantity` and `Items.averageCost`.
Send movements whole. The replay recomputes a movement's derived fields on every device, and a
count's `unitCost` is also an input (the opening cost), so it must travel.
Run `StockLedger` with `applying = 1` too: its writes are recomputations that every device
does for itself, not changes to send.
Create the triggers in the migration with `customStatement`. Keep the SQL in one Dart file,
generated from the table list of Step 1.1, so a new table cannot be missed.

**Step 2.4: Merge repeated changes to the same row.**
If a row changes 5 times while offline, only the last version matters. Before inserting, the
trigger (or the sender in Phase 5) removes older outbox lines for the same `tableName` and
`rowId`. This keeps the queue small.

**Step 2.5: Show the real pending count.**
Make `pendingChangesProvider` (in `lib/shared/widgets/offline_banner.dart`) watch
`SELECT COUNT(*) FROM outbox`. Add a small `OutboxRepository` in `lib/data/repositories/` for
this and for Phase 5.

**Step 2.6: Keep the demo out of the outbox.**
The seed and the "reset demo" (`demo_repository.dart`) must run with `applying = 1`, or empty
the outbox after they finish. Demo data must never be sent.

**Step 2.7: Tests.**
In `test/db/`, add `outbox_test.dart`:

- Creating a product adds one outbox line.
- Editing it 3 times leaves one line.
- Deleting it leaves one `delete` line.
- A stock movement adds lines for the movement and the product, without the derived columns.
- Writes with `applying = 1` add nothing.
- Resetting the demo leaves the outbox empty.

**Done when:** the offline banner shows the real number of unsent changes, and all tests pass.

---

## Phase 3: The server (Supabase)

Goal: a server database that mirrors the synced tables, with security rules and two functions:
one to receive changes, one to send them.

**Step 3.1: Create the account tables.**
In a first SQL migration in `supabase/migrations/`:

- `organizations` (id, name, created_at).
- `members` (user_id linked to Supabase login, organization_id, role, created_at).
- `devices` (id, organization_id, name, last_seen_at).
- Add `organization_id` to the server `stores` table.

**Step 3.2: Create the mirror tables.**
One Postgres table per synced table, with the same columns in `snake_case`. Add to each:

- `server_seq`: a big number taken from one shared sequence. A trigger sets it on every insert
  and update. This is what devices use to ask "what changed after N".
- `updated_by_device`: which device sent the last change.

Use the same text IDs as the app. Do not add the derived columns (stock quantity, average cost)
on the server, or keep them only as information and never trust them.

**Step 3.3: Write the security rules (Row Level Security).**
Turn on RLS on every table. The rule is always the same: a user can read and write a row only
if the row's `store_id` belongs to their organization. Owners can create and edit stores.
Managers cannot. Write one SQL helper function, `user_can_access_store(store_id)`, and use it in
every policy.

**Step 3.4: Write the `push_changes` function.**
A Postgres function (called with RPC) that receives a batch of outbox lines. For each line:

1. Check that the user can access the store.
2. Check the special rules of Phase 7 (order status, payroll, attendance).
3. Insert or update the row (or set `deleted_at` for a delete).
4. Return, for each line, `accepted` or `rejected` with a reason.

The whole batch runs in one transaction per line, so one bad line does not block the others.

**Step 3.5: Write the `pull_changes` function.**
It takes a store ID, a `server_seq` cursor and a limit (for example 500). It returns the rows
of all synced tables with `server_seq` above the cursor, sorted by `server_seq`, and the new
cursor. It returns deleted rows too, so devices learn about deletes.

**Step 3.6: Turn on realtime.**
Enable Supabase realtime on a small table, for example `store_changes (store_id, last_seq)`,
updated by a trigger. Devices listen to it and pull when it moves. This is lighter than
listening to 20 tables.

**Step 3.7: Create the photo storage bucket.**
A private bucket named `photos`, with folders per store (`store_id/items/...`,
`store_id/employees/...`). The same access rule as the tables.

**Step 3.8: Test the server alone.**
Write SQL tests (Supabase supports pgTAP) or a small Dart script in `tool/` that: creates two
users in two organizations, checks that user A cannot read store B, pushes and pulls a few
changes, and checks the cursor.

**Done when:** the dev server has all tables, the rules block other organizations, and push and
pull work from a test script.

---

## Phase 4: Real authentication

Goal: owners and managers log in with a real account. Employees keep the PIN on shared devices.

**Step 4.1: Add the Supabase package.**
Add `supabase_flutter` to `pubspec.yaml`. Initialize it in `main.dart` with the values from
Step 0.3. Check it does not conflict with the pinned drift version.

**Step 4.2: Fill `AuthService`.**
In `lib/services/auth_service.dart`: sign up, sign in, sign out, reset password, and "current
account". Supabase keeps the session on the device, so the member stays logged in offline.
Expose it with a Riverpod provider in `lib/data/providers.dart`.

**Step 4.3: Two levels of session.**
Keep them separate and clear:

- **Account session** (Supabase): which organization this device belongs to. Needed to sync.
- **Employee session** (the existing `SessionRepository` and `currentEmployeeProvider`): who is
  using the device right now. Stays local and fast, with the PIN.

**Step 4.4: Sign-up creates the organization.**
When an owner signs up, create the organization, the member row (role owner), and register the
device. Then the owner creates their first store, or uploads the existing local data (Phase 9).

**Step 4.5: Add a device to an existing organization.**
On a new tablet, a manager signs in once. The device is registered and downloads the stores of
the organization (Phase 6, first download). After that, employees use their PIN.

**Step 4.6: Update the router guard.**
In `lib/app/router.dart`: no account session and not in demo mode means the account login page.
Account session but no employee session means the PIN screen, like today. Demo mode keeps the
current behaviour.

**Step 4.7: Sign out of the account wipes the local data.**
When a member signs out of the account (not an employee), warn if the outbox is not empty. Then
delete the local database file and photos. This protects data on shared or lost devices.

**Step 4.8: Tests.**
Fake `AuthService` in tests with a Riverpod override. Test the router guard for each case.
Update `test/db/auth_test.dart` and `test/router_test.dart`.

**Done when:** an owner can sign up, sign in on a second device, and both are linked to the
same organization. Demo mode still works with no account.

---

## Phase 5: Sending changes (push)

Goal: the outbox empties itself to the server whenever the device is online.

**Step 5.1: Build the `SyncService` skeleton.**
In `lib/services/sync_service.dart`. It holds a state: `idle`, `syncing`, `offline`, `error`,
plus the last sync time. Expose it with a provider. Only one sync can run at a time: if one is
running, a new request waits for it.

**Step 5.2: Detect the network.**
Add the `connectivity_plus` package. When the network comes back, start a sync. Also treat a
failed request as "offline", because having Wi-Fi does not always mean having internet.

**Step 5.3: Send the outbox in batches.**
Read the first 100 lines by `id`. Send them to `push_changes`. For each accepted line, delete
it from the outbox. Repeat until the outbox is empty.

**Step 5.4: Handle failures.**

- Network error: stop, keep the lines, retry later with a growing wait (5 s, 15 s, 1 min, 5 min).
- Rejected line: do not retry forever. Move it to a local `sync_errors` table with the reason,
  remove it from the outbox, and ask the server for the current version of that row in the next
  pull. The screen shows the error (Phase 10).

**Step 5.5: Decide when to sync.**

- A few seconds after a local write (wait 2 to 3 seconds so many quick writes go together).
- When the app comes back to the front.
- When the network returns.
- Every few minutes while the app is open.
- When the user taps "Synchroniser maintenant" on the sync page.

**Step 5.6: Order the sending correctly.**
Parents must reach the server before children (an order before its lines, a product before its
movements). Sending by outbox `id` already follows the write order. Keep it, and do not reorder.

**Step 5.7: Tests.**
Create a `FakeSyncServer` in `test/support/` that stores rows in memory and can be told to fail
or reject. Test: batch sending, retry after a network error, rejected line goes to errors,
order is kept.

**Done when:** changes made offline reach the server when the network returns, and the pending
count drops to zero.

---

## Phase 6: Receiving changes (pull)

Goal: each device receives what other devices changed, and the screens update by themselves.

**Step 6.1: Store a cursor per store.**
In `Meta`, save `syncCursor:<storeId>`, the last `server_seq` received. It starts at 0.

**Step 6.2: Always push before pulling.**
One sync is always: push the outbox, then pull. This way the device's own changes are on the
server before it downloads, which avoids many conflicts.

**Step 6.3: Download in pages.**
Call `pull_changes` with the cursor, get up to 500 changes, apply them, save the new cursor,
repeat until nothing is left.

**Step 6.4: Apply the changes safely.**
For each page, in one drift transaction:

1. Set `applying = 1` (Step 2.2).
2. Insert or replace each row. A row with `deleted_at` is saved with it, so it becomes hidden.
3. Skip a row if the same row still has a line in the outbox (a local change not yet sent).
   The local change will be sent next time and the server decides.
4. Set `applying = 0`.
5. Save the new cursor in the same transaction, so a crash never skips or repeats changes.

Put this code in a new `lib/data/sync/` folder (for example `sync_applier.dart`), with one
mapper per table from server JSON to drift rows. Reuse the existing mappers where possible.

**Step 6.5: Recompute stock after receiving movements.**
Collect the IDs of products that got new movements. After the transaction, call
`StockLedger.rebuildItems` (Step 1.7) with those IDs. This fixes quantity and average cost for movements
that arrived late or out of order.

**Step 6.6: Handle notifications correctly.**
Received rows are written directly, not through repositories. So the notification engine does
not run for them, and alerts are not duplicated. Only the device that made the change creates
the alert, and the alert syncs like other rows. Check that low-stock alerts still make sense
after a rebuild.

**Step 6.7: Listen to realtime.**
Subscribe to `store_changes` for the current store. When it changes, start a sync. If realtime
disconnects, the timer of Step 5.5 still catches up.

**Step 6.8: The first download.**
On a new device, the cursor is 0, so the pull downloads everything. Show a progress screen
("Téléchargement des données… 40 %"). Allow it to continue after an interruption, thanks to the
saved cursor.

**Step 6.9: Screens update by themselves.**
The screens already watch drift streams. When the applier writes, drift notifies them. Check the
main pages (stock, orders, time clock) with a two-device test.

**Step 6.10: Tests.**
With `FakeSyncServer` and **two in-memory databases** (device A and device B):

- A creates a product, B receives it.
- A deletes a supplier, B stops showing it.
- A and B each add 5 kg offline, both end at +10 kg.
- The pull stops halfway, and restarting gives the right result.
- A received row does not come back in B's outbox.

**Done when:** a change on one device appears on the other device within seconds when both are
online, and after reconnecting when one was offline.

---

## Phase 7: Conflict rules

Goal: when two devices change the same thing, the result is predictable and correct. The server
checks these rules in `push_changes` (Step 3.4).

**Step 7.1: Add-only records never conflict.**
`StockMovements`, `GoodsReceipts` and their lines, `PriceHistory`, `AttendanceSessions` and
`AttendancePauses` are only added, never edited by two people. The server accepts them all.
If one needs a fix, the app adds a correcting record, like a stock correction movement.

**Step 7.2: Normal records: the last change wins.**
Product name, supplier phone, store settings, employee details, categories, units: the change
that reaches the server last wins, for the whole row. This is simple and fits a restaurant,
where two people rarely edit the same product at the same minute.

**Step 7.3: Delete against edit: the delete wins.**
If one device deletes a product and another edits it, the product stays deleted. An edit to a
row that has `deleted_at` on the server is rejected, and the device receives the deleted version.

**Step 7.4: Purchase order status only moves forward.**
Draft, then sent, then partly received, then closed. The server rejects a change that moves
backward (for example received back to draft). Receipts are still accepted, because they are
add-only: the order status is then recomputed from the receipts.

**Step 7.5: Payroll can be paid only once.**
If two devices mark the same pay period as paid, the first one wins. The second gets a
rejection with the reason "déjà payée par X". A paid period cannot be edited any more.

**Step 7.6: One open clock-in per employee.**
If an employee clocks in on two tablets while offline, the server keeps both sessions, but marks
the overlap. The attendance history page shows it for the manager to fix. We never silently
delete working time.

**Step 7.7: Duplicate names.**
Two devices can create a category or unit with the same name offline. Accept both. Later, add a
"merge" action in settings. Do not block the user offline for this.

**Step 7.8: Clock differences between devices.**
Device clocks can be wrong. Never use device time to decide who wins. The server order
(`server_seq`) decides. Device time is only used for display and for sorting movements
(`occurredAt`), which is what the user means by "when".

**Step 7.9: Write each rule in the code and in a test.**
Each rule gets a server test (Step 3.8) and a two-device app test (Step 6.10).

**Done when:** every rule above has a passing test, and the rules are listed in
`lib/data/sync/README.md`.

---

## Phase 8: Photos

Goal: product and employee photos appear on every device.

**Step 8.1: Upload after saving.**
When a photo is chosen, `lib/data/images/product_images.dart` and
`lib/data/employee_photo_store.dart` keep saving it locally, like today. Then a small
"photo upload queue" sends the file to the `photos` bucket when online.

**Step 8.2: Store the cloud path.**
The row stores the cloud path (`store_id/items/<id>.jpg`) instead of only the local filename.
The row syncs like any other.

**Step 8.3: Download when missing.**
When a device shows a photo it does not have locally, it downloads it once and keeps it in a
local cache. Offline, it shows the usual placeholder.

**Step 8.4: Make photos smaller before upload.**
Resize to a reasonable size (for example 1024 px) and compress, to save mobile data.

**Step 8.5: Delete from the cloud.**
When a product is deleted or its photo replaced, delete the old cloud file after the change is
accepted by the server.

**Done when:** a photo added on the PC appears on the tablet.

---

## Phase 9: First connection and existing data

Goal: people who already use the app locally do not lose their data.

**Step 9.1: Three starting cases.**
At first account login, the device is in one of these cases:

1. **Demo data only.** Throw it away and start from the server data (or empty).
2. **Real local data, new organization.** Offer to upload it: "Envoyer mes données vers mon
   compte".
3. **Real local data, organization already has data.** Do not merge automatically. Offer to
   keep the server data (the local data is saved as a backup file first).

**Step 9.2: Detect demo data.**
Use `MetaKeys.seededAt` and the seed IDs (like `item-tomates`) to know if the data is the demo.

**Step 9.3: Upload local data.**
Fill the outbox with every existing row (parents first), then run a normal push. Show progress.

**Step 9.4: Keep demo mode.**
A button on the login page, "Essayer la démo", opens the app offline with the seed, like today.
Demo mode never syncs. The reset button stays available only in demo mode.

**Done when:** each of the three cases is tested by hand and by an automated test.

---

## Phase 10: Screens and user messages

Goal: the user always knows the sync state, without technical words.

**Step 10.1: The sync page.**
Rewrite `lib/features/settings/presentation/pages/sync_status_page.dart`:

- State: "À jour", "Synchronisation…", "Hors ligne", "Erreur".
- Last sync time (real, from `SyncService`).
- Number of changes waiting.
- Button "Synchroniser maintenant".
- List of rejected changes (from `sync_errors`) with the reason in plain French, and a button
  to dismiss each one.
- The device name and the account email.

**Step 10.2: The offline banner.**
`lib/shared/widgets/offline_banner.dart` uses the real network state and the real pending count.
Remove the fake "offline mode" toggle, or keep it only in demo mode.

**Step 10.3: Account pages.**
Login, sign up, forgot password, and in settings: account, organization, devices list (with a
button to remove a lost device), sign out.

**Step 10.4: Texts.**
Add every new text to `lib/l10n/*.arb`. Keep the app's style: short, clear, no technical words
like "outbox" or "server_seq".

**Step 10.5: Widget tests.**
Test the sync page and the banner in each state, with a fake `SyncService`.

**Done when:** a non-technical user can understand from the screen whether their changes are
saved on the server.

---

## Phase 11: Testing and release

Goal: be sure the sync is safe before real restaurants use it.

**Step 11.1: Automated tests pass.**
`flutter analyze`, `flutter test`, and the server tests, all green.

**Step 11.2: Manual test on real devices.**
Use at least two devices (for example a Windows PC and an Android tablet) on the dev server:

1. Sign up on the PC, create a store and products.
2. Sign in on the tablet, check everything is there.
3. Turn off Wi-Fi on the tablet. Do stock outs, a receipt, a clock-in.
4. At the same time, on the PC, edit products and receive another order.
5. Turn Wi-Fi back on. Check stock numbers, orders and attendance on both devices.
6. Delete a supplier on one device, edit it on the other, check the delete wins.
7. Pay the same pay period on both devices offline, check only one payment is kept.
8. Add a photo on the PC, see it on the tablet.
9. Sign out of the account on the tablet, check the local data is gone.

**Step 11.3: Measure with a large dataset.**
Create a store with a year of data (thousands of movements). Check the first download time and
that the app stays smooth while syncing.

**Step 11.4: Test app updates.**
Install the current version with local data, then update to the sync version. Check the
migrations to versions 15 and 16 keep all the data.

**Step 11.5: Small beta.**
Give the app to one real restaurant first. Watch the `sync_errors` and server logs for two
weeks before a wider release.

**Step 11.6: Update the docs.**
Update `README.md` (phase table: Phase 3 done), `lib/data/database/README.md`, and write
`lib/data/sync/README.md` explaining the design of this file in short.

**Done when:** the manual checklist passes on real devices and the beta restaurant uses it with
no data loss.

---

## Rules for every phase

- Work on one branch per phase. Merge a phase only when its tests pass.
- Every database change is a new `schemaVersion` with a migration and a schema dump. Never edit
  an old migration.
- Every new synced table must be added to the list of Step 1.1, to the triggers of Step 2.3,
  to the server tables of Step 3.2 and to the applier of Step 6.4. Add a test that fails when a
  table is missing from one of these places.
- Screens never talk to the network. They read drift, like today.
- Never send demo data to the server.
- Never trust device time to decide a conflict.

## Summary of phases

| Phase | What | Needs network |
|---|---|---|
| 0 | Decisions and setup | No |
| 1 | Local database ready for sync | No |
| 2 | Outbox | No |
| 3 | Server tables, rules, push and pull functions | Server only |
| 4 | Real login | Yes |
| 5 | Sending changes | Yes |
| 6 | Receiving changes | Yes |
| 7 | Conflict rules | Yes |
| 8 | Photos | Yes |
| 9 | First connection and existing data | Yes |
| 10 | Screens and messages | Yes |
| 11 | Testing and release | Yes |

