import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// A surface.
///
/// Phase 1 drew these as hairline-bordered rectangles, which made every screen
/// read as a spreadsheet. They are now softly lifted instead: a low-opacity
/// shadow separates the card from the page without announcing itself.
///
/// Interactive cards respond. Hover lifts them slightly, press settles them
/// back down, and the selected card in a master–detail list is outlined in the
/// action colour so the connection to the detail pane is unmistakable. Without
/// that, a split view is two unrelated panels sitting next to each other.
class AppCard extends StatefulWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding,
    this.selected = false,
    this.accentColor,
    super.key,
  });

  final Widget child;

  /// Makes the whole card tappable, with hover and press feedback.
  final VoidCallback? onTap;

  final EdgeInsetsGeometry? padding;

  /// Highlights the card whose detail is currently open.
  final bool selected;

  /// A thick left edge — carries stock status onto a card without relying on
  /// the surface colour, which has to stay neutral.
  final Color? accentColor;

  /// The hairline a resting card is drawn with.
  static const double borderWidth = 1;

  /// The outline a selected card is drawn with instead.
  static const double selectedBorderWidth = 2;

  /// What the border costs the child vertically, at its thickest.
  ///
  /// A [BoxDecoration] border insets what it wraps, so the child is laid out
  /// in the card's height *less* this. A grid sizing a tile to its contents
  /// has to add it back — the product grid did not, and every card in it was
  /// striped "BOTTOM OVERFLOWED BY 2.0 PIXELS", or 4 where one was selected.
  ///
  /// It is the selected width whether or not the card is selected: a tile that
  /// changed height when it was picked would shuffle the row around it.
  static const double verticalBorderAllowance = selectedBorderWidth * 2;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _isInteractive => widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: widget.padding ?? AppSpacing.cardInsets,
      child: widget.child,
    );

    final lifted = _isInteractive && (_hovered || widget.selected || _focused);

    return MouseRegion(
      cursor: _isInteractive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: _isInteractive ? (_) => setState(() => _hovered = true) : null,
      onExit: _isInteractive ? (_) => setState(() => _hovered = false) : null,
      child: AnimatedContainer(
        duration: AppMotion.duration(context, AppMotion.fast),
        curve: AppMotion.standard,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.lgAll,
          // Keyboard focus is drawn the same way selection is, because it
          // means the same thing to the person looking at it: this is the card
          // you are about to act on. Without it, tabbing through a list on a
          // desktop window moved an invisible cursor.
          border: widget.selected || _focused
              ? Border.all(
                  color: AppColors.primary600,
                  width: AppCard.selectedBorderWidth,
                )
              : Border.all(
                  color: AppColors.hairline,
                  width: AppCard.borderWidth,
                ),
          // Pressed drops back to resting so the card appears to sink under
          // the finger rather than staying lifted.
          boxShadow: _pressed
              ? AppElevation.card
              : lifted
              ? AppElevation.cardHovered
              : AppElevation.card,
        ),
        child: ClipRRect(
          borderRadius: AppRadius.lgAll,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              canRequestFocus: _isInteractive,
              onFocusChange: _isInteractive
                  ? (value) => setState(() => _focused = value)
                  : null,
              onTapDown: _isInteractive
                  ? (_) => setState(() => _pressed = true)
                  : null,
              onTapUp: _isInteractive
                  ? (_) => setState(() => _pressed = false)
                  : null,
              onTapCancel: _isInteractive
                  ? () => setState(() => _pressed = false)
                  : null,
              hoverColor: AppColors.primary600.withValues(alpha: 0.03),
              splashColor: AppColors.primary600.withValues(alpha: 0.06),
              // The accent stripe is a positioned child rather than a Row
              // sibling or a thicker left border. A Row would need
              // CrossAxisAlignment.stretch, which demands a bounded height, and
              // these cards live in ListViews where height is unbounded. A
              // non-uniform Border cannot be painted with a borderRadius at
              // all. Stack sizes itself to the content and lets the stripe
              // fill.
              child: widget.accentColor == null
                  ? content
                  : Stack(
                      children: [
                        content,
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: 5,
                          child: ColoredBox(color: widget.accentColor!),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
