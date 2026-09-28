import 'package:flutter/widgets.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';

/// One slot in an [AdaptiveRow].
///
/// The flex lives here rather than in an `Expanded` around the child because
/// the child has to work in both layouts: an `Expanded` is legal in the row and
/// throws in the stacked column, which sits in a `ListView` where height is
/// unbounded. Declaring the intent as data lets [AdaptiveRow] apply it only
/// where it means something.
class AdaptiveCell {
  const AdaptiveCell({required this.child, this.flex = 0, this.width});

  final Widget child;

  /// Share of the leftover width in row layout. Zero takes the child's natural
  /// width. Ignored when stacked.
  final int flex;

  /// A fixed width in row layout, for a column that must line up down a list —
  /// a date, a duration. Ignored when stacked, where the child fills the line.
  ///
  /// Prefer [flex]. A fixed width is a promise that the content never grows,
  /// which French labels and 150% type both break.
  final double? width;

  /// Sizes itself to its content in both layouts. The common case.
  static AdaptiveCell auto(Widget child) => AdaptiveCell(child: child);

  /// Takes the slack. Use for the one column that should absorb the window.
  static AdaptiveCell expand(Widget child, {int flex = 1}) =>
      AdaptiveCell(child: child, flex: flex);
}

/// A row that becomes a column when there is not enough width for it.
///
/// The app is full of pseudo-tables — a list row built from a `Row` of
/// `SizedBox`es so the columns line up down the page. Those are correct on the
/// 1280dp design baseline and overflow on a phone. This is the one mechanism
/// that fixes them: above [breakpoint] it lays out as the row it always was,
/// below it each cell takes its own full-width line.
///
/// It measures its own constraints rather than the screen, because a row inside
/// a 434dp detail pane on a 1280dp tablet is narrow even though the window is
/// not — the bug the comment in `section_header.dart` records. The cost is that
/// a `LayoutBuilder` cannot report intrinsic dimensions, so an [AdaptiveRow]
/// must not be placed inside an `IntrinsicHeight` or an `IntrinsicWidth`.
class AdaptiveRow extends StatelessWidget {
  const AdaptiveRow({
    required this.cells,
    this.breakpoint = AppBreakpoints.compact,
    this.spacing = AppSpacing.md,
    this.runSpacing = AppSpacing.sm,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.stackedCrossAxisAlignment = CrossAxisAlignment.start,
    this.stackOnLargeText = true,
    super.key,
  });

  final List<AdaptiveCell> cells;

  /// Available width below which the cells stack. Defaults to the phone
  /// threshold; a denser row (five or six columns) should pass something
  /// higher.
  final double breakpoint;

  /// Gap between cells in row layout.
  final double spacing;

  /// Gap between lines in stacked layout.
  final double runSpacing;

  final CrossAxisAlignment crossAxisAlignment;
  final CrossAxisAlignment stackedCrossAxisAlignment;

  /// Stack regardless of width once the user has turned type up. A row that
  /// fits at 1280dp can still be unreadable at 200%.
  final bool stackOnLargeText;

  @override
  Widget build(BuildContext context) {
    final forceStack = stackOnLargeText && context.isLargeText;

    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = forceStack || constraints.maxWidth < breakpoint;
        return stack ? _buildStacked() : _buildRow();
      },
    );
  }

  Widget _buildRow() {
    final children = <Widget>[];
    for (var i = 0; i < cells.length; i++) {
      if (i > 0) children.add(SizedBox(width: spacing));

      final cell = cells[i];
      var child = cell.child;
      if (cell.width != null) {
        child = SizedBox(width: cell.width, child: child);
      }
      children.add(cell.flex > 0 ? Expanded(flex: cell.flex, child: child) : child);
    }

    return Row(crossAxisAlignment: crossAxisAlignment, children: children);
  }

  Widget _buildStacked() {
    final children = <Widget>[];
    for (var i = 0; i < cells.length; i++) {
      if (i > 0) children.add(SizedBox(height: runSpacing));
      children.add(cells[i].child);
    }

    return Column(
      crossAxisAlignment: stackedCrossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
