import 'dart:math' as math;

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
    this.caption,
    this.onTap,
    this.selected = false,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;

  /// A short muted line under the label — what the count is measured against
  /// (« Stock sous le minimum »), for a row of tiles that reads as a summary.
  final String? caption;

  /// Makes the tile a way in: the alerts summary filters the list on tap.
  final VoidCallback? onTap;

  /// Outlined in the tile's own colour — the filter the tile stands for is on.
  final bool selected;

  /// Tints the tile — use for a count that should read as something to act on
  /// (late breaks, unpaid periods) rather than a neutral statistic.
  final StockStatusColors? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = accent?.foreground ?? AppColors.textPrimary;

    return AppCard(
      bordered: selected,
      borderColor: selected ? (accent?.solid ?? AppColors.primary600) : null,
      onTap: onTap,
      // The icon always stays; a narrow tile shrinks its figure instead.
      child: _content(
        theme,
        foreground,
        // A smaller label on a phone, where two tiles share the line.
        phone: MediaQuery.sizeOf(context).width < AppBreakpoints.compact,
      ),
    );
  }

  Widget _content(ThemeData theme, Color foreground, {required bool phone}) {
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
                  fontSize: phone ? 11 : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // Dropped on a phone, where two tiles share the line and the
              // caption would only ever show as « Stock sous … ».
              if (caption != null && !phone)
                Text(
                  caption!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    // neutral500, not textDisabled: still 4.5:1 on white.
                    color: AppColors.neutral500,
                    fontWeight: FontWeight.w400,
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
/// On a phone or a small tablet (screen narrower than [AppBreakpoints.medium])
/// the tiles go two per line. Anywhere wider they share one line as long as
/// each keeps [minTileWidth]; past that — a 900dp window less the rail — they
/// spread over balanced lines (five: three, then two) rather than cut every
/// label to « Perso… ». Each line fills the width, so an odd last tile takes
/// the whole line instead of leaving a hole beside it.
class StatTileRow extends StatelessWidget {
  const StatTileRow({
    required this.tiles,
    this.spacing = AppSpacing.lg,
    super.key,
  });

  final List<StatTile> tiles;

  final double spacing;

  /// The narrowest a tile goes on a wide screen: the medallion, its gap and
  /// a label such as « Embauchés ce mois » still whole.
  static const double minTileWidth = 200;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();

    final small = MediaQuery.sizeOf(context).width < AppBreakpoints.medium;

    return LayoutBuilder(
      builder: (context, constraints) {
        final fit =
            ((constraints.maxWidth + spacing) / (minTileWidth + spacing))
                .floor()
                .clamp(1, tiles.length);
        final columns = small ? math.min(2, tiles.length) : fit;

        // As many lines as [columns] needs, the tiles shared out evenly — the
        // longer lines first.
        final lines = (tiles.length / columns).ceil();
        final base = tiles.length ~/ lines;
        final extra = tiles.length % lines;

        final rows = <Widget>[];
        var next = 0;
        for (var line = 0; line < lines; line++) {
          final count = base + (line < extra ? 1 : 0);
          if (line > 0) rows.add(SizedBox(height: spacing));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < count; i++) ...[
                    if (i > 0) SizedBox(width: spacing),
                    Expanded(child: tiles[next + i]),
                  ],
                ],
              ),
            ),
          );
          next += count;
        }
        return Column(mainAxisSize: MainAxisSize.min, children: rows);
      },
    );
  }
}
