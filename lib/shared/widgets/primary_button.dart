import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

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
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isBusy = false,
    this.fullWidth = false,
    this.large = false,
    super.key,
  });

  final String label;

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
          : _ButtonContent(label: label, icon: icon),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// A supporting action — "Annuler", "Voir tout", a secondary form path.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: onPressed,
      child: _ButtonContent(label: label, icon: icon),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
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
    this.icon,
    this.filled = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// False renders it outlined — for a delete that sits among other actions
  /// rather than being the point of the screen.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final content = _ButtonContent(label: label, icon: icon);

    if (!filled) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        child: content,
      );
    }

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.error,
        foregroundColor: AppColors.white,
      ),
      child: content,
    );
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (icon == null) {
      return Text(label, textAlign: TextAlign.center);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppSizing.iconMd),
        const SizedBox(width: AppSpacing.sm),
        // Flexible so a long French label ellipsizes rather than overflowing
        // when the button is width-constrained.
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
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
