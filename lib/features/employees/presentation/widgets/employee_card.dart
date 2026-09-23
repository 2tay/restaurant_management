import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/employee_status.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

/// What the card's ⋮ menu offers.
enum _CardAction { edit, archive, restore }

/// One member of staff on the roster grid, as a vertical card:
///
/// - identity — photo, name, PIN, the Actif / Retiré status and the role;
/// - contact — phone and email;
/// - the hourly rate, put forward in a tinted block;
/// - the hire date (the position is already the role badge).
///
/// Tapping the card opens the detail drawer ([onTap]); the ⋮ menu edits,
/// retires or restores without opening it. Outlined in green on hover, and
/// while its drawer is open ([selected]).
class EmployeeCard extends StatelessWidget {
  const EmployeeCard({
    required this.employee,
    required this.onTap,
    required this.onEdit,
    required this.onArchive,
    required this.onRestore,
    this.selected = false,
    super.key,
  });

  final Employee employee;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onRestore;

  /// The card whose detail drawer is open — drawn like a hovered one.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final archived = !isEmployeeActive(employee);

    return AppCard(
      onTap: onTap,
      outlineOnHover: true,
      selected: selected,
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
                              ? AppColors.surfaceVariant
                              : AppColors.inStock.container,
                          foreground: archived
                              ? AppColors.textSecondary
                              : AppColors.inStock.foreground,
                          dense: true,
                        ),
                        EmployeeRoleBadge(role: employee.role),
                      ],
                    ),
                  ],
                ),
              ),
              _CardMenu(
                archived: archived,
                onSelected: (action) => switch (action) {
                  _CardAction.edit => onEdit(),
                  _CardAction.archive => onArchive(),
                  _CardAction.restore => onRestore(),
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          InfoLine(icon: LucideIcons.phone, text: employee.phone),
          const SizedBox(height: AppSpacing.sm),
          InfoLine(icon: LucideIcons.mail, text: employee.email),
          const SizedBox(height: AppSpacing.lg),
          HighlightTile(
            icon: LucideIcons.coins,
            value: '${Formatters.price(employee.pay)} /h',
            caption: l10n.employeeCardHourlyRate,
          ),
          const SizedBox(height: AppSpacing.lg),
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

class _CardMenu extends StatelessWidget {
  const _CardMenu({required this.archived, required this.onSelected});

  final bool archived;
  final ValueChanged<_CardAction> onSelected;

  static PopupMenuItem<_CardAction> _item(
    _CardAction action,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem(
      value: action,
      child: Row(
        children: [
          Icon(icon, size: AppSizing.iconSm, color: color),
          const SizedBox(width: AppSpacing.md),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PopupMenuButton<_CardAction>(
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
      onSelected: onSelected,
      itemBuilder: (_) => [
        _item(
          _CardAction.edit,
          LucideIcons.pencil,
          l10n.actionEdit,
          AppColors.textPrimary,
        ),
        if (archived)
          _item(
            _CardAction.restore,
            LucideIcons.userCheck,
            l10n.employeeRestore,
            AppColors.textPrimary,
          )
        else
          _item(
            _CardAction.archive,
            LucideIcons.userMinus,
            l10n.employeeArchiveConfirm,
            AppColors.error,
          ),
      ],
    );
  }
}
