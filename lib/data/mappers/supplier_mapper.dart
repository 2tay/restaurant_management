import 'package:drift/drift.dart';

import '../../models/price_history_entry.dart';
import '../../models/supplier.dart';
import '../../models/supplier_price.dart';
import '../database/app_database.dart';

Supplier supplierFromRow(SupplierRow row) => Supplier(
  id: row.id,
  storeId: row.storeId,
  name: row.name,
  contactName: row.contactName,
  email: row.email,
  phone: row.phone,
  addressLine: row.addressLine,
  postalCode: row.postalCode,
  city: row.city,
  note: row.note,
);

SuppliersCompanion supplierToRow(Supplier supplier) =>
    SuppliersCompanion.insert(
      id: supplier.id,
      storeId: supplier.storeId,
      name: supplier.name,
      contactName: supplier.contactName,
      email: supplier.email,
      phone: supplier.phone,
      addressLine: supplier.addressLine,
      postalCode: supplier.postalCode,
      city: supplier.city,
      note: Value(supplier.note),
    );

SupplierPrice supplierPriceFromRow(SupplierPriceRow row) => SupplierPrice(
  id: row.id,
  itemId: row.itemId,
  supplierId: row.supplierId,
  pricePerUnit: row.pricePerUnit,
  effectiveDate: row.effectiveDate,
  isDefault: row.isDefault,
);

SupplierPricesCompanion supplierPriceToRow(SupplierPrice price) =>
    SupplierPricesCompanion.insert(
      id: price.id,
      itemId: price.itemId,
      supplierId: price.supplierId,
      pricePerUnit: price.pricePerUnit,
      effectiveDate: price.effectiveDate,
      isDefault: price.isDefault,
    );

PriceHistoryEntry priceHistoryFromRow(PriceHistoryRow row) => PriceHistoryEntry(
  id: row.id,
  itemId: row.itemId,
  supplierId: row.supplierId,
  oldPrice: row.oldPrice,
  newPrice: row.newPrice,
  changedAt: row.changedAt,
  changedByName: row.changedByName,
);

PriceHistoryCompanion priceHistoryToRow(PriceHistoryEntry entry) =>
    PriceHistoryCompanion.insert(
      id: entry.id,
      itemId: entry.itemId,
      supplierId: entry.supplierId,
      oldPrice: entry.oldPrice,
      newPrice: entry.newPrice,
      changedAt: entry.changedAt,
      changedByName: entry.changedByName,
    );
