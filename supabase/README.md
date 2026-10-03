# Sync server (Supabase)

The server side of multi-device sync (`SYNC_PLAN.md`, Phase 3). The app does not talk to it
yet. Phases 4 to 6 connect it.

## Run it on this PC

Needs Docker Desktop running and the Supabase CLI (`scoop install supabase`).

```
supabase start      # first run downloads the images, then applies migrations/
supabase test db    # runs tests/database/*.sql against it
supabase db reset   # wipes the local database and re-applies every migration
supabase stop
```

`supabase start` prints the local URLs and keys. They are local-only development keys.

## What is here

| File | What it does |
|---|---|
| `migrations/…_accounts.sql` | Organizations, members (owner or manager), devices, `create_organization`, `register_device` |
| `migrations/…_sync_tables.sql` | **Generated.** The 20 synced tables, `server_seq`, `store_changes`, read-only access rules, `pull_changes` |
| `migrations/…_push_changes.sql` | `push_changes`: access checks, conflict rules, then the write |
| `migrations/…_photos.sql` | The private `photos` bucket, one folder per store |
| `migrations/…_join_codes.sql` | Join codes for managers, `my_account`, `remove_device` (Phase 4) |
| `migrations/…_personnel_audit.sql` | The pointage audit synced: `business_days`, `stores.business_day_auto_open_minutes`, `attendance_sessions.exit_set_by_employee_id` (SYNC_PERSONNEL_PLAN, step 2) |
| `migrations/…_partial_updates.sql` | `apply_change` writes only the columns an edit names (SYNC_PERSONNEL_PLAN, step 4) |
| `tests/database/sync.test.sql` | pgTAP tests: isolation between restaurants, push and pull, conflict rules |
| `tests/database/accounts.test.sql` | pgTAP tests: join codes, roles, removing a device |

## Rules worth knowing

- **Clients never write a table directly.** They can read their own organization's rows.
  Every write goes through `push_changes`, so its rules cannot be skipped.
- **One organization per login.** A store belongs to one organization, and every row belongs
  to one store. Access is "is this store in my organization".
- **Only owners create or change stores.** Managers work inside them.
- **`server_seq` orders everything.** Each insert or update takes the next number from one
  sequence. A device pulls "everything after the last number I saw".
- **Conflict rules** in `push_changes`: delete wins, a commande's status only moves forward,
  a paid pay period is final. Otherwise the last change to arrive wins — for a personnel row,
  only for the columns it changed (`columns` in the entry).

## Changing a synced table

The mirror tables are generated from the app's schema dump. After a change to a synced table
in the app:

1. Regenerate the reference with `python tool/generate_server_schema.py`.
2. **Do not commit it over the applied migration.** Write a new migration that alters the
   server tables the same way, and restore the generated file to what was applied.
