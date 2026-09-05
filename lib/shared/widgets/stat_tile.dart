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

/// A row of [StatTile]s that drops to fewer columns as the available width
/// narrows, rather than squeezing every tile down to nothing — a `StatTile`
/// carries a fixed 40dp icon plus its spacing, which overflows once a tile is
/// squashed much below ~200dp. Used above the employees roster, the pointage
/// history and the payroll history, so the same width reads as the same
/// column count on all three.
class StatTileRow extends StatelessWidget {
  const StatTileRow({required this.tiles, super.key});

  final List<StatTile> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 480
            ? 1
            : constraints.maxWidth < 800
            ? 2
            : tiles.length;
        final spacing = AppSpacing.lg * (columns - 1);
        final tileWidth = (constraints.maxWidth - spacing) / columns;
        return Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.lg,
          children: [
            for (final tile in tiles) SizedBox(width: tileWidth, child: tile),
          ],
        );
      },
    );
  }
}
