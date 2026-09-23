import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/employee_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';

enum _Action { attendance, payroll, edit, archive, restore }

/// The ⋮ menu of a staff card or table row: the person's pointage and
/// payment histories, Modifier, and Retirer (or Restaurer for someone
/// retired). White, rounded, an icon beside each action, and the rate
/// block's green wash on hover.
///
/// [includeHistories] is off where the two histories already have buttons of
/// their own (the table's Actions column).
class EmployeeActionsMenu extends StatelessWidget {
  const EmployeeActionsMenu({
    required this.employee,
    required this.onAttendance,
    required this.onPayroll,
    required this.onEdit,
    required this.onArchive,
    required this.onRestore,
    this.includeHistories = true,
    super.key,
  });

  final Employee employee;
  final VoidCallback onAttendance;
  final VoidCallback onPayroll;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onRestore;
  final bool includeHistories;

  /// The rate block's green wash — the menu's hover, so the two read as one
  /// family.
  static final Color _hover = AppColors.primary600.withValues(alpha: 0.08);

  static PopupMenuItem<_Action> _item(
    _Action action,
    IconData icon,
    String label, {
    Color color = AppColors.textPrimary,
  }) {
    return PopupMenuItem(
      value: action,
      child: Row(
        children: [
          Icon(icon, size: AppSizing.iconSm, color: color),
          const SizedBox(width: AppSpacing.md),
          // A menu is at most 280dp wide; a long label ellipsizes rather
          // than overflowing it.
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final archived = !isEmployeeActive(employee);

    // The menu route captures the themes around its button, so the hover
    // colour set here reaches the items.
    return Theme(
      data: theme.copyWith(hoverColor: _hover, highlightColor: _hover),
      child: PopupMenuButton<_Action>(
        key: const ValueKey('employee-card-menu'),
        tooltip: l10n.employeeCardActions,
        // The brand green of the rate, so the menu reads as part of the card.
        icon: const Icon(
          LucideIcons.ellipsisVertical,
          size: AppSizing.iconSm,
          color: AppColors.primary600,
        ),
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        onSelected: (action) => switch (action) {
          _Action.attendance => onAttendance(),
          _Action.payroll => onPayroll(),
          _Action.edit => onEdit(),
          _Action.archive => onArchive(),
          _Action.restore => onRestore(),
        },
        itemBuilder: (_) => [
          if (includeHistories) ...[
            _item(
              _Action.attendance,
              LucideIcons.history,
              l10n.employeeActionAttendance,
            ),
            _item(
              _Action.payroll,
              LucideIcons.receipt,
              l10n.employeeActionPayroll,
            ),
            const PopupMenuDivider(),
          ],
          _item(_Action.edit, LucideIcons.pencil, l10n.actionEdit),
          if (archived)
            _item(
              _Action.restore,
              LucideIcons.userCheck,
              l10n.employeeRestore,
            )
          else
            _item(
              _Action.archive,
              LucideIcons.userMinus,
              l10n.employeeArchiveConfirm,
              color: AppColors.error,
            ),
        ],
      ),
    );
  }
}
