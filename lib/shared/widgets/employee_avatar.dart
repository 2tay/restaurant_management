import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/theme/app_colors.dart';
import '../../core/utils/employee_status.dart';
import '../../data/employee_photo_store.dart';
import '../../models/models.dart';

/// The image behind an `Employee.photoAsset` string.
///
/// Since schema v20 the value is a bare file name in `EmployeePhotoStore`'s
/// folder, the same on every tablet (SYNC_PLAN.md, Phase 8). Before, it was an
/// absolute path on one device; that still resolves while the file exists. A
/// value with a separator that is not an existing file is a bundled asset
/// path. Anything that fails to load becomes initials (the caller's
/// `errorBuilder`), including a photo still on its way from the server.
ImageProvider employeePhotoImage(String path) {
  if (p.isAbsolute(path) && File(path).existsSync()) {
    return FileImage(File(path));
  }
  final folder = EmployeePhotoStore.cachedDirectory;
  if (!path.contains('/') && !path.contains(r'\') && folder != null) {
    return FileImage(File(p.join(folder.path, path)));
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
          // Rebuilt when a photo arrives from the server, so a tile that was
          // showing initials picks it up.
          ? ValueListenableBuilder<int>(
              valueListenable: EmployeePhotoStore.revision,
              builder: (context, _, _) {
                final image = employeePhotoImage(photo);
                return Image(
                  key: ValueKey(EmployeePhotoStore.revision.value),
                  image: image,
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  errorBuilder: (_, _, _) => initials,
                );
              },
            )
          : initials,
    );
  }
}
