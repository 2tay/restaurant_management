import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// How the staff roster lays its records out.
enum CollectionViewMode { grid, list }

/// One way of showing a list: its icon, and the name read out and shown on
/// hover.
@immutable
class ViewModeOption<T> {
  const ViewModeOption({
    required this.value,
    required this.icon,
    required this.label,
  });

  final T value;
  final IconData icon;
  final String label;
}

/// Cards, list or table — a segmented control of icon buttons, the chosen one
/// tinted.
///
/// Shared by the product page (grille / tableau), the movement history
/// (liste / tableau) and the staff roster (grille / liste), so the control
/// that switches a view looks and sits the same wherever there is one.
class ViewModeToggle<T> extends StatelessWidget {
  const ViewModeToggle({
    required this.value,
    required this.options,
    required this.onSelected,
    super.key,
  });

  final T value;
  final List<ViewModeOption<T>> options;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizing.toolbarControlHeight,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.smAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            _ViewModeButton(
              icon: option.icon,
              label: option.label,
              selected: option.value == value,
              onTap: () => onSelected(option.value),
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
          borderRadius: AppRadius.smAll,
          child: AnimatedContainer(
            duration: AppMotion.duration(context, AppMotion.fast),
            curve: AppMotion.standard,
            // Square at the toolbar height: a full-size hit area for a small
            // icon.
            width: AppSizing.toolbarControlHeight,
            height: AppSizing.toolbarControlHeight,
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryContainer : Colors.transparent,
              borderRadius: AppRadius.smAll,
            ),
            child: Icon(
              icon,
              size: AppSizing.iconSm,
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
