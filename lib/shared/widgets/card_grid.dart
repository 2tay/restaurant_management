import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';

/// Cards in equal columns — always one on a phone or a small tablet, then two,
/// three or four as the content width allows, each at least [minCardWidth]
/// wide.
///
/// Columns come from the width the grid actually gets, not the screen's: the
/// sidebar takes a different share at each breakpoint, so the same screen width
/// can leave very different room. The single-column rule is the exception — it
/// goes by the screen ([ResponsiveContext.isSmallScreen]): below a medium
/// screen two columns are always cramped.
///
/// Shared by the Personnel cards, the pointage board and both history pages,
/// so the same width reads as the same column count everywhere.
class ResponsiveCardGrid extends StatelessWidget {
  const ResponsiveCardGrid({
    required this.children,
    this.minCardWidth = 280,
    this.maxColumns = 4,
    this.itemHeight,
    super.key,
  });

  final List<Widget> children;
  final double minCardWidth;
  final int maxColumns;

  /// A fixed height for every card — for cards whose content is laid out
  /// against the bottom edge. Null lets each card size itself.
  final double? itemHeight;

  static const double _spacing = AppSpacing.lg;

  @override
  Widget build(BuildContext context) {
    final single = context.isSmallScreen;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = single
            ? 1
            : cardGridColumns(
                width,
                minCardWidth: minCardWidth,
                singleColumnBelow: 0,
                maxColumns: maxColumns,
              );
        final cardWidth = (width - _spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          children: [
            for (final child in children)
              SizedBox(width: cardWidth, height: itemHeight, child: child),
          ],
        );
      },
    );
  }
}
