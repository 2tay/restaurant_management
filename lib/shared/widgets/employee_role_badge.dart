import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import 'status_pill.dart';

/// The Owner / Gérant / Employé chip.
///
/// Owner is tinted; the other two are neutral, because "gérant" and "employé"
/// are the ordinary cases and should not compete for attention — same
/// treatment the removed `TeamMember` role chip used.
class EmployeeRoleBadge extends StatelessWidget {
  const EmployeeRoleBadge({required this.role, super.key});

  final EmployeeRole role;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isOwner = role == EmployeeRole.owner;

    return LabelChip(
      label: employeeRoleLabel(l10n, role),
      icon: switch (role) {
        EmployeeRole.owner => LucideIcons.crown,
        EmployeeRole.manager => LucideIcons.shieldCheck,
        EmployeeRole.staff => LucideIcons.user,
      },
      background: isOwner
          ? AppColors.primaryContainer
          : AppColors.surfaceVariant,
      foreground: isOwner
          ? AppColors.onPrimaryContainer
          : AppColors.textSecondary,
      borderRadius: AppRadius.smAll,
    );
  }
}

/// Shared role naming, so the list, the form, the detail page and the account
/// screen all agree. The one place a [EmployeeRole] becomes words.
String employeeRoleLabel(AppLocalizations l10n, EmployeeRole role) =>
    switch (role) {
      EmployeeRole.owner => l10n.employeeRoleOwner,
      EmployeeRole.manager => l10n.employeeRoleManager,
      EmployeeRole.staff => l10n.employeeRoleStaff,
    };

/// Shared role description, shown under the name on the role picker.
String employeeRoleDescription(AppLocalizations l10n, EmployeeRole role) =>
    switch (role) {
      EmployeeRole.owner => l10n.employeeRoleOwnerBody,
      EmployeeRole.manager => l10n.employeeRoleManagerBody,
      EmployeeRole.staff => l10n.employeeRoleStaffBody,
    };
