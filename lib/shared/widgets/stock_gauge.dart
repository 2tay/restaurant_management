import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Where a product's stock sits in the range it declares, as one bar.
///
/// The track spans **zero to the maximum**, the fill is what is on the shelf,
/// a paler segment behind it is what is already on its way, and a notch marks
/// the minimum. Four facts that take four sentences to write down, in a shape
/// that answers all of them at a glance: how full, how far from the floor, and
/// whether anyone has acted.
///
/// It used to fill at the *minimum*, because that was the only bound a product
/// was guaranteed to have — which made a product at 8 of a possible 20 look
/// complete. Both bounds are required now, so the bar can show the real
/// proportion, and the notch is what keeps "am I under the line" readable,
/// which is the question the alerts screen asks.
///
/// The fill is **red under the minimum, amber between the bounds, and green at
/// the maximum** — a traffic light against the range the product declares, and
/// the one thing on the bar that is colour rather than geometry.
///
/// That is deliberately not `stockStatusOf`, which keys red to *zero*: by that
/// rule an article one gram above nothing and an article one gram under its
/// minimum are both merely "low", and a full shelf and a nearly empty one are
/// both "in stock". Against a declared range the question is how full, and the
/// three colours answer it.
///
/// The gauge works the colour out itself rather than taking one, so the four
/// places that draw it cannot drift apart — which is exactly what had already
/// happened between the alerts rows, the catalogue table and the dashboard.
class StockGauge extends StatelessWidget {
  const StockGauge({
    required this.quantity,
    required this.minimum,
    required this.maximum,
    this.onOrder = 0,
    this.height = 6,
    super.key,
  });

  /// What is on the shelf. Can be negative — an unrecorded delivery — which
  /// draws as empty rather than as a bar running backwards.
  final double quantity;

  /// The floor the notch marks.
  final double minimum;

  /// The ceiling the track ends at.
  final double maximum;

  /// What is on its way across every open commande.
  final double onOrder;

  final double height;

  /// Red under the minimum, amber up to the maximum, green at or above it.
  StockStatusColors get _colors {
    if (quantity < minimum) return AppColors.outOfStock;
    if (quantity < maximum) return AppColors.lowStock;
    return AppColors.inStock;
  }

  @override
  Widget build(BuildContext context) {
    // A product with no ceiling has no range to draw a proportion of. The
    // repository normalises this away on create, so this is the guard for a
    // row that predates it rather than a case the app produces.
    if (maximum <= 0) return const SizedBox.shrink();

    final colors = _colors;
    final held = (quantity / maximum).clamp(0.0, 1.0);
    // Stacked on top of what is held and capped together at full, so a
    // delivery that overshoots fills the bar rather than overflowing it.
    final covered = ((quantity + onOrder) / maximum).clamp(0.0, 1.0);
    final notch = (minimum / maximum).clamp(0.0, 1.0);

    return Semantics(
      // Decoration to a screen reader: every caller states the same numbers in
      // words beside it, and a second reading of them would be noise.
      excludeSemantics: true,
      child: SizedBox(
        // Room for the notch to overshoot the track at both ends, which is
        // what makes it read as a mark on the bar rather than a gap in it.
        height: height + 6,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: AppRadius.pillAll,
              child: SizedBox(
                height: height,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: AppColors.surfaceVariant),
                    ),
                    if (covered > 0)
                      FractionallySizedBox(
                        widthFactor: covered,
                        child: ColoredBox(color: colors.solid.withValues(alpha: 0.32)),
                      ),
                    if (held > 0)
                      FractionallySizedBox(
                        widthFactor: held,
                        child: ColoredBox(color: colors.solid),
                      ),
                  ],
                ),
              ),
            ),
            // Positioned by alignment rather than by a LayoutBuilder: the bar
            // is often inside a table cell whose width is decided a frame
            // later, and an Align needs no measurement of its own.
            Align(
              alignment: Alignment(notch * 2 - 1, 0),
              child: Container(
                width: 2,
                height: height + 6,
                decoration: BoxDecoration(
                  // Near-black, so the mark is findable over the empty track
                  // and over the fill alike, whatever the status colour is.
                  color: AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
