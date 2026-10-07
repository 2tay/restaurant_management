import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';

/// Cards in equal columns — always one on a phone or a small tablet, then two,
/// three or four as the content width allows, each at least [minCardWidth]
/// wide (the gaps between them counted, so no card ends up narrower).
///
/// Columns come from the width the grid actually gets, not the screen's: the
/// sidebar takes a different share at each breakpoint, so the same screen width
/// can leave very different room. Two exceptions go by the screen:
///
/// - below a medium screen ([ResponsiveContext.isSmallScreen]) it is always
///   one column — two are always cramped there;
/// - while the sidebar is an icon strip (below
///   [AppBreakpoints.sidebarCollapse]), never more columns than the grid gets
///   once the sidebar opens at that width. Otherwise widening the window went
///   2 → 3 → 2 → 3: the sidebar taking 192dp back at 1100 dropped a column.
///   Now the count only ever grows with the window.
///
/// Shared by the Personnel cards, the pointage board and both history pages,
/// so the same width reads as the same column count everywhere.
class ResponsiveCardGrid extends StatelessWidget {
  const ResponsiveCardGrid({
    required this.children,
    this.minCardWidth = 320,
    this.maxColumns = 4,
    this.itemHeight,
    super.key,
  });

  final List<Widget> children;

  /// The narrowest a card may be drawn. The default fits a history card's
  /// header whole: `📅 Sam 03/10/2026` beside its « Non payé » badge.
  final double minCardWidth;
  final int maxColumns;

  /// A fixed height for every card — for cards whose content is laid out
  /// against the bottom edge. Null lets each card size itself.
  final double? itemHeight;

  static const double _spacing = AppSpacing.lg;

  /// The grid's width at [AppBreakpoints.sidebarCollapse], the sidebar just
  /// opened to its full width.
  static const double _widthAtSidebarOpen =
      AppBreakpoints.sidebarCollapse -
      AppSizing.sidebarWidthExpanded -
      2 * AppSpacing.pagePadding;

  /// How many cards of at least [minCardWidth] fit [width], gaps included.
  int _fit(double width) =>
      ((width + _spacing) / (minCardWidth + _spacing)).floor().clamp(
        1,
        maxColumns,
      );

  @override
  Widget build(BuildContext context) {
    final single = context.isSmallScreen;
    final railOnly =
        MediaQuery.sizeOf(context).width < AppBreakpoints.sidebarCollapse;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        var columns = single ? 1 : _fit(width);
        if (!single && railOnly) {
          columns = math.min(columns, _fit(_widthAtSidebarOpen));
        }
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
