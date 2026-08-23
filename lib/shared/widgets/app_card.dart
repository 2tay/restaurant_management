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
          child: accentColor == null
              ? content
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 5, color: accentColor),
                    Expanded(child: content),
                  ],
                ),
        ),
      ),
    );
  }
}
