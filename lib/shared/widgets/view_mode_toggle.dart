import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

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

/// Cards, list or table — a pill of icon buttons, the chosen one tinted.
///
/// Shared by the product page (grille / tableau) and the movement history
/// (liste / tableau), so the control that switches a view looks and behaves
/// the same wherever there is one.
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
      height: AppSizing.minTapTarget,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            _Button(
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

class _Button extends StatelessWidget {
  const _Button({
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
