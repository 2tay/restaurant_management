import 'package:drift/drift.dart';

import '../../models/payroll_period.dart';
import '../database/app_database.dart';

PayrollPeriod payrollPeriodFromRow(PayrollPeriodRow row) => PayrollPeriod(
  id: row.id,
  storeId: row.storeId,
  employeeId: row.employeeId,
  startDate: row.startDate,
  endDate: row.endDate,
  workedDays: row.workedDays,
  totalWorkedHours: row.totalWorkedHours,
  totalOvertimeHours: row.totalOvertimeHours,
  appliedRate: row.appliedRate,
  computedAmount: row.computedAmount,
  status: row.status,
  createdAt: row.createdAt,
  paidByEmployeeId: row.paidByEmployeeId,
  paidAt: row.paidAt,
);

PayrollPeriodsCompanion payrollPeriodToRow(PayrollPeriod period) =>
    PayrollPeriodsCompanion.insert(
      id: period.id,
      employeeId: period.employeeId,
      storeId: period.storeId,
      startDate: period.startDate,
      endDate: period.endDate,
      workedDays: period.workedDays,
      totalWorkedHours: period.totalWorkedHours,
      totalOvertimeHours: period.totalOvertimeHours,
      appliedRate: period.appliedRate,
      computedAmount: period.computedAmount,
      status: period.status,
      createdAt: period.createdAt,
      paidByEmployeeId: Value(period.paidByEmployeeId),
      paidAt: Value(period.paidAt),
    );
