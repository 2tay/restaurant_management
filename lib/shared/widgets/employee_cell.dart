import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/employee_status.dart';
import '../../models/models.dart';
import 'employee_avatar.dart';

/// The "Employé" cell shared by the Personnel, Pointage and Paiement tables:
/// avatar, then the name with the PIN underneath — the bare number, no
/// "PIN" label, since the column context already says what it is.
///
/// A null [employee] (a row whose employee was deleted) renders an em dash.
class EmployeeCell extends StatelessWidget {
  const EmployeeCell({
    required this.employee,
    this.dimmed = false,
    this.trailing,
    super.key,
  });

  final Employee? employee;

  /// Greyed avatar — for a retired employee's row.
  final bool dimmed;

  /// Shown after the name, e.g. the "Retiré" chip.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final employee = this.employee;
    if (employee == null) return const Text('—');
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        EmployeeAvatar(employee: employee, size: 32, dimmed: dimmed),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              employeeDisplayName(employee),
              style: theme.textTheme.bodyMedium,
            ),
            Text(
              employee.pin,
              key: const ValueKey('employee-cell-pin'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          trailing!,
        ],
      ],
    );
  }
}
