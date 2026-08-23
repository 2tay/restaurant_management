import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import 'team_list_page.dart';

/// What each role can do, as a matrix.
///
/// Deliberately three roles and seven permissions. A restaurant is not an
/// enterprise, and a matrix nobody can hold in their head is worse than none —
/// it just means everyone gets made a manager.
///
/// Permission is shown with a tick or a dash rather than colour alone, for the
/// same reason the stock badges carry icons.
class RolesPermissionsPage extends StatelessWidget {
  const RolesPermissionsPage({required this.storeId, super.key});

  final String storeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Ordered least to most privileged, so reading down a column tells a story.
    final permissions = <({String label, Set<TeamRole> granted})>[
      (
        label: l10n.permissionViewInventory,
        granted: {TeamRole.staff, TeamRole.manager, TeamRole.owner},
      ),
      (
        label: l10n.permissionRecordMovements,
        granted: {TeamRole.staff, TeamRole.manager, TeamRole.owner},
      ),
      (
        label: l10n.permissionEditItems,
        granted: {TeamRole.manager, TeamRole.owner},
      ),
      (
        label: l10n.permissionManageSuppliers,
        granted: {TeamRole.manager, TeamRole.owner},
      ),
      (
        label: l10n.permissionViewReports,
        granted: {TeamRole.manager, TeamRole.owner},
      ),
      (
        label: l10n.permissionManageTeam,
        granted: {TeamRole.manager, TeamRole.owner},
      ),
      (label: l10n.permissionManageAccount, granted: {TeamRole.owner}),
    ];

    return ShellPage(
      back: BackDestination(
        label: l10n.teamTitle,
        path: Routes.toTeam(storeId),
      ),
      crumbs: [
        Crumb(l10n.teamTitle, Routes.toTeam(storeId)),
        Crumb(l10n.rolesTitle),
      ],
      title: l10n.rolesTitle,
      subtitle: l10n.rolesSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final role in TeamRole.values) ...[
                Expanded(
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          roleLabel(l10n, role),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          roleDescription(l10n, role),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                if (role != TeamRole.values.last)
                  const SizedBox(width: AppSpacing.lg),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          DataTableWrapper(
            minWidth: 760,
            columns: [
              DataColumn(label: Text(l10n.rolesSubtitle)),
              for (final role in TeamRole.values)
                DataColumn(label: Text(roleLabel(l10n, role))),
            ],
            rows: [
              for (final permission in permissions)
                DataRow(
                  cells: [
                    DataCell(Text(permission.label)),
                    for (final role in TeamRole.values)
                      DataCell(
                        _PermissionMark(
                          granted: permission.granted.contains(role),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PermissionMark extends StatelessWidget {
  const _PermissionMark({required this.granted});

  final bool granted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Icon(
      granted ? LucideIcons.circleCheck : LucideIcons.minus,
      size: AppSizing.iconMd,
      color: granted ? AppColors.inStock.solid : AppColors.textDisabled,
      // The icon alone conveys nothing to a screen reader, and this table is
      // entirely icons.
      semanticLabel: granted
          ? l10n.a11yPermissionGranted
          : l10n.a11yPermissionDenied,
    );
  }
}
