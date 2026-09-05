import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import 'filter_pill.dart';
import 'primary_button.dart';

/// The filters of a list screen, moved off the screen and behind a button.
///
/// A list screen's controls — search, two or three filters, a result count, a
/// sort, a view toggle — come to about 1500dp of natural width. A tablet has
/// room to lay that out in a line or two. A 360dp phone has 328, so they stack
/// into six rows and 341dp of chrome above a 320dp card: the screen showed two
/// thirds of one product.
///
/// So on a phone they collapse to one button. This does contradict the rule the
/// inventory page was built on — *a hidden filter is a filter nobody uses* —
/// and that rule is right at the width it was written for. At 360dp the trade
/// is not hidden filters against visible ones, it is filters against any
/// visible products at all. The button carries the number of applied filters so
/// the state is never hidden, only the controls.
abstract final class FilterSheet {
  /// Opens [builder]'s controls in a sheet from the bottom of the screen.
  ///
  /// The controls inside are the same widgets the wide layout puts in its bar,
  /// so there is one definition of what a filter looks like. They drive the
  /// same providers, which is what lets the sheet stay open while the list
  /// behind it updates — the count on the button is live.
  static Future<void> show(
    BuildContext context, {
    required WidgetBuilder builder,
    VoidCallback? onClear,
  }) {
    final l10n = AppLocalizations.of(context);

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.filtersTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (onClear != null)
                    TextButton(
                      onPressed: () {
                        onClear();
                        Navigator.of(context).pop();
                      },
                      child: Text(l10n.filtersClearAll),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Scrollable: a store with long category names, on a phone with
              // the type turned up, is taller than the half screen a sheet
              // gets.
              Flexible(
                child: SingleChildScrollView(child: builder(context)),
              ),

              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: l10n.filtersDone,
                fullWidth: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The button that opens a [FilterSheet].
///
/// Shaped like the filter pills it stands in for, and it names how many
/// filters are applied — the controls are hidden on a narrow screen, the state
/// never is.
class FilterSheetButton extends StatelessWidget {
  const FilterSheetButton({
    required this.activeCount,
    required this.onPressed,
    super.key,
  });

  /// How many filters are currently applied. Zero draws the resting pill.
  final int activeCount;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final active = activeCount > 0;

    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.pillAll,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.pillAll,
        child: FilterPill(
          label: l10n.filtersTitle,
          selectedLabel: active
              ? l10n.filtersTitleWithCount(activeCount)
              : null,
          icon: LucideIcons.slidersHorizontal,
        ),
      ),
    );
  }
}
