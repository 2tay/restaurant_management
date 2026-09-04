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

/// The pointage / paie settings live on the store row too, since Phase 2 employé
/// folded `mock_store_settings.dart` into it — `storeId` plus these six fields is
/// the whole `StoreSettings` record.
StoreSettings storeSettingsFromRow(StoreRow row) => StoreSettings(
  storeId: row.id,
  openMinutes: row.openMinutes,
  closeMinutes: row.closeMinutes,
  maxBreakMinutes: row.maxBreakMinutes,
  overtimeMultiplier: row.overtimeMultiplier,
  workingDaysPerMonth: row.workingDaysPerMonth,
  stalePartialOrderDays: row.stalePartialOrderDays,
);

/// [settings] is optional: when omitted the six settings columns take their
/// schema defaults (which are the `core/utils/` constants), which is what
/// `StoreRepository.createStore` wants. The seed passes the demo settings so a
/// re-seed restores the per-store pointage hours.
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
      openMinutes: settings == null
          ? const Value.absent()
          : Value(settings.openMinutes),
      closeMinutes: settings == null
          ? const Value.absent()
          : Value(settings.closeMinutes),
      maxBreakMinutes: settings == null
          ? const Value.absent()
          : Value(settings.maxBreakMinutes),
      overtimeMultiplier: settings == null
          ? const Value.absent()
          : Value(settings.overtimeMultiplier),
      workingDaysPerMonth: settings == null
          ? const Value.absent()
          : Value(settings.workingDaysPerMonth),
    );
