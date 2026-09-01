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

| File | For |
|---|---|
| `item_row_view.dart` | A row of the inventory list: the article, its category name, its unit |
| `movement_row_view.dart` — in `item_detail_views.dart` | A line of the movement log, with its article, unit, supplier and commande all named |
| `item_detail_views.dart` | The item detail screen: its offers and what the default costs extra (`ItemPricing`), and what is on its way and from whom (`ItemOnOrder`) |
| `order_detail_view.dart` | One commande with its lines and deliveries, and one delivery with its lines |
| `supplier_views.dart` | A supplier with its article count, and one article it offers with the best price on the market beside it |
| `catalog_row_views.dart` | A category or unit with the number of articles using it |
| `store_card_view.dart` | An establishment with its article and alert counts |
| `low_stock_alert_view.dart` | A low article, who would fill it, and how much is already ordered |
| `receipt_document_sources.dart` | Everything the bon de réception needs besides the receipt |

## The rule they follow

**A view model bundles what one screen decides together.** Splitting `ItemPricing` into a
list of offers and an overpayment figure would let the callout name a supplier the table
underneath it does not list. Splitting `ItemOnOrder` would let a total disagree with the
commandes it sums. That is the test for whether two things belong in the same bundle — not
whether they come from the same table.
