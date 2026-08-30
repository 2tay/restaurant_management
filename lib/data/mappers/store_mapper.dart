import 'package:drift/drift.dart';

import '../../models/store.dart';
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

/// Note what is missing: `stalePartialOrderDays`.
///
/// It is a column on the row and not a field on the model — it is a preference
/// about how the dashboard behaves, not a fact about the shop. Leaving it absent
/// means an insert takes the default and an upsert leaves whatever the user
/// chose alone. The settings screen writes that column directly.
StoresCompanion storeToRow(Store store) => StoresCompanion.insert(
  id: store.id,
  name: store.name,
  addressLine: store.addressLine,
  postalCode: store.postalCode,
  city: store.city,
  phone: store.phone,
  createdAt: store.createdAt,
  vatNumber: Value(store.vatNumber),
  imageAsset: Value(store.imageAsset),
);
