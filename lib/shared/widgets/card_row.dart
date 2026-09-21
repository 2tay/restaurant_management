import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// A section of cards that is always **one row** — never a grid that wraps.
///
/// With room for every card at [minCardWidth] or wider, the cards share the
/// width equally and stretch to the tallest one, so a row of figures lines up
/// top and bottom. Without it — a phone, a narrow pane — the same cards scroll
/// sideways at [scrollCardWidth], with the next one peeking in at the edge and
/// dots underneath, so it is plain there is more to swipe to.
///
/// A wrapping grid was the thing this replaces: five figures in four columns
/// left one card alone on a second row, and on a phone the grid stacked them
/// one per line, so the dashboard was a column of five before anything else.
class CardRow extends StatefulWidget {
  const CardRow({
    required this.children,
    this.minCardWidth = 168,
    this.scrollCardWidth = 168,
    this.spacing = AppSpacing.lg,
    super.key,
  });

  final List<Widget> children;

  /// Below this width per card, the row scrolls instead of squeezing.
  final double minCardWidth;

  /// Each card's width once the row scrolls.
  final double scrollCardWidth;

  final double spacing;

  @override
  State<CardRow> createState() => _CardRowState();
}

class _CardRowState extends State<CardRow> {
  final _controller = ScrollController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    final step = widget.scrollCardWidth + widget.spacing;
    final page = (_controller.offset / step).round().clamp(
      0,
      widget.children.length - 1,
    );
    if (page != _page) setState(() => _page = page);
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.children.length;
    if (count == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final needed =
            count * widget.minCardWidth + (count - 1) * widget.spacing;

        if (constraints.maxWidth >= needed) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, child) in widget.children.indexed) ...[
                  if (i > 0) SizedBox(width: widget.spacing),
                  Expanded(child: child),
                ],
              ],
            ),
          );
        }

        // How many fit whole; the dots count the positions the row can
        // scroll to, not the cards, so the last dot is reachable.
        final visible =
            ((constraints.maxWidth + widget.spacing) /
                    (widget.scrollCardWidth + widget.spacing))
                .floor()
                .clamp(1, count);
        final positions = count - visible + 1;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, child) in widget.children.indexed) ...[
                      if (i > 0) SizedBox(width: widget.spacing),
                      SizedBox(width: widget.scrollCardWidth, child: child),
                    ],
                  ],
                ),
              ),
            ),
            if (positions > 1) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < positions; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxs,
                      ),
                      width: i == _page.clamp(0, positions - 1) ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _page.clamp(0, positions - 1)
                            ? AppColors.primary600
                            : AppColors.border,
                        borderRadius: AppRadius.pillAll,
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
