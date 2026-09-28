import 'package:flutter/material.dart';

import '../../app/navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The back control that sits left of the title on every pushed screen.
///
/// An arrow, not a labelled button. The label — "Retour à Inventaire" — took a
/// row of its own above the breadcrumbs, which already name where back leads,
/// so the header spent 48dp repeating itself before the title. The destination
/// still reaches the user: as a tooltip on hover and long-press, and as the
/// screen-reader label.
///
/// The tap target stays the full 48dp square. Someone reaching across a counter
/// needs the area, not the words.
class BackControl extends StatelessWidget {
  const BackControl({required this.destination, this.onBack, super.key});

  final BackDestination destination;

  /// Overrides the default pop — used by forms that must confirm before
  /// discarding input.
  final Future<void> Function()? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Named after the screen back actually pops to. The destination's own
    // label is for when there is nothing to pop and back lands on the parent.
    final route = ModalRoute.of(context);
    final previous = route == null ? null : BackHistory.previousTitle(route);
    final label = l10n.backTo(previous ?? destination.label);

    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.pillAll,
          child: InkWell(
            onTap: () => _handleBack(context),
            borderRadius: AppRadius.pillAll,
            child: const SizedBox.square(
              dimension: AppSizing.minTapTarget,
              child: Icon(
                LucideIcons.arrowLeft,
                size: AppSizing.iconMd,
                color: AppColors.textSecondary,
              ),
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
