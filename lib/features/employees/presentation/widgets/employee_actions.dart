import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/employee_status.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/current_employee.dart';
import '../../../../data/providers.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

/// Retire (archive) an employee, after asking — the one path the detail
/// drawer and the roster card's menu both take.
///
/// Refused outright, with the reason, for yourself and for the last owner
/// (`EmployeeRepository.archiveRefusal`). Otherwise the confirm warns — but
/// does not stop — when the person is still in service (their shift stays
/// open until the journée closes) or still owed finished days (they stay
/// payable in Paiement).
Future<void> confirmArchiveEmployee(
  BuildContext context,
  WidgetRef ref,
  Employee employee,
) async {
  final l10n = AppLocalizations.of(context);
  final employees = ref.read(employeeRepositoryProvider);
  final actor = ref.read(currentEmployeeProvider);
  final name = employeeDisplayName(employee);

  final refusal = await employees.archiveRefusal(
    employee.id,
    byEmployeeId: actor?.id,
  );
  if (!context.mounted) return;
  if (refusal != null) {
    AppSnackBar.error(context, switch (refusal) {
      ArchiveRefusal.self => l10n.employeeArchiveRefusedSelf,
      ArchiveRefusal.lastOwner => l10n.employeeArchiveRefusedLastOwner,
    });
    return;
  }

  final days = await ref
      .read(attendanceRepositoryProvider)
      .forEmployee(employee.id);
  final inService = days.any(
    (d) =>
        d.status == AttendanceStatus.working ||
        d.status == AttendanceStatus.onBreak,
  );
  final unpaid = await ref
      .read(payrollRepositoryProvider)
      .preview(employee.id, employee.storeId);
  if (!context.mounted) return;

  final confirmed = await ConfirmDialog.show(
    context,
    title: l10n.employeeArchiveTitle('« $name »'),
    message: [
      l10n.employeeArchiveBody,
      if (inService) l10n.employeeArchiveWarnInService(name),
      if (!unpaid.isEmpty)
        l10n.employeeArchiveWarnUnpaid(
          unpaid.days.length,
          Formatters.price(unpaid.amount),
        ),
    ].join('\n\n'),
    confirmLabel: l10n.employeeArchiveConfirm,
  );
  if (!confirmed || !context.mounted) return;

  final archived = await employees.archive(
    employee.id,
    byEmployeeId: actor?.id,
  );
  if (!context.mounted) return;
  if (!archived) {
    AppSnackBar.error(context, l10n.employeeArchiveFailed);
    return;
  }
  AppSnackBar.success(context, l10n.employeeArchived);
}

/// Bring a retired employee back.
Future<void> restoreEmployee(
  BuildContext context,
  WidgetRef ref,
  Employee employee,
) async {
  final l10n = AppLocalizations.of(context);
  await ref.read(employeeRepositoryProvider).restore(employee.id);
  if (!context.mounted) return;
  AppSnackBar.success(context, l10n.employeeRestored);
}
