import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/employee_status.dart';
import '../../models/models.dart';

/// The circular photo-or-initials tile every employee-facing screen shows.
///
/// One shared widget rather than the four near-identical private copies the
/// removed module carried. Photo is mocked (`Employee.photoAsset` is a
/// nullable asset path, no picker behind it) — null renders the initials.
class EmployeeAvatar extends StatelessWidget {
  const EmployeeAvatar({
    required this.employee,
    this.size = 48,
    this.dimmed = false,
    super.key,
  });

  final Employee employee;
  final double size;

  /// Greyed out — for an archived employee's row.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photo = employee.photoAsset;

    final style = (size >= 60 ? theme.textTheme.titleLarge : theme.textTheme.labelLarge)
        ?.copyWith(
          color: dimmed
              ? AppColors.textDisabled
              : AppColors.onPrimaryContainer,
        );

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: dimmed ? AppColors.neutral100 : AppColors.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: photo != null
          ? Image.asset(photo, fit: BoxFit.cover, width: size, height: size)
          : Text(employeeInitials(employee), style: style),
    );
  }
}
