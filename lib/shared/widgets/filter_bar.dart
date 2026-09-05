import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';

/// The pieces every compact filter bar in the app is built from — the
/// Historique de pointage and the Historique de paiement share them so the two
/// pages read as one design instead of two takes on the same idea.
///
/// [FilterBar] is the bar itself. Under it, a row of [RemovableFilterChip]s
/// shows whatever is currently applied.

/// One control in a [FilterBar]: a label, the control, and the width it wants.
///
/// The width lives here rather than in a `SizedBox` at the call site because
/// [FilterBar] overrides it on a phone, where every field takes the full line —
/// a 260dp employee picker and two 165dp date fields do not share a 296dp
/// window, and both history pages hardcoded exactly those numbers.
class FilterField extends StatelessWidget {
  const FilterField({
    required this.label,
    required this.child,
    this.width = AppSizing.filterFieldWidth,
    super.key,
  });

  final String label;
  final Widget child;

  /// The field's width when the bar lays out as a row.
  final double width;

  /// A date field. Narrower, because a date is a known number of characters.
  static FilterField date({required String label, required Widget child}) =>
      FilterField(
        label: label,
        width: AppSizing.filterDateWidth,
        child: child,
      );

  /// Sizes itself to its content — for a [FilterMenu], which is a button.
  static FilterField auto({required String label, required Widget child}) =>
      FilterField(label: label, width: double.nan, child: child);

  @override
  Widget build(BuildContext context) => LabeledField(label: label, child: child);
}

/// A row of filter controls with an optional reset at the end.
///
/// Wraps onto as many lines as it needs on a tablet, and becomes a column of
/// full-width fields on a phone.
class FilterBar extends StatelessWidget {
  const FilterBar({required this.fields, this.reset, super.key});

  final List<FilterField> fields;

  /// Usually a [FilterResetButton]. Null when there is nothing to reset.
  final Widget? reset;

  @override
  Widget build(BuildContext context) {
    if (context.isPhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final field in fields) ...[
            field,
            const SizedBox(height: AppSpacing.md),
          ],
          if (reset != null)
            Align(alignment: Alignment.centerLeft, child: reset!),
        ],
      );
    }

    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        for (final field in fields)
          field.width.isNaN
              ? field
              : SizedBox(width: field.width, child: field),
        ?reset,
      ],
    );
  }
}

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
