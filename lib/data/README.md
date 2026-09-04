# Data layer

Everything between SQLite and the widget tree. Phase 1 had no such thing — screens read a
set of global lists directly, and writes edited them in place.

```
database/       the drift schema and the AppDatabase class
  tables/         one file per table group
  migrations/     drift's schema dumps, from version 2 onward
mappers/        row <-> model, one file per aggregate
repositories/   the only code allowed to read or write the database
view_models/    what one screen needs, resolved in one query
seed/           the demo dataset, loaded on first launch
  dataset/        the data itself — thirteen files of hand-written restaurant
providers.dart  the bridge: one provider per screen-level query
```

## Why this is central and not `features/*/data/`

An item is read by inventory, orders, reports, search and the dashboard alike. Filing its
repository under any one of them would make the other four import across a feature
boundary, which is worse than having no boundary. Feature folders keep `presentation/`
only.

## The rules that hold this layer together

- **Screens never import `database/`.** They talk to repositories, which return models.
  `tool/ux_audit.py` enforces this mechanically.
- **`lib/models/` stays plain.** No drift annotations, no generated superclasses. Drift
  generates its own row classes and `mappers/` converts between the two. That keeps the
  models usable by the PDF layer and, in Phase 3, by the sync layer.
- **Repositories are the write boundary.** Nothing outside `repositories/` may call
  `into(...)`, `update(...)` or `delete(...)` on a table.
- **Only `movement_repository.dart` writes `items.quantity` and `items.averageCost`.**
  This is the app's oldest invariant and the one the audit guards hardest.

## Shape of a repository

Reads that a screen watches return `Stream<T>` — drift pushes when the underlying rows
change, which is what replaced Phase 1's global "something changed" revision counter.
Reads a form does once return `Future<T?>`. Pure predicates over already-loaded objects
(`itemMatchesSearch`) stay synchronous and stay in `core/utils/`.

Writes that touch more than one table run in a transaction. Receiving a delivery touches
five, and a half-applied receipt is not a state the domain has a name for.
