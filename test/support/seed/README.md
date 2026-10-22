# Seed

The test dataset, and the code that puts it in the database. It used to ship as the
app's demo; the demo is gone and nothing in `lib/` reads this folder. `db_fixture.dart`
and `app_harness.dart` seed it for the suites, which name its ids (`StoreIds`,
`EmployeeIds`, ...).

Seeding is one transaction, in foreign-key order: stores → categories and units →
suppliers → items → prices → history → movements → orders and their lines → receipts and
their lines → team → notifications. With `foreign_keys` on, a broken reference in the
dataset fails loudly instead of quietly producing an orphan.

## Dates

The dataset's dates are all offsets from a single "now", so it always looks recent — an
order sent three days ago, a delivery due tomorrow. `seedDemoData` takes that instant as
an argument, shifts every date by the difference, and records what it used in `meta`.
Tests pass a fixed instant and get a dataset whose dates they can assert on.
