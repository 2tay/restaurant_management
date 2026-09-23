import 'package:drift/drift.dart';

import '../../models/store.dart';
import '../../models/store_settings.dart';
import '../database/app_database.dart';

Store storeFromRow(StoreRow row) => Store(
  id: row.id,
  name: row.name,
  addressLine: row.addressLine,
  postalCode: row.postalCode,
  city: row.city,
  phone: row.phone,
  createdAt: row.createdAt,
  vatNumber: row.vatNumber,
  imageAsset: row.imageAsset,
);

/// The pointage break allowance lives on the store row too, since Phase 2
/// employé folded `mock_store_settings.dart` into it — `storeId` plus this
/// field is the whole `StoreSettings` record.
StoreSettings storeSettingsFromRow(StoreRow row) => StoreSettings(
  storeId: row.id,
  maxBreakMinutes: row.maxBreakMinutes,
  stalePartialOrderDays: row.stalePartialOrderDays,
);

/// [settings] is optional: when omitted the settings columns take their
/// schema defaults (which are the `core/utils/` constants), which is what
/// `StoreRepository.createStore` wants. The seed passes the demo settings so a
/// re-seed restores the per-store break allowance.
StoresCompanion storeToRow(Store store, [StoreSettings? settings]) =>
    StoresCompanion.insert(
      id: store.id,
      name: store.name,
      addressLine: store.addressLine,
      postalCode: store.postalCode,
      city: store.city,
      phone: store.phone,
      createdAt: store.createdAt,
      vatNumber: Value(store.vatNumber),
      imageAsset: Value(store.imageAsset),
      stalePartialOrderDays: settings == null
          ? const Value.absent()
          : Value(settings.stalePartialOrderDays),
      maxBreakMinutes: settings == null
          ? const Value.absent()
          : Value(settings.maxBreakMinutes),
    );
