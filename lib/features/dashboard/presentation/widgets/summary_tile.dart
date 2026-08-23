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
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? caption;

  /// Tints the tile. Used for the low-stock count, which should read as a
  /// call to action rather than a neutral statistic.
  final StockStatusColors? accent;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = accent?.foreground ?? AppColors.textPrimary;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent?.container ?? AppColors.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: AppSizing.iconMd,
                  color: accent?.foreground ?? AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onTap != null)
                const Icon(
                  LucideIcons.chevronRight,
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
            // Flexible with a single line: these tiles sit in fixed-height
            // grid cells, and a two-line French caption overflows the cell on
            // a 1024dp tablet. The caption is supporting detail — losing its
            // tail is far better than a yellow overflow bar across the number.
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

/// A large quick-action button for the dashboard.
///
/// Deliberately oversized. These are the four things staff do most, and they
/// should be hittable without aiming — the brief's "wet hands, moving fast"
/// case is exactly this.
class QuickActionButton extends StatelessWidget {
  const QuickActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.emphasised = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  /// The single most common action. Only one per screen.
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: emphasised ? AppColors.primary600 : AppColors.surface,
      borderRadius: AppRadius.lgAll,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.lgAll,
        child: Container(
          height: 116,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgAll,
            border: Border.all(
              color: emphasised ? AppColors.primary600 : AppColors.border,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 28,
                color: emphasised ? AppColors.white : AppColors.primary600,
              ),
              const Spacer(),
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: emphasised ? AppColors.white : AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
