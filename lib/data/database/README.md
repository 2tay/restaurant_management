# Database

The drift schema and the `AppDatabase` class. **Nothing outside `lib/data/` imports this
folder** — screens talk to repositories.

- `app_database.dart` — the `@DriftDatabase` class, `schemaVersion`, and the two
  constructors: the real file one and `AppDatabase.memory()` for tests.
- `tables/` — table definitions, grouped by aggregate.
- `migrations/` — drift's generated schema dumps, from the second schema version onward.
  The `MigrationStrategy` itself is ten lines and lives in `app_database.dart`.

There is no `converters/`. The five stored enums use drift's `textEnum`, which already
stores them as their **name string** — the property that mattered, since an index shifts
the day somebody reorders the enum and the database outlives the source file. Hand-written
`TypeConverter`s would be the same behaviour spelled out at length.

## Ready for sync (schema version 15)

Phase 3 syncs this database between devices. Version 15 prepared it, with no network
involved yet. See `SYNC_PLAN.md` at the repository root, Phase 1.

**Every table is synced or local.** The two lists are in `sync_tables.dart`, and a test
fails when a new table is in neither.

| Synced (shared by every device) | Local (this installation only) |
|---|---|
| `stores`, `categories`, `units`, `items`, `suppliers`, `supplier_prices`, `price_history`, `stock_movements`, `purchase_orders`, `purchase_order_lines`, `goods_receipts`, `goods_receipt_lines`, `notifications`, `employees`, `employee_credentials`, `payroll_periods`, `attendances`, `attendance_sessions`, `attendance_pauses`, `busy_dates` | `meta`: the signed-in employee, the device id, later the sync cursors. `outbox`: the changes waiting to be sent |

A synced table follows four rules:

- **It has `updated_at` and `deleted_at`** (`tables/sync_columns.dart`). An insert gets
  `updated_at` from a client default. An update gets it from the `*_touch` trigger in
  `sync_triggers.drift`, unless the write set it itself.
- **Nothing is deleted from it.** A delete sets `deleted_at`, through
  `repositories/soft_delete.dart`, which also writes out the cascades the foreign keys
  used to do. The demo reset is the one exception: the demo never syncs.
- **Every read skips deleted rows.** Each query says `deletedAt IS NULL`, joins included
  (in the `ON` clause of a left join, so the left row survives). The three reads that must
  see deleted rows, because a unique index does, say so in a comment: the attendance day
  lookup before a clock-in and the two position counts.
- **A child row carries its store**, copied from its parent, so the server can check who
  may see it without a join.

**Stock is derived.** `items.quantity` and `items.average_cost` are what replaying the
movements not marked `in_baseline` on top of `baseline_quantity` and
`baseline_average_cost` produces. `repositories/stock_ledger.dart` does the replay. The
version 15 upgrade and the demo seed set the baseline to the stock the article already
held, because the history before that is incomplete.

## The outbox (schema version 16)

Every change to a synced table queues itself in `outbox`, in the same transaction
(`SYNC_PLAN.md`, Phase 2). Nothing sends it yet.

- **Triggers fill it**, two per synced table, in `outbox_triggers.drift`. That file is
  generated: after changing a synced table, dump the schema, then run
  `python tool/generate_outbox_triggers.py`, then `build_runner`. A test fails if the
  triggers and the tables disagree.
- **One entry per row**, holding the whole row as JSON as it is now. The entry keeps the
  place of the row's first change, so a parent is always ahead of its children.
- **A delete is just an entry with `deleted_at` set.** There is no delete entry.
- **`items.quantity` and `items.average_cost` never travel.** Every device recomputes them.
- **Some writes are quiet.** The demo seed, a stock rebuild, and later the rows received
  from the server run inside `SyncQuiet.run`, and queue nothing. The demo reset also
  empties the queue.

The offline banner and the sync page show the queue's size, demo mode included.

## Two things that are easy to get wrong

**Foreign keys are off by default in SQLite.** Every `references()` in `tables/` is
decorative until `PRAGMA foreign_keys = ON` runs in `beforeOpen`. It does.

**`schemaVersion` starts at 1 with a real migration strategy**, not with a
`throw UnimplementedError()`. Phase 3 adds columns; the habit costs nothing now and is
expensive to retrofit onto a database that already has a user's data in it.
