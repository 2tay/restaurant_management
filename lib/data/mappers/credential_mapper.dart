import 'package:drift/drift.dart';

import '../../models/employee_credential.dart';
import '../database/app_database.dart';

EmployeeCredential credentialFromRow(EmployeeCredentialRow row) =>
    EmployeeCredential(
      id: row.id,
      employeeId: row.employeeId,
      pinHash: row.pinHash,
      failedAttempts: row.failedAttempts,
      lockedUntil: row.lockedUntil,
      lastLoginAt: row.lastLoginAt,
    );

EmployeeCredentialsCompanion credentialToRow(EmployeeCredential credential) =>
    EmployeeCredentialsCompanion.insert(
      id: credential.id,
      employeeId: credential.employeeId,
      pinHash: credential.pinHash,
      failedAttempts: Value(credential.failedAttempts),
      lockedUntil: Value(credential.lockedUntil),
      lastLoginAt: Value(credential.lastLoginAt),
    );
