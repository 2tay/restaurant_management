import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/employee_status.dart';
import '../../../../data/providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

/// Retire (archive) an employee, after asking — the one path the detail
/// drawer and the roster card's menu both take.
Future<void> confirmArchiveEmployee(
  BuildContext context,
  WidgetRef ref,
  Employee employee,
) async {
  final l10n = AppLocalizations.of(context);

  final confirmed = await ConfirmDialog.show(
    context,
    title: l10n.employeeArchiveTitle('« ${employeeDisplayName(employee)} »'),
    message: l10n.employeeArchiveBody,
    confirmLabel: l10n.employeeArchiveConfirm,
  );
  if (!confirmed || !context.mounted) return;

  await ref.read(employeeRepositoryProvider).archive(employee.id);
  if (!context.mounted) return;
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
