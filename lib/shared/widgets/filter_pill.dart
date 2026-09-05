import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// The chip-shaped trigger for a dropdown filter.
///
/// Shows the filter's name when nothing is selected and the selected value once
/// something is, so a row of these reads as a sentence describing what is
/// currently being shown. Active filters are tinted, which is what stops
/// somebody wondering why the list looks short.
///
/// Pair it with a [PopupMenuButton]; it is the `child`, not the menu.
class FilterPill extends StatelessWidget {
  const FilterPill({
    required this.label,
    required this.selectedLabel,
    this.icon,
    super.key,
  });

  /// The filter's name — "Catégorie", "Période".
  final String label;

  /// The current selection, or null when the filter is inactive.
  final String? selectedLabel;

  final IconData? icon;

  /// How much room the label takes before it ellipsizes, where there is room
  /// to spare. Supplier and item names run long, and a filter row that reflows
  /// on every selection is disorienting.
  static const double _maxLabelWidth = 200;

  @override
  Widget build(BuildContext context) {
    final active = selectedLabel != null;
    final foreground = active
        ? AppColors.onPrimaryContainer
        : AppColors.textSecondary;

    return Container(
      constraints: const BoxConstraints(minHeight: AppSizing.minTapTarget),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: active ? AppColors.primaryContainer : AppColors.surface,
        borderRadius: AppRadius.pillAll,
        border: Border.all(
          color: active ? AppColors.primary600 : AppColors.border,
        ),
      ),
      // The label is capped where there is room and *flexible* where there is
      // not. A pill sits in a Wrap on a control bar, and on a narrow one the
      // bar is thinner than the pill's natural width — where a plain
      // ConstrainedBox simply overflowed. Flexible only works against a
      // bounded width, hence the LayoutBuilder: laid out unbounded (an
      // intrinsic pass, a Row that has not been given a width) the cap alone
      // still applies.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final text = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxLabelWidth),
            child: Text(
              selectedLabel ?? label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: foreground),
            ),
          );

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppSizing.iconSm, color: foreground),
                const SizedBox(width: AppSpacing.xs),
              ],
              if (constraints.maxWidth.isFinite)
                Flexible(child: text)
              else
                text,
              const SizedBox(width: AppSpacing.xs),
              Icon(
                LucideIcons.chevronDown,
                size: AppSizing.iconSm,
                color: foreground,
              ),
            ],
          );
        },
      ),
    );
  }
}
