import 'package:drift/drift.dart';

import '../../models/business_day.dart';
import '../database/app_database.dart';

BusinessDay businessDayFromRow(BusinessDayRow row) => BusinessDay(
  id: row.id,
  storeId: row.storeId,
  date: row.date,
  openedAt: row.openedAt,
  openedByEmployeeId: row.openedByEmployeeId,
  closedAt: row.closedAt,
  closedByEmployeeId: row.closedByEmployeeId,
);

BusinessDaysCompanion businessDayToRow(BusinessDay day) =>
    BusinessDaysCompanion.insert(
      id: day.id,
      storeId: day.storeId,
      date: day.date,
      openedAt: day.openedAt,
      openedByEmployeeId: Value(day.openedByEmployeeId),
      closedAt: Value(day.closedAt),
      closedByEmployeeId: Value(day.closedByEmployeeId),
    );
