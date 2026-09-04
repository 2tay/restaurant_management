import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/theme/app_colors.dart';
import '../../core/utils/employee_status.dart';
import '../../models/models.dart';

/// The image behind an `Employee.photoAsset` string.
///
/// The value is an absolute path to a file `EmployeePhotoStore` owns once a
/// photo has been chosen, and a bundled asset path otherwise (the shape the
/// field always had). An absolute path that no longer exists on disk — a photo
/// deleted under the app's feet — falls through to `AssetImage`, which the
/// caller's `errorBuilder` then turns into initials.
ImageProvider employeePhotoImage(String path) {
  if (p.isAbsolute(path) && File(path).existsSync()) {
    return FileImage(File(path));
  }
  return AssetImage(path);
}

/// The circular photo-or-initials tile every employee-facing screen shows.
///
/// One shared widget rather than the four near-identical private copies the
/// removed module carried. Null [Employee.photoAsset] — and any photo that
/// fails to load — renders the initials.
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

    final initials = Text(employeeInitials(employee), style: style);

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
          ? Image(
              image: employeePhotoImage(photo),
              fit: BoxFit.cover,
              width: size,
              height: size,
              errorBuilder: (_, _, _) => initials,
            )
          : initials,
    );
  }
}
