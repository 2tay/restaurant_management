import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/employee_status.dart';
import '../../models/models.dart';
import 'employee_avatar.dart';

/// Who a day card is about — the photo (or initials), the name, and the
/// masked PIN beneath it.
///
/// The card-sized sibling of `EmployeeCell`: a larger avatar and a bolder
/// name, and a placeholder avatar rather than a dash when the employee is
/// unknown. [trailing] sits after the name — « Retiré » on the payroll card.
class EmployeeCardIdentity extends StatelessWidget {
  const EmployeeCardIdentity({required this.employee, this.trailing, super.key});

  final Employee? employee;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final employee = this.employee;

    return Row(
      children: [
        if (employee != null)
          EmployeeAvatar(employee: employee, size: 36)
        else
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.user,
              size: AppSizing.iconSm,
              color: AppColors.textSecondary,
            ),
          ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      employee == null ? '—' : employeeDisplayName(employee),
                      style: theme.textTheme.labelLarge?.copyWith(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    trailing!,
                  ],
                ],
              ),
              if (employee != null)
                Text(
                  maskedPin(employee.pin),
                  key: const ValueKey('employee-card-pin'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
