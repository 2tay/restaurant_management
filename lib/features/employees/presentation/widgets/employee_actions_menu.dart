import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/employee_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';

/// The ⋮ contextual menu of a staff card or table row:
///
/// 1. Historique pointage — the person's attendance history, filtered to them;
/// 2. Historique paiement — their payment history, filtered to them;
/// 3. Modifier — the edit wizard;
/// 4. Retirer (red) — or Restaurer for someone already retired.
///
/// A [MenuAnchor], not a modal popup: anchored to the button and kept inside
/// the window by the framework, closed by Échap or a click outside — and that
/// click is not swallowed, so pressing another employee's ⋮ closes this menu
/// and opens theirs in one go.
///
/// Dressed like the product card's ⋮ menu: white, rounded, the popup's
/// shadow and no border, 190–220dp wide; each row a grey icon then the label
/// (Retirer in red).
///
/// [includeHistories] is off where the two histories already have buttons of
/// their own (the table's Actions column).
class EmployeeActionsMenu extends StatefulWidget {
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

  @override
  State<EmployeeActionsMenu> createState() => _EmployeeActionsMenuState();
}

class _EmployeeActionsMenuState extends State<EmployeeActionsMenu> {
  final _controller = MenuController();

  /// The menu's own width band, in the design brief's range.
  static const double _minWidth = 190;
  static const double _maxWidth = 220;

  /// Échap closes the menu whatever holds the keyboard focus — opened with the
  /// mouse, the focus is not inside it, so the menu's own shortcut would not
  /// hear the key. Listening only while open.
  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _controller.isOpen) {
      _controller.close();
      return true;
    }
    return false;
  }

  void _listen(bool on) => on
      ? HardwareKeyboard.instance.addHandler(_onKey)
      : HardwareKeyboard.instance.removeHandler(_onKey);

  @override
  void dispose() {
    _listen(false);
    super.dispose();
  }

  static const MenuStyle _menuStyle = MenuStyle(
    backgroundColor: WidgetStatePropertyAll(AppColors.surface),
    surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
    // The popup menu's own elevation and shadow, as on the product card.
    elevation: WidgetStatePropertyAll(3),
    shadowColor: WidgetStatePropertyAll(Colors.black),
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(vertical: AppSpacing.sm),
    ),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
    ),
  );

  Widget _item({
    required String keyName,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool destructive = false,
  }) {
    final textColor = destructive ? AppColors.error : AppColors.textPrimary;
    final iconColor = destructive ? AppColors.error : AppColors.textSecondary;
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: _minWidth,
        maxWidth: _maxWidth,
      ),
      child: MenuItemButton(
        key: ValueKey('employee-menu-$keyName'),
        onPressed: onPressed,
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(textColor),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.md),
          ),
          minimumSize: const WidgetStatePropertyAll(
            Size(_minWidth, kMinInteractiveDimension),
          ),
        ),
        // Icon, gap, label — the product card menu's row.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppSizing.iconSm, color: iconColor),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final archived = !isEmployeeActive(widget.employee);

    return MenuAnchor(
      controller: _controller,
      style: _menuStyle,
      onOpen: () => _listen(true),
      onClose: () => _listen(false),
      menuChildren: [
        if (widget.includeHistories) ...[
          _item(
            keyName: 'attendance',
            icon: LucideIcons.history,
            label: l10n.employeeActionAttendance,
            onPressed: widget.onAttendance,
          ),
          _item(
            keyName: 'payroll',
            icon: LucideIcons.wallet,
            label: l10n.employeeActionPayroll,
            onPressed: widget.onPayroll,
          ),
        ],
        _item(
          keyName: 'edit',
          icon: LucideIcons.pencil,
          label: l10n.actionEdit,
          onPressed: widget.onEdit,
        ),
        if (archived)
          _item(
            keyName: 'restore',
            icon: LucideIcons.userCheck,
            label: l10n.employeeRestore,
            onPressed: widget.onRestore,
          )
        else
          _item(
            keyName: 'archive',
            icon: LucideIcons.userMinus,
            label: l10n.employeeArchiveConfirm,
            onPressed: widget.onArchive,
            destructive: true,
          ),
      ],
      builder: (context, controller, _) => IconButton(
        key: const ValueKey('employee-card-menu'),
        tooltip: l10n.employeeCardActions,
        // The brand green of the rate, so the button reads as part of the
        // card.
        icon: const Icon(
          LucideIcons.ellipsisVertical,
          size: AppSizing.iconSm,
          color: AppColors.primary600,
        ),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
