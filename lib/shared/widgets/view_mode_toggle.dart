import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';

/// How a collection screen lays its records out.
enum CollectionViewMode { grid, list }

/// Cards or rows, as a two-button segmented control — shared by the inventory
/// and the staff roster so the switch looks and sits the same on both.
class ViewModeToggle extends StatelessWidget {
  const ViewModeToggle({
    required this.mode,
    required this.onSelected,
    super.key,
  });

  final CollectionViewMode mode;
  final ValueChanged<CollectionViewMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      height: AppSizing.minTapTarget,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ViewModeButton(
            icon: LucideIcons.layoutGrid,
            label: l10n.viewModeGrid,
            selected: mode == CollectionViewMode.grid,
            onTap: () => onSelected(CollectionViewMode.grid),
          ),
          _ViewModeButton(
            icon: LucideIcons.list,
            label: l10n.viewModeList,
            selected: mode == CollectionViewMode.list,
            onTap: () => onSelected(CollectionViewMode.list),
          ),
        ],
      ),
    );
  }
}

class _ViewModeButton extends StatelessWidget {
  const _ViewModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.pillAll,
          child: AnimatedContainer(
            duration: AppMotion.duration(context, AppMotion.fast),
            curve: AppMotion.standard,
            // Square at the tap-target floor, even though the icon inside is
            // small: this is a control for a wet finger on a tablet.
            width: AppSizing.minTapTarget,
            height: AppSizing.minTapTarget,
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryContainer : Colors.transparent,
              borderRadius: AppRadius.pillAll,
            ),
            child: Icon(
              icon,
              size: AppSizing.iconMd,
              color: selected
                  ? AppColors.onPrimaryContainer
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
