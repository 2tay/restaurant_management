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
      bordered: false,
      // The icon always stays; a narrow tile shrinks its figure instead.
      child: _content(theme, foreground),
    );
  }

  Widget _content(ThemeData theme, Color foreground) {
    return Row(
      children: [
        Container(
          width: AppSizing.statTileMedallion,
          height: AppSizing.statTileMedallion,
          decoration: BoxDecoration(
            // A translucent wash of the brand green, not a flat tint — it
            // sits lighter on the white card.
            color:
                accent?.container ??
                AppColors.primary600.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: AppSizing.iconMd,
            color: accent?.foreground ?? AppColors.primary600,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
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
/// payroll history each had their own `_KpiRow`/`_StatRow` wrapping the tiles
/// in a `Row`. They share this one now.
///
/// On a phone (screen narrower than [AppBreakpoints.compact]) the tiles go
/// two per line; an odd last tile takes the whole line rather than leaving a
/// hole beside it. From a small tablet up, they all share a single line.
class StatTileRow extends StatelessWidget {
  const StatTileRow({
    required this.tiles,
    this.spacing = AppSpacing.lg,
    super.key,
  });

  final List<StatTile> tiles;

  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();

    final phone = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final columns = phone && tiles.length > 2 ? 2 : tiles.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final tileWidth =
            (available - spacing * (columns - 1)) / columns;
        // An odd tile alone on the last line stretches across it.
        final lonelyLast = tiles.length % columns == 1 && columns > 1;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var i = 0; i < tiles.length; i++)
              SizedBox(
                width: lonelyLast && i == tiles.length - 1
                    ? available
                    : tileWidth,
                child: tiles[i],
              ),
          ],
        );
      },
    );
  }
}
