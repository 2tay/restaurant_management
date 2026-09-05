import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'action_density.dart';

/// The one obvious thing to do on a screen.
///
/// There should be at most one of these visible at a time. The teal is reserved
/// for it precisely so that it answers "what do I tap next?" without the user
/// having to read anything — which stops working the moment a second one
/// appears.
///
/// Sizing and colour come from the theme; this exists to add the icon slot, the
/// busy state, and the full-width option without every call site rebuilding
/// them.
///
/// It shortens its label in a tight header but never collapses to an icon —
/// see [ActionDensity.iconOnly] for why.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.shortLabel,
    this.icon,
    this.isBusy = false,
    this.fullWidth = false,
    this.large = false,
    super.key,
  });

  final String label;

  /// A shorter wording for a narrow header — "Enregistrer" for "Enregistrer les
  /// modifications". Only worth setting where the full label is long; where it
  /// is null the full label is used at every density.
  final String? shortLabel;

  /// Null disables the button. Prefer disabling over hiding: a control that
  /// vanishes leaves the user hunting for it.
  final VoidCallback? onPressed;

  final IconData? icon;

  /// Shows a spinner and blocks input. Nothing in Phase 1 is slow enough to
  /// need it, but forms are wired for it so Phase 2 doesn't have to retrofit.
  final bool isBusy;

  final bool fullWidth;

  /// For the single most important action on a screen — the dashboard's
  /// quick actions, a form's submit.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton(
      onPressed: isBusy ? null : onPressed,
      style: large
          ? FilledButton.styleFrom(
              minimumSize: const Size(0, AppSizing.buttonHeightLarge),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            )
          : null,
      child: isBusy
          ? const _ButtonSpinner()
          : _ButtonContent(
              label: label,
              shortLabel: shortLabel,
              icon: icon,
              // The teal button keeps its words however tight the header gets.
              allowIconOnly: false,
            ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// A supporting action — "Annuler", "Voir tout", a secondary form path.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    this.shortLabel,
    this.icon,
    this.fullWidth = false,
    super.key,
  });

  final String label;

  /// See [PrimaryButton.shortLabel].
  final String? shortLabel;

  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return _collapsible(
      context: context,
      label: label,
      shortLabel: shortLabel,
      icon: icon,
      fullWidth: fullWidth,
      builder: (child, style) =>
          OutlinedButton(onPressed: onPressed, style: style, child: child),
    );
  }
}

/// Deletes and removals.
///
/// Red, and never the only way to trigger something destructive — every use of
/// this is expected to be behind a [ConfirmDialog]. The colour is a warning,
/// not a safety mechanism.
class DestructiveButton extends StatelessWidget {
  const DestructiveButton({
    required this.label,
    required this.onPressed,
    this.shortLabel,
    this.icon,
    this.filled = true,
    super.key,
  });

  final String label;

  /// See [PrimaryButton.shortLabel].
  final String? shortLabel;

  final VoidCallback? onPressed;
  final IconData? icon;

  /// False renders it outlined — for a delete that sits among other actions
  /// rather than being the point of the screen.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return _collapsible(
      context: context,
      label: label,
      shortLabel: shortLabel,
      icon: icon,
      fullWidth: false,
      builder: (child, style) {
        if (!filled) {
          return OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error, width: 1.5),
            ).merge(style),
            child: child,
          );
        }

        return FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: AppColors.white,
          ).merge(style),
          child: child,
        );
      },
    );
  }
}

/// Builds a supporting button that may collapse to its icon.
///
/// Shared by [SecondaryButton] and [DestructiveButton] because the collapse is
/// the same in both: a square button holding only the icon, with the label kept
/// as a tooltip for the eye and a semantics label for the screen reader. The
/// label is moved, never dropped.
Widget _collapsible({
  required BuildContext context,
  required String label,
  required String? shortLabel,
  required IconData? icon,
  required bool fullWidth,
  required Widget Function(Widget child, ButtonStyle? style) builder,
}) {
  final iconOnly =
      icon != null && ActionDensityScope.of(context) == ActionDensity.iconOnly;

  if (!iconOnly) {
    final button = builder(
      _ButtonContent(label: label, shortLabel: shortLabel, icon: icon),
      null,
    );
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }

  // MergeSemantics rather than a wrapper: the button already publishes a node
  // with the tap action on it, and merging folds the name into that node.
  // Excluding it would name the control and take away the ability to press it.
  return MergeSemantics(
    child: Semantics(
      label: label,
      child: Tooltip(
        message: label,
        child: builder(
          Icon(icon, size: AppSizing.iconMd),
          // Square. The theme's horizontal padding is sized for a label that
          // is no longer there, and 56dp is comfortably over the 48dp
          // tap-target floor.
          OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            fixedSize: const Size(
              AppSizing.buttonHeight,
              AppSizing.buttonHeight,
            ),
          ),
        ),
      ),
    ),
  );
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    this.shortLabel,
    this.icon,
    this.allowIconOnly = true,
  });

  final String label;
  final String? shortLabel;
  final IconData? icon;
  final bool allowIconOnly;

  @override
  Widget build(BuildContext context) {
    final density = ActionDensityScope.of(context);

    // `iconOnly` reaches here only when the caller refused the collapse — the
    // teal primary, or a button with no icon to collapse to. Both fall back to
    // the short label rather than to nothing.
    final text = density == ActionDensity.full
        ? label
        : (shortLabel ?? label);

    if (icon == null) {
      return Text(text, textAlign: TextAlign.center);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppSizing.iconMd),
        const SizedBox(width: AppSpacing.sm),
        // Flexible so a long French label ellipsizes rather than overflowing
        // when the button is width-constrained.
        Flexible(
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: AppColors.white,
      ),
    );
  }
}
