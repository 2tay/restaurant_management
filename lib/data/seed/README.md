# Seed

The demo dataset, and the code that puts it in the database.

First launch finds an empty `stores` table and seeds it, so a fresh install looks exactly
like the Phase 1 demo did. *Paramètres → Synchronisation → Réinitialiser la démonstration*
wipes and re-seeds through the same path, which means the mechanism is exercised on every
test run rather than only when somebody taps the button.

Seeding is one transaction, in foreign-key order: stores → categories and units →
suppliers → items → prices → history → movements → orders and their lines → receipts and
their lines → team → notifications. With `foreign_keys` on, a broken reference in the
dataset now fails loudly instead of quietly producing an orphan.

## Dates

The dataset's dates are all offsets from a single "now", so the demo always looks recent —
an order sent three days ago, a delivery due tomorrow. The seed records the moment it ran
in the `meta` table and derives from that, so a re-seed months later still produces a
plausible recent history rather than one anchored to whenever the app was first opened.
