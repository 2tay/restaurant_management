import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'app_card.dart';

/// A compact KPI card — icon, a headline number, a label beneath it.
///
/// The horizontal, dense variant, for a row of counts above a list or a
/// table (the employees roster, the attendance history, the payroll history).
/// `SummaryTile` in `features/dashboard/` is the tall, single-figure variant
/// for the dashboard grid; this one is deliberately separate so a feature
/// does not reach sideways into the dashboard folder for it.
class StatTile extends StatelessWidget {
  const StatTile({
    required this.label,
    required this.value,
    required this.icon,
    this.accent,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;

  /// Tints the tile — use for a count that should read as something to act on
  /// (late breaks, unpaid periods) rather than a neutral statistic.
  final StockStatusColors? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = accent?.foreground ?? AppColors.textPrimary;

    return AppCard(
      child: Row(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: foreground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
