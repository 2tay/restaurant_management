import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/widgets.dart';

/// A headline figure on the dashboard.
///
/// One number, large, with a label above and a caption below. The number is the
/// point — everything else is sized so it does not compete.
class SummaryTile extends StatelessWidget {
  const SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    this.caption,
    this.accent,
    this.iconColors,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? caption;

  /// Tints the figure and its icon. Used for the low-stock count, which should
  /// read as a call to action rather than a neutral statistic — and only when
  /// there is something to act on.
  final StockStatusColors? accent;

  /// The icon badge's colours when [accent] is not set, so each figure in a
  /// row is recognisable by its badge alone. Neutral grey when null.
  final StockStatusColors? iconColors;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = accent?.foreground ?? AppColors.textPrimary;
    final badge = accent ?? iconColors;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: badge?.container ?? AppColors.surfaceVariant,
                  borderRadius: AppRadius.mdAll,
                ),
                child: Icon(
                  icon,
                  size: AppSizing.iconSm,
                  color: badge?.foreground ?? AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onTap != null)
                const Icon(
                  LucideIcons.arrowUpRight,
                  size: AppSizing.iconSm,
                  color: AppColors.textDisabled,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTypography.numericLarge.copyWith(color: foreground),
              maxLines: 1,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: AppSpacing.xs),
            // One line: a two-line French caption would make this card taller
            // than its neighbours, and the row is drawn to the tallest. The
            // caption is supporting detail — losing its tail is the right
            // trade.
            // Flexible as well: the reports put these tiles in fixed-height
            // grid cells, where the caption is what gives way.
            Flexible(
              child: Text(
                caption!,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A quick action on the dashboard, in its movement's colour.
///
/// Compact enough that all four share one row even on a phone: there the icon
/// sits over a short label, like an app shortcut; with room, the icon sits
/// beside the full label. [emphasised] fills it — the one most common action.
class QuickActionButton extends StatelessWidget {
  const QuickActionButton({
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.colors,
    required this.onPressed,
    this.emphasised = false,
    this.compact = false,
    super.key,
  });

  final String label;
  final String shortLabel;

  /// Icon over the short label, for a row too narrow for the full one. Set
  /// by the caller rather than measured here: the row sizes every button to
  /// the tallest, which needs intrinsic heights a `LayoutBuilder` cannot give.
  final bool compact;
  final IconData icon;
  final StockStatusColors colors;
  final VoidCallback onPressed;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = emphasised ? colors.solid : AppColors.surface;
    final foreground = emphasised ? AppColors.white : AppColors.textPrimary;

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: background,
        borderRadius: AppRadius.lgAll,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.lgAll,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: AppRadius.lgAll,
              border: Border.all(
                color: emphasised ? colors.solid : AppColors.border,
              ),
            ),
            child: Builder(
              builder: (context) {
                final badge = Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: emphasised
                        ? AppColors.white.withValues(alpha: 0.18)
                        : colors.container,
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Icon(
                    icon,
                    size: AppSizing.iconMd,
                    color: emphasised ? AppColors.white : colors.foreground,
                  ),
                );

                // Narrow: icon over the short label.
                if (compact) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      badge,
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        shortLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    badge,
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: foreground,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
