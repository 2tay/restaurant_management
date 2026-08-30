# View models

Plain data assembled by a repository for one screen or one document, holding everything that
screen needs already resolved.

They exist to answer one question in one query. A row in the inventory list shows an article's
category name, its unit abbreviation and its default supplier — three lookups per row, which
in Phase 1 was three list scans and in Phase 2 would be three round trips. A leaf widget with
no `ref` cannot make them at all without becoming a `FutureBuilder`, which is one query per
row per rebuild. So the join happens once, in SQL, and the widget receives text.

Nothing here has behaviour. A view model is what a query returned, not a place to put rules —
those stay in `core/utils/` where both this layer and the tests can reach them.

## What lives here

- `receipt_document_sources.dart` — the letterhead, the commande, the supplier and a name and
  unit per article, for the bon de réception. Added in stage 7, when the document assembly
  stopped making its own lookups.

Stage 9 adds the row view-models for the lists — `ItemRowView`, `MovementRowView` and their
neighbours — for the same reason.
