import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// How much of an article's threshold is covered, as one bar.
///
/// Three facts sit on the same line: what is physically on the shelf, what is
/// already on its way, and the threshold both are measured against. Spelled out
/// they take three sentences and a reader who holds all three in their head;
/// drawn, "low but handled" and "low and nobody has acted" stop looking alike.
///
/// The solid segment is the stock in hand, the pale one behind it what is on
/// order. Both are proportions of the threshold, and the bar fills at the
/// threshold rather than at the maximum stock — the question this screen asks
/// is "are we back above the line", not "is the shelf full".
///
/// Colour is never the only signal: the row carries a `StockStatusBadge` and
/// the figures in words. This is the third telling, for the glance.
class CoverageBar extends StatelessWidget {
  const CoverageBar({
    required this.quantity,
    required this.onOrder,
    required this.threshold,
    required this.color,
    super.key,
  });

  /// What is on the shelf. Can be negative — an unrecorded delivery — which
  /// draws as empty rather than as a bar running backwards.
  final double quantity;

  /// What is on its way across every open commande.
  final double onOrder;

  /// The figure both are measured against.
  final double threshold;

  /// The status colour of the article, from `StockStatusBadge.colorsFor`.
  final Color color;

  static const double _height = 6;

  @override
  Widget build(BuildContext context) {
    // A threshold of zero means the article has no line to be under, so there
    // is nothing to draw a proportion of.
    if (threshold <= 0) return const SizedBox.shrink();

    final held = (quantity / threshold).clamp(0.0, 1.0);
    // Stacked on top of what is held, and together capped at full: a delivery
    // that overshoots the threshold fills the bar rather than overflowing it.
    final covered = ((quantity + onOrder) / threshold).clamp(0.0, 1.0);

    return Semantics(
      // The bar is decoration to a screen reader; the row's own text already
      // carries the numbers, and a second reading of them would be noise.
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: AppRadius.pillAll,
        child: SizedBox(
          height: _height,
          child: Stack(
            children: [
              const Positioned.fill(
                child: ColoredBox(color: AppColors.surfaceVariant),
              ),
              if (covered > 0)
                FractionallySizedBox(
                  widthFactor: covered,
                  child: ColoredBox(color: color.withValues(alpha: 0.32)),
                ),
              if (held > 0)
                FractionallySizedBox(
                  widthFactor: held,
                  child: ColoredBox(color: color),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
