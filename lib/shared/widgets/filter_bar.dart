import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// The two small pieces every compact filter bar in the app is built from — the
/// Historique de pointage and the Historique de paiement share them so the two
/// pages read as one design instead of two takes on the same idea.
///
/// The bar itself is a plain `Wrap` at the call site: each control wrapped in a
/// [LabeledField], an optional [FilterResetButton] at the end, and a row of
/// [RemovableFilterChip]s beneath it for whatever is currently applied.

/// A form control with its label stacked above it — the layout every filter and
/// every form field in the app uses.
class LabeledField extends StatelessWidget {
  const LabeledField({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: AppSpacing.sm),
      child,
    ],
  );
}

/// The "Réinitialiser" affordance at the end of a filter bar. Sits on the
/// baseline of the row of fields, so it is padded to line up with their inputs
/// rather than their labels.
class FilterResetButton extends StatelessWidget {
  const FilterResetButton({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(LucideIcons.rotateCcw, size: AppSizing.iconSm),
      label: Text(label),
    ),
  );
}

/// One applied filter, shown beneath the bar with an ✕ that clears just that
/// one. Teal-tinted, matching the app's other selected-state chips.
class RemovableFilterChip extends StatelessWidget {
  const RemovableFilterChip({
    required this.label,
    required this.onRemove,
    super.key,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label),
      onDeleted: onRemove,
      deleteIcon: const Icon(LucideIcons.x, size: AppSizing.iconSm),
      backgroundColor: AppColors.primaryContainer,
      labelStyle: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(color: AppColors.onPrimaryContainer),
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.pillAll,
        side: BorderSide(color: AppColors.primary600),
      ),
      side: BorderSide.none,
    );
  }
}
