import 'package:drift/drift.dart';

import '../../models/employee.dart';
import '../database/app_database.dart';

Employee employeeFromRow(EmployeeRow row) => Employee(
  id: row.id,
  storeId: row.storeId,
  firstName: row.firstName,
  lastName: row.lastName,
  cin: row.cin,
  phone: row.phone,
  email: row.email,
  hireDate: row.hireDate,
  role: row.role,
  contractType: row.contractType,
  pay: row.pay,
  createdAt: row.createdAt,
  photoAsset: row.photoAsset,
  scheduledStartMinutes: row.scheduledStartMinutes,
  scheduledEndMinutes: row.scheduledEndMinutes,
  archivedAt: row.archivedAt,
);

/// Writes every column, [Employee.archivedAt] included.
///
/// Safe here because the caller always has a whole employee in hand — the seed,
/// or the employee repository, which builds the archived transition itself.
/// `EmployeeRepository.update` has no `archivedAt` parameter, exactly as
/// `EmployeeMutations.update` had none: archiving is its own method.
EmployeesCompanion employeeToRow(Employee employee) => EmployeesCompanion.insert(
  id: employee.id,
  storeId: employee.storeId,
  firstName: employee.firstName,
  lastName: employee.lastName,
  cin: employee.cin,
  phone: employee.phone,
  email: employee.email,
  hireDate: employee.hireDate,
  role: employee.role,
  contractType: employee.contractType,
  pay: employee.pay,
  createdAt: employee.createdAt,
  photoAsset: Value(employee.photoAsset),
  scheduledStartMinutes: Value(employee.scheduledStartMinutes),
  scheduledEndMinutes: Value(employee.scheduledEndMinutes),
  archivedAt: Value(employee.archivedAt),
);
