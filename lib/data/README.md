# Data layer

Everything between SQLite and the widget tree. Phase 2 builds it; Phase 1 had no such
thing — screens read `lib/mock_data/` directly and writes edited global lists.

```
database/      the drift schema and the AppDatabase class
  tables/        one file per table group
  converters/    enum <-> text TypeConverters
  migrations/    MigrationStrategy + drift's schema dumps
mappers/       row <-> model, one file per aggregate
repositories/  the only code allowed to read or write the database
seed/          the demo dataset, loaded on first launch
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
