import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// A bordered surface.
///
/// Borders rather than shadows: this is a dense data tool, and a screen of
/// floating shadowed cards reads as decoration. The border does the same
/// grouping job and stays legible under bright kitchen lighting where soft
/// shadows disappear.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding,
    this.selected = false,
    this.accentColor,
    super.key,
  });

  final Widget child;

  /// Makes the whole card tappable, with a ripple.
  final VoidCallback? onTap;

  final EdgeInsetsGeometry? padding;

  /// Highlights the card in a master–detail list.
  final bool selected;

  /// Draws a thick left edge — used to carry stock status onto a card without
  /// relying on the border colour alone.
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding ?? AppSpacing.cardInsets,
      child: child,
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: selected ? AppColors.primary600 : AppColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          // The accent stripe is a positioned child rather than a Row sibling
          // or a thicker left border. A Row would need
          // CrossAxisAlignment.stretch, which demands a bounded height, and
          // these cards live in ListViews where height is unbounded. A
          // non-uniform Border cannot be painted with a borderRadius at all.
          // Stack sizes itself to the content and lets the stripe fill.
          child: accentColor == null
              ? content
              : Stack(
                  children: [
                    content,
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 5,
                      child: ColoredBox(color: accentColor!),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
