import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/employee_status.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import 'employee_actions_menu.dart';

/// One member of staff on the roster grid, as a vertical card:
///
/// - identity — photo, name, PIN, the Actif / Retiré status and the role;
/// - contact — phone and email;
/// - the hourly rate, put forward in a tinted block;
/// - the hire date (the position is already the role badge).
///
/// Everything is on the ⋮ menu ([EmployeeActionsMenu]) — the two
/// histories, Modifier, Retirer / Restaurer; the card itself is not a button.
/// A retired employee's card turns red — dashed outline, Retiré badge, the
/// rate block — and its foot line gives the date they were retired instead of
/// the hire date.
class EmployeeCard extends StatelessWidget {
  const EmployeeCard({
    required this.employee,
    required this.onAttendance,
    required this.onPayroll,
    required this.onEdit,
    required this.onArchive,
    required this.onRestore,
    super.key,
  });

  final Employee employee;
  final VoidCallback onAttendance;
  final VoidCallback onPayroll;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final archived = !isEmployeeActive(employee);

    return AppCard(
      dashedBorderColor: archived ? AppColors.error : null,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EmployeeAvatar(employee: employee, size: 56, dimmed: archived),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      employeeDisplayName(employee),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      l10n.employeePinLabel(employee.pin),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        LabelChip(
                          key: const ValueKey('employee-card-status'),
                          label: archived
                              ? l10n.employeesArchivedPill
                              : l10n.employeeStatusActive,
                          background: archived
                              ? AppColors.outOfStock.container
                              : AppColors.inStock.container,
                          foreground: archived
                              ? AppColors.outOfStock.foreground
                              : AppColors.inStock.foreground,
                          dense: true,
                          borderRadius: AppRadius.smAll,
                        ),
                        EmployeeRoleBadge(role: employee.role),
                      ],
                    ),
                  ],
                ),
              ),
              EmployeeActionsMenu(
                employee: employee,
                onAttendance: onAttendance,
                onPayroll: onPayroll,
                onEdit: onEdit,
                onArchive: onArchive,
                onRestore: onRestore,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          InfoLine(icon: LucideIcons.phone, text: employee.phone),
          const SizedBox(height: AppSpacing.sm),
          InfoLine(icon: LucideIcons.mail, text: employee.email),
          const SizedBox(height: AppSpacing.lg),
          HighlightTile(
            key: const ValueKey('employee-card-rate'),
            icon: LucideIcons.coins,
            value: '${Formatters.price(employee.pay)} /h',
            caption: l10n.employeeCardHourlyRate,
            color: archived ? AppColors.error : AppColors.primary600,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (archived)
            InfoLine(
              key: const ValueKey('employee-card-retired'),
              icon: LucideIcons.calendarX,
              text: l10n.employeeCardRetiredOn,
              value: Formatters.date(employee.archivedAt!),
              valueColor: AppColors.error,
            )
          else
            InfoLine(
              key: const ValueKey('employee-card-hired'),
              icon: LucideIcons.calendar,
              text: l10n.employeeCardHiredOn,
              value: Formatters.date(employee.hireDate),
            ),
        ],
      ),
    );
  }
}
