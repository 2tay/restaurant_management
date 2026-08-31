import 'package:drift/drift.dart';

import '../../core/utils/attendance_status.dart';
import '../../core/utils/order_status.dart';
import '../../core/utils/payroll_math.dart';
import '../../models/store.dart';
import '../../models/store_settings.dart';
import '../database/app_database.dart';
import '../mappers/mappers.dart';
import 'new_id.dart';

/// Establishments.
///
/// Small enough that everything here reads the whole table: there are three in
/// the demo and a real account will have a handful. Filtering in Dart on top of
/// a three-row query is clearer than a second SQL path.
class StoreRepository {
  const StoreRepository(this._db);

  final AppDatabase _db;

  /// Oldest first, which is the order the store selector and the switcher show.
  ///
  /// Explicit rather than relying on insertion order. The mock list happened to
  /// be written oldest-first and every screen quietly depended on that; a
  /// database has no such habit, and `ORDER BY` is where that expectation
  /// becomes a promise.
  Stream<List<Store>> watchStores() => _query().watch().map(_toStores);

  Future<List<Store>> stores() => _query().get().then(_toStores);

  Stream<Store?> watchStore(String id) =>
      (_db.select(_db.stores)..where((s) => s.id.equals(id)))
          .watchSingleOrNull()
          .map((row) => row == null ? null : storeFromRow(row));

  Future<Store?> store(String id) =>
      (_db.select(_db.stores)..where((s) => s.id.equals(id)))
          .getSingleOrNull()
          .then((row) => row == null ? null : storeFromRow(row));

  /// The named establishment, or the first one if the name does not resolve.
  ///
  /// What the shell route reads. A stale or hand-typed store id in the URL
  /// should show the app rather than a crash — but unlike its Phase 1
  /// counterpart this can return null, because a database can genuinely hold no
  /// establishments and pretending otherwise would move the crash rather than
  /// remove it.
  Stream<Store?> watchStoreOrFirst(String? id) {
    return watchStores().map((List<Store> stores) {
      if (stores.isEmpty) return null;
      if (id == null) return stores.first;
      return stores.firstWhere(
        (store) => store.id == id,
        orElse: () => stores.first,
      );
    });
  }

  /// How many days a `partial` commande may sit before the dashboard flags it.
  ///
  /// A column on the establishment since this phase; it was a mutable global in
  /// Phase 1. Returns the default for a store that does not exist, so a caller
  /// reading it for a stale route parameter gets a usable number rather than an
  /// exception on a screen that is about to be replaced anyway.
  Future<int> stalePartialOrderDays(String storeId) async {
    final row = await (_db.select(
      _db.stores,
    )..where((s) => s.id.equals(storeId))).getSingleOrNull();
    return row?.stalePartialOrderDays ?? 7;
  }

  /// The full six-field [StoreSettings] — the pointage hours, the break
  /// allowance, the payroll coefficients and the stale-order threshold.
  ///
  /// This was `mock_store_settings.dart` / `MockQueries.storeSettings`; the
  /// columns live on the establishment row since Phase 2 employé. Synthesises a
  /// default record when there is no row — nothing in the app produces a store
  /// without one, but a missing row is cheaper to treat as "defaults" than to
  /// assert against, exactly as the mock did.
  Stream<StoreSettings> watchSettings(String storeId) =>
      (_db.select(_db.stores)..where((s) => s.id.equals(storeId)))
          .watchSingleOrNull()
          .map((row) => _settingsOf(storeId, row));

  Future<StoreSettings> settings(String storeId) async {
    final row = await (_db.select(
      _db.stores,
    )..where((s) => s.id.equals(storeId))).getSingleOrNull();
    return _settingsOf(storeId, row);
  }

  StoreSettings _settingsOf(String storeId, StoreRow? row) => row == null
      ? StoreSettings(
          storeId: storeId,
          openMinutes: AttendanceRules.defaultOpenMinutes,
          closeMinutes: AttendanceRules.defaultCloseMinutes,
          maxBreakMinutes: AttendanceRules.defaultMaxBreakMinutes,
          overtimeMultiplier: PayrollRules.defaultOvertimeMultiplier,
          workingDaysPerMonth: PayrollRules.defaultWorkingDaysPerMonth,
          stalePartialOrderDays: OrderRules.defaultStalePartialDays,
        )
      : storeSettingsFromRow(row);

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------
  //
  // Phase 1 kept these in `AccountMutations` alongside the team, on the grounds
  // that neither was big enough to justify a file of its own. The reads already
  // split along aggregate lines in stage 3, so the writes follow them: an
  // establishment is not a fact about the team, and a repository that owns the
  // reads and not the writes is the shape that lets the two drift apart.

  /// Opens a new establishment.
  ///
  /// It starts with no categories, units, articles or suppliers, which is
  /// correct rather than lazy: those are per-establishment by design, and a new
  /// shop's catalogue is not the old shop's. What the user sees next is every
  /// empty state in the app, doing its job.
  Future<Store> createStore({
    required String name,
    required String addressLine,
    required String postalCode,
    required String city,
    required String phone,
    String? vatNumber,
  }) async {
    final store = Store(
      id: newId(),
      name: name.trim(),
      addressLine: addressLine.trim(),
      postalCode: postalCode.trim(),
      city: city.trim(),
      phone: phone.trim(),
      vatNumber: _trimToNull(vatNumber),
      createdAt: DateTime.now(),
    );

    await _db.into(_db.stores).insert(storeToRow(store));
    return store;
  }

  /// Edits an establishment. Null when it is gone.
  ///
  /// The id never changes, because it is a route segment: anything the user has
  /// open or bookmarked keeps working across a rename.
  Future<Store?> updateStore(
    String id, {
    String? name,
    String? addressLine,
    String? postalCode,
    String? city,
    String? phone,
    String? vatNumber,
  }) {
    return _db.transaction(() async {
      final existing = await store(id);
      if (existing == null) return null;

      // An empty string clears the VAT number; null leaves it alone. The two
      // mean different things on a field that is legitimately absent, and the
      // document header prints nothing for absent and an empty label for blank.
      final clearedVat = vatNumber == null
          ? const Value<String?>.absent()
          : Value<String?>(_trimToNull(vatNumber));

      await (_db.update(_db.stores)..where((s) => s.id.equals(id))).write(
        StoresCompanion(
          name: name == null ? const Value.absent() : Value(name.trim()),
          addressLine: addressLine == null
              ? const Value.absent()
              : Value(addressLine.trim()),
          postalCode: postalCode == null
              ? const Value.absent()
              : Value(postalCode.trim()),
          city: city == null ? const Value.absent() : Value(city.trim()),
          phone: phone == null ? const Value.absent() : Value(phone.trim()),
          vatNumber: clearedVat,
        ),
      );

      return Store(
        id: existing.id,
        name: name?.trim() ?? existing.name,
        addressLine: addressLine?.trim() ?? existing.addressLine,
        postalCode: postalCode?.trim() ?? existing.postalCode,
        city: city?.trim() ?? existing.city,
        phone: phone?.trim() ?? existing.phone,
        vatNumber: vatNumber == null
            ? existing.vatNumber
            : _trimToNull(vatNumber),
        createdAt: existing.createdAt,
        imageAsset: existing.imageAsset,
      );
    });
  }

  /// Sets how long a `partial` commande may sit before the dashboard flags it.
  ///
  /// Refuses a non-positive number rather than storing it: zero days would flag
  /// every commande the moment it went partial, and a negative one would flag
  /// none at all — the dashboard warning would look broken in both directions.
  /// The settings screen falls back to `OrderRules.defaultStalePartialDays` on
  /// nonsense input, which is a decision about the form rather than about the
  /// establishment.
  Future<bool> setStalePartialOrderDays(String storeId, int days) async {
    if (days <= 0) return false;

    final changed =
        await (_db.update(_db.stores)..where((s) => s.id.equals(storeId)))
            .write(StoresCompanion(stalePartialOrderDays: Value(days)));
    return changed > 0;
  }

  // ---------------------------------------------------------------------------

  /// An optional text field as it should be stored: trimmed, and absent rather
  /// than blank. A whitespace-only VAT number would print an empty line on the
  /// bon de réception, which reads as a rendering bug rather than a missing
  /// value.
  static String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  SimpleSelectStatement<$StoresTable, StoreRow> _query() =>
      _db.select(_db.stores)..orderBy([
        (s) => OrderingTerm(expression: s.createdAt),
        (s) => OrderingTerm(expression: s.id),
      ]);

  List<Store> _toStores(List<StoreRow> rows) => rows.map(storeFromRow).toList();
}
