/// The demo dataset.
///
/// Thirteen files of hand-written restaurant data: three establishments, their
/// catalogues, suppliers, prices, movements, commandes and deliveries. It is
/// what a first launch seeds and what *Réinitialiser la démonstration* seeds
/// again.
///
/// It used to be `lib/mock_data/`, an app layer that every screen read from
/// directly. It is a fixture now — the seed reads it, the tests name its ids,
/// and nothing else in `lib/` knows it exists. The move is the whole point of
/// the phase said in one directory name.
///
/// The dataset is built so every screen says something true: three stock
/// statuses in the flagship establishment, an article with three competing
/// suppliers, another whose default supplier is not the cheapest, and one
/// establishment that is genuinely empty so the empty states can be shown
/// rather than described. Changing a number here changes what the demo
/// demonstrates — `test/db/seed_test.dart` pins the properties that matter.
library;

export 'attendances.dart';
export 'categories.dart';
export 'credentials.dart';
export 'employees.dart';
export 'goods_receipts.dart';
export 'items.dart';
export 'notifications.dart';
export 'payroll_periods.dart';
export 'price_history.dart';
export 'purchase_orders.dart';
export 'reference.dart';
export 'stock_movements.dart';
export 'store_settings.dart';
export 'stores.dart';
export 'supplier_prices.dart';
export 'suppliers.dart';
export 'units.dart';
