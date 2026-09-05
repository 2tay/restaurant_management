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
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The icon medallion is 52dp of the tile's width including its gap.
          // Below this there is not enough left for a figure beside it, and the
          // number is the point of the tile — so the medallion goes rather than
          // the digits. [StatTileRow] normally guarantees enough width; this is
          // for a caller that puts a tile somewhere narrower.
          final showIcon = constraints.maxWidth >= 140;
          return _content(theme, foreground, showIcon: showIcon);
        },
      ),
    );
  }

  Widget _content(
    ThemeData theme,
    Color foreground, {
    required bool showIcon,
  }) {
    return Row(
      children: [
        if (showIcon) ...[
          Container(
            width: AppSizing.statTileMedallion,
            height: AppSizing.statTileMedallion,
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
        ],
        Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Scaled down rather than ellipsized. A truncated number is
                // worse than a small one — "1 2…" reads as a different figure,
                // where 11pt still reads as 1 234. Aligned left so a row of
                // tiles keeps its rhythm whatever each one shrinks to.
                Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: foreground,
                      ),
                      maxLines: 1,
                    ),
                  ),
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
    );
  }
}

/// The row of KPI tiles that sits above a list or a table.
///
/// Written three times — the employees roster, the attendance history and the
/// payroll history each had their own `_KpiRow`/`_StatRow` wrapping four
/// `Expanded` tiles in a `Row`. That is correct at the design baseline and
/// splits four ways at 360dp, giving each tile 63dp: enough for the icon
/// medallion and nothing else, which is exactly how all three pages overflowed
/// on a phone.
///
/// Here the tiles get a minimum width and wrap onto as many lines as that
/// takes — four across on a tablet, two on a large phone, one at 360dp.
class StatTileRow extends StatelessWidget {
  const StatTileRow({
    required this.tiles,
    this.minTileWidth = 200,
    this.spacing = AppSpacing.lg,
    super.key,
  });

  final List<StatTile> tiles;

  /// The narrowest a tile may be squeezed to before the row uses fewer columns.
  /// 200dp fits the medallion plus a five-digit figure and a French label.
  final double minTileWidth;

  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        // How many minimum-width tiles fit, counting the gaps between them.
        final fits = ((available + spacing) / (minTileWidth + spacing)).floor();
        final columns = fits.clamp(1, tiles.length);
        final tileWidth =
            (available - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles)
              SizedBox(width: tileWidth, child: tile),
          ],
        );
      },
    );
  }
}
