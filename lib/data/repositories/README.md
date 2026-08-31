# Repositories

The only code allowed to touch the database. One file per aggregate, mirroring the write
layer Phase 1 kept in memory — that seam was built one-to-one on purpose, so this was a
translation rather than a redesign.

The domain rules did not move: they are still the ones written down in `DOMAIN_MODEL.md`
and still enforced by the same test suites. What changed is where the data comes from.

## Non-negotiable

- **`movement_repository.dart` is the only writer of `items.quantity` and
  `items.averageCost`.** Every other repository that needs stock to move delegates to it.
  `item_repository.create` inserts the item with `quantity: 0` and hands the opening
  balance over, in the same transaction, so an item never exists without its opening
  movement.
- **Multi-table writes run in a transaction.** `confirmReceipt` touches the receipt, its
  lines, the stock movements, the item costs, the order lines and the price history. It
  applies completely or not at all.
- **Read-modify-write happens inside the transaction.** Reading a quantity outside and
  writing it inside is a race that Phase 1 could not have and this phase can — two stock
  outs from a double-tapped button are genuinely concurrent futures now.
- **The arithmetic is not reimplemented here.** `core/utils/stock_cost.dart` and
  `core/utils/order_status.dart` are pure and unchanged; repositories call them.
