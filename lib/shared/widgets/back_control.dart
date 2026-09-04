import 'package:flutter/material.dart';

import '../../app/navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The back control that sits top-left on every pushed screen.
///
/// Deliberately a labelled button rather than a bare arrow icon. A 24dp chevron
/// is a fine target for a thumb on a phone held in one hand; it is a poor one
/// for someone reaching across a counter, and it says nothing about where back
/// leads. Naming the destination removes the guess.
///
/// Falls back to a bare arrow only when the destination name is long enough to
/// crowd the header.
class BackControl extends StatelessWidget {
  const BackControl({required this.destination, this.onBack, super.key});

  final BackDestination destination;

  /// Overrides the default pop — used by forms that must confirm before
  /// discarding input.
  final Future<void> Function()? onBack;

  /// Beyond this, the label is dropped and only the arrow shows.
  static const int _maxLabelLength = 22;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final showLabel = destination.label.length <= _maxLabelLength;
    final label = showLabel ? l10n.backTo(destination.label) : l10n.backGeneric;

    return Semantics(
      button: true,
      label: l10n.backTo(destination.label),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.pillAll,
        child: InkWell(
          onTap: () => _handleBack(context),
          borderRadius: AppRadius.pillAll,
          child: Container(
            // A minimum, not a fixed height: 48dp is the tap-target floor the
            // brief sets, and a control pinned to it clips its own label once
            // the user turns the type up.
            constraints: const BoxConstraints(
              minHeight: AppSizing.minTapTarget,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.arrowLeft,
                  size: AppSizing.iconMd,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleBack(BuildContext context) async {
    if (onBack != null) {
      await onBack!();
      return;
    }
    context.backTo(destination.path);
  }
}
