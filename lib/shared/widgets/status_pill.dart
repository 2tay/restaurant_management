import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// A tinted pill: icon, label, rounded container.
///
/// The shape every status indicator in the app is made of. It was written eight
/// separate times — four `*StatusBadge` widgets here plus `_Pill`, `_Tag` and
/// `_Flag` inside three feature files — each rebuilding the same
/// `AppRadius.pillAll` container with slightly different padding, and each one
/// a place the two rules below could quietly stop being true.
///
/// The rules, enforced structurally rather than by convention:
///
/// 1. **Colour is never alone.** [icon] and [label] are both required. The
///    app's core signal is red/amber/green and roughly 1 in 12 men has a colour
///    vision deficiency, so a colour-only pill is unreadable to a chunk of any
///    kitchen brigade. [compact] moves the label to a tooltip rather than
///    dropping it.
/// 2. **The label is read once.** The icon is decorative — a screen reader that
///    announced both would say "warning, stock faible" on every row.
///
/// What each *status* means stays with its own badge widget; this only knows
/// how to draw one.
class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.colors,
    required this.icon,
    required this.label,
    this.compact = false,
    this.outlined = false,
    super.key,
  });

  /// Container and foreground tints. Comes from the badge's own `colorsFor`.
  final StockStatusColors colors;

  final IconData icon;
  final String label;

  /// Icon only, with the label moved to a tooltip. For dense table rows where
  /// the surrounding column already says what the number means.
  ///
  /// Use sparingly — the label is what makes this readable at a glance.
  final bool compact;

  /// Drawn as an outline on the page ground rather than a filled tint. For a
  /// pill that sits on a coloured surface, where the container tint would
  /// disappear into it.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Tooltip(
        message: label,
        child: Container(
          width: AppSizing.iconLg,
          height: AppSizing.iconLg,
          decoration: BoxDecoration(
            color: outlined ? null : colors.container,
            border: outlined ? Border.all(color: colors.foreground) : null,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: AppSizing.iconSm, color: colors.foreground),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: outlined ? null : colors.container,
        border: outlined ? Border.all(color: colors.foreground) : null,
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Excluded from semantics: the label beside it already says this, and
          // a screen reader should not read the status twice.
          ExcludeSemantics(
            child: Icon(icon, size: AppSizing.iconSm, color: colors.foreground),
          ),
          const SizedBox(width: AppSpacing.xs),
          // Flexible so a long French status ellipsizes inside a narrow table
          // column rather than overflowing the row it sits in. `mainAxisSize`
          // is still min, so a pill with room stays exactly as wide as its
          // content.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: colors.foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// A pill that names something rather than reporting a status.
///
/// The role badge, the contract type, "Nouveau", "Retiré". These are labels,
/// not signals — there is no state to misread if the colour is not perceived,
/// so unlike [StatusPill] they carry no mandatory icon. Same geometry, so the
/// two read as one family on a screen that shows both.
///
/// Absorbs `_Pill` from the store card, `_ContractChip` and `_ArchivedPill`
/// from the roster, which were three copies of this container.
class LabelChip extends StatelessWidget {
  const LabelChip({
    required this.label,
    this.background,
    this.foreground,
    this.icon,
    this.dense = false,
    super.key,
  });

  final String label;

  /// Defaults to the neutral surface. Tint only when the label is worth
  /// picking out of a row of them.
  final Color? background;
  final Color? foreground;

  final IconData? icon;

  /// Tighter padding and a smaller type size, for a chip inside a card that is
  /// already dense.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = foreground ?? AppColors.textSecondary;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.sm : AppSpacing.md,
        vertical: dense ? AppSpacing.xs : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background ?? AppColors.surfaceVariant,
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            ExcludeSemantics(
              child: Icon(icon, size: AppSizing.iconSm, color: fg),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (dense ? theme.textTheme.labelSmall : theme.textTheme.labelMedium)
                  ?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}
