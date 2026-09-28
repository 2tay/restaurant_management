import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';

/// How full a product is against the range it declares.
///
/// The track runs **zero to the maximum**, so a half-full shelf and a full one
/// look different — which is the reason both bounds are required. The fill is
/// **red under the minimum, amber up to the maximum, green at or above it**: a
/// traffic light against the product's own range.
///
/// That is deliberately not `stockStatusOf`, which keys red to *zero*. By that
/// rule an article a gram above empty and one a gram under its minimum are both
/// merely "low", and a full shelf and a nearly empty one are both "in stock".
/// Against a declared range the question is how full, and three colours answer
/// it.
///
/// **Built on [LinearProgressIndicator], and that matters.** Two earlier
/// versions drew the fill with `FractionallySizedBox` inside a `Stack` so a
/// notch could be laid over the bar. A `Stack` hands its non-positioned
/// children loose constraints, a fraction of an unbounded width is nothing, and
/// the bar rendered as an empty track on every screen — a blank gauge that read
/// as a broken colour rule rather than a broken layout. A progress indicator
/// takes the width it is given and cannot collapse that way.
///
/// There is no marker for the minimum and none for stock on order. The colour
/// change *is* the minimum, and every caller already states what is on its way
/// in words beside the bar. Both were segments layered over the track, which is
/// precisely what could not be drawn reliably.
class StockGauge extends StatelessWidget {
  const StockGauge({
    required this.quantity,
    required this.minimum,
    required this.maximum,
    this.height = 6,
    super.key,
  });

  /// What is on the shelf. Negative — an unrecorded delivery — draws as empty
  /// rather than as a bar running backwards.
  final double quantity;

  /// The floor. Below it the fill is red.
  final double minimum;

  /// The ceiling the track ends at.
  final double maximum;

  final double height;

  /// Past the ceiling the bar can only say "full", so it says so separately.
  bool get _overflowing => quantity > maximum;

  /// Red under the minimum, amber up to the maximum, green at or above it.
  StockStatusColors get _colors {
    if (quantity < minimum) return AppColors.outOfStock;
    if (quantity < maximum) return AppColors.lowStock;
    return AppColors.inStock;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // No ceiling means no range to draw a proportion of. The repository
    // normalises this away on create, so this guards a row that predates it
    // rather than a case the app still produces.
    if (maximum <= 0) return const SizedBox.shrink();

    final colors = _colors;
    final bar = ClipRRect(
      borderRadius: AppRadius.pillAll,
      child: LinearProgressIndicator(
        value: (quantity / maximum).clamp(0.0, 1.0),
        minHeight: height,
        color: colors.solid,
        backgroundColor: colors.container,
      ),
    );

    return Semantics(
      // Decoration to a screen reader: every caller states the same numbers in
      // words beside it, and a second reading of them would be noise.
      excludeSemantics: true,
      child: Row(
        children: [
          Expanded(child: bar),
          // A full bar cannot tell "exactly at the maximum" from "eight times
          // over it", and a product well past its ceiling is worth noticing —
          // it usually means the range on that product is wrong.
          if (_overflowing) ...[
            const SizedBox(width: AppSpacing.xs),
            Tooltip(
              message: l10n.stockGaugeOverMaximum,
              child: Icon(
                LucideIcons.chevronsRight,
                size: height + 6,
                color: colors.solid,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
