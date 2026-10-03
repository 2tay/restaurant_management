# À traiter plus tard

Problems found while testing the release build on two laptops (2026-10-02).
Ordered by priority.

---

## 1. ✅ Waiting screen ("Presque prêt") stays stuck after the data arrived — FIXED

**Symptom.** After signing in to an account (owner on a second device, or a
manager who just joined), the app stays on *Presque prêt* with no error and
no progress bar. *Réessayer maintenant* does nothing.

**What was checked.**

| Where | Result |
|---|---|
| Server (Supabase) | 1 organization, 1 store, 2 employees, 2 members, all migrations applied |
| Server, as the owner's account | RLS shows the store; `pull_changes` returns 18 changes |
| Local SQLite on the stuck PC | store + 2 employees downloaded, `syncCursor` = 28, outbox empty, `sync_errors` empty |

The data is on the device. Only the screen does not move on.

**Cause.** Leaving the waiting screen depends on a change being noticed at the
right moment:

- `AccountWaitingPage` (`lib/features/auth/presentation/pages/account_waiting_page.dart`)
  uses `ref.listen` on `deviceAccessProvider`. It reacts to changes made
  *after* it was built, never to the current state.
- `SyncController._pass` (`lib/services/sync_service.dart`) only calls
  `deviceAccessProvider.notifier.hydrate()` when `result.received > 0`.
- The router's `_deviceGuard` (`lib/app/router.dart`) only runs on
  navigation. The router has no `refreshListenable` tied to device access.

If the first sync pass downloads the rows and hydrates before the waiting page
is listening, the change goes unseen. Every later pass receives 0 rows, so
`hydrate()` never runs again, and the screen waits forever.

**Real root cause (found 2026-10-02 with a slow fake server).** The first
fixes were not enough on a real network. `DeviceAccessController._set` set
`state` *before* `deviceAccessSnapshot`. Setting `state` runs the waiting
page's listener at once, which navigates. The router then read the old
snapshot (`hasLocalData = false`) and sent it straight back to the waiting
page. Fixed by updating the snapshot first, in `device_access.dart` and the
same pattern in `current_employee.dart`. Covered by "a slow first download
still opens the PIN login" in `test/account_screens_test.dart`.

**Workaround (old builds).** Close the app completely and reopen it. `main()` hydrates at
startup, sees the store, and goes to the PIN login.

**Fix (any one of these, ideally the first two together):**
- [x] On the waiting page, check `access.hasLocalData` on build/init as well
      as listening, and navigate if it is already true.
- [x] In `_pass`, call `hydrate()` after every successful pass while
      `!hasLocalData`, not only when `received > 0`.
- [ ] (optional, not done) Give the router a `refreshListenable` tied to device access, so
      `_deviceGuard` re-runs when the mode or local data changes.
- [x] Add a test: data arrives before the waiting page mounts → it still
      reaches the login.

---

## 1b. ✅ Rows received from another device don't appear until the app restarts — FIXED

**Symptom.** A product ("Carrot") created on the manager's laptop is on
Supabase, but it does not show on the owner's PC, even after *Paramètres →
Synchroniser*.

**What was checked.** Supabase has the item (`server_seq` 56). The owner's
local SQLite **also has it**: `syncCursor` = 56, no `sync_errors`, outbox
empty. The sync worked. The screen did not refresh.

**Cause.** Every screen reads through drift `watch()` streams
(`lib/data/providers.dart`), which re-run only when drift is told a table
changed. `SyncApplier._upsert` (`lib/data/repositories/sync_applier.dart`)
writes with `_db.customStatement(...)`, which **does not notify** stream
queries. `StockLedger.rebuildItems` only writes when the computed stock
differs, which is not the case for a new item. So no notification reaches the
`items` streams, and the list keeps its old result until the query is rebuilt
(app restart, or leaving and reopening the page may not be enough if the
provider stays alive).

**Fix:**
- [x] After `SyncApplier.apply` writes rows, call
      `_db.notifyUpdates({...})` with a `TableUpdate` for every table that
      received rows (or `customStatement` → `customInsert`/`customUpdate` with
      `updates: {table}`).
- [x] Add a test: a `watch()` on another table (categories) emits again after
      a pulled page adds a row (`test/db/sync_pull_test.dart`).

---

## 2. 🟠 Sign-up shows "Une erreur est survenue. Réessayez." on email rate limit

**Symptom.** Creating an account fails with the generic error.

**Cause.** "Confirm email" is on in the hosted project. Supabase's built-in
SMTP allows only a few emails per hour. The server answers
`429 over_email_send_rate_limit`, and `_authCode` in
`lib/services/auth_service.dart` maps unknown codes to
`AccountErrorCode.unknown`.

**To do:**
- [ ] Supabase dashboard (config, not code): for dev, turn off
      *Authentication → Sign In / Providers → Email → Confirm email*. For
      production, set up custom SMTP (Resend, Brevo, SendGrid…) and raise
      *Authentication → Rate Limits*.
- [ ] Map `over_email_send_rate_limit`, `over_request_rate_limit` and HTTP
      429 to a dedicated code (e.g. `AccountErrorCode.rateLimited`) with a
      clear message: "Trop de tentatives, réessayez dans quelques minutes."

---

## 3. 🟡 Migration tests skip v14–v19 → v20

`test/db/migration_test.dart` checks v1…v13 → v20 but not v14…v19 → v20. A
temporary test confirmed that all six upgrades pass today. Add them so it
stays that way.

- [ ] Add "a version N install upgrades to version 20 cleanly" for N = 14…19.

Note: another Claude session claimed that the v17→v18 block
(`app_database.dart:383`) creates triggers on `busy_dates` before the table
exists. That is **not reproducible** from the real schema history:
`busy_dates` is created in the v13→v14 step, before any v15+ block runs. If a
device hangs on startup, get its `Documents\stock_inventory.sqlite` and check
`PRAGMA user_version` and its tables before changing the migration.

---

## 4. 🟡 Release build for Windows

The release build is made with:

```
flutter build windows --release --dart-define-from-file=config/dev.json
```

then the `build\windows\x64\runner\Release\` folder is zipped.

- [ ] Script it (build + copy `msvcp140.dll`, `vcruntime140.dll`,
      `vcruntime140_1.dll` + zip). The DLLs were copied by hand from
      `System32`.
- [ ] Consider an installer (MSIX or Inno Setup) and code signing, so
      SmartScreen stops showing "Windows a protégé votre ordinateur".
- [ ] Remember that the build points at whatever `config/*.json` it was given.
      Make a separate prod config when there is a prod project.

---

## 5. 🟢 UX: the two logouts are easy to confuse

The employee logout keeps the device linked to the account, and the next
screen is PIN + mot de passe. *Paramètres → Compte du restaurant → Se
déconnecter du compte* unlinks the device and wipes it, and the next screen is
email + password. When testing, it is not obvious how to reach the account
(email) login.

- [ ] Maybe add a discreet link on the PIN login screen ("Changer de compte"),
      or explain it in the help.
- [ ] Keep the existing warning when outbox changes are still pending before
      an account sign-out: it is what protects data that never reached the
      server.
