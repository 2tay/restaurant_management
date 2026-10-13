import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/navigation.dart';
import '../../app/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/current_employee.dart';
import '../../l10n/app_localizations.dart';

/// The user menu: Mes établissements, Paramètres, Se déconnecter — a white
/// panel [width] wide at [position], with a real drop shadow.
///
/// Opened from the sidebar's profile row on a tablet or a desktop, and from
/// the avatar in the green top bar on a phone, where the sidebar is a drawer
/// and no longer carries the profile.
Future<void> showAccountMenu(
  BuildContext context,
  WidgetRef ref, {
  required String storeId,
  required RelativeRect position,
  double width = AppSizing.sidebarWidthExpanded - AppSpacing.xl,
}) async {
  final l10n = AppLocalizations.of(context);

  final selected = await showMenu<String>(
    context: context,
    color: AppColors.white,
    elevation: 12,
    shadowColor: AppColors.neutral950.withValues(alpha: 0.35),
    surfaceTintColor: Colors.transparent,
    constraints: BoxConstraints.tightFor(width: width),
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
    position: position,
    items: [
      PopupMenuItem<String>(
        value: 'stores',
        padding: EdgeInsets.zero,
        child: _MenuRow(icon: LucideIcons.building2, label: l10n.sidebarMyStores),
      ),
      PopupMenuItem<String>(
        value: 'settings',
        padding: EdgeInsets.zero,
        child: _MenuRow(icon: LucideIcons.settings, label: l10n.navSettings),
      ),
      const PopupMenuDivider(color: AppColors.border),
      PopupMenuItem<String>(
        value: 'logout',
        padding: EdgeInsets.zero,
        child: _MenuRow(
          icon: LucideIcons.logOut,
          label: l10n.actionLogout,
          destructive: true,
        ),
      ),
    ],
  );

  if (selected == null || !context.mounted) return;
  switch (selected) {
    case 'stores':
      context.goSection(Routes.stores);
    case 'settings':
      context.goSection(Routes.toStoreSettings(storeId));
    case 'logout':
      await ref.read(currentEmployeeProvider.notifier).signOut();
      if (context.mounted) context.goSection(Routes.login);
  }
}

/// The active navigation entry's pale-green fill, for a hovered menu row.
final Color _menuHoverFill = AppColors.primary600.withValues(alpha: 0.08);

/// One row of the user menu, on white. On hover it takes the active
/// navigation entry's pale-green fill and green text; [destructive] keeps
/// "Se déconnecter" red, over a pale-red fill on hover.
class _MenuRow extends StatefulWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color foreground;
    final Color iconColor;
    final Color fill;
    if (widget.destructive) {
      foreground = iconColor = AppColors.error;
      fill = _hovered
          ? AppColors.error.withValues(alpha: 0.08)
          : Colors.transparent;
    } else if (_hovered) {
      foreground = iconColor = AppColors.primary600;
      fill = _menuHoverFill;
    } else {
      foreground = AppColors.textPrimary;
      iconColor = AppColors.textSecondary;
      fill = Colors.transparent;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSizing.minTapTarget),
        alignment: Alignment.centerLeft,
        color: fill,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          children: [
            Icon(widget.icon, size: AppSizing.iconMd, color: iconColor),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
