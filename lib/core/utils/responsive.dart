import 'package:flutter/widgets.dart';

import '../theme/app_spacing.dart';

/// Breakpoint helpers for the tablet layouts.
///
/// The design baseline is a 10" tablet in landscape (~1280x800). These exist so
/// screens ask "is there room for a split view?" rather than hardcoding widths,
/// which is what would make a phone layout impossible to add later.
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  bool get isLandscape =>
      MediaQuery.orientationOf(this) == Orientation.landscape;

  /// Phone territory. Not a Phase 1 target — layouts must degrade rather than
  /// overflow, but no phone-specific design work is expected.
  bool get isCompact => screenWidth < AppBreakpoints.compact;

  /// The navigation sidebar shows icons only. True below the design baseline —
  /// a 7" tablet, a 10" in portrait, or a 10" landscape narrower than ~1100dp,
  /// where a 280dp sidebar would leave the dense content area too cramped.
  bool get isSidebarCollapsed =>
      screenWidth < AppBreakpoints.sidebarCollapse;

  /// There is room for a list and a detail pane side by side. Below this,
  /// tapping a row pushes a full page instead.
  bool get canSplitView => screenWidth >= AppBreakpoints.splitView;

  /// Sensible column count for a card grid at the current width.
  int gridColumns({int max = 4}) {
    final width = screenWidth;
    if (width < AppBreakpoints.compact) return 1;
    if (width < AppBreakpoints.railCollapse) return 2;
    if (width < 1400) return 3;
    return max;
  }
}

/// Column count for a card grid, from the *available content width* rather
/// than the screen width — a `LayoutBuilder` constraint inside the page body,
/// which is narrower than the screen once the sidebar takes its share. Every
/// card stays at least [minCardWidth] wide, so a grid never crowds cards to
/// the point of clipping their content.
///
/// Shared by every card grid that used to size itself independently — the
/// roster grid, the pointage history cards and the payroll history cards —
/// so the same width reads as the same column count everywhere in the app.
int cardGridColumns(
  double width, {
  double minCardWidth = 280,
  double singleColumnBelow = 420,
  int maxColumns = 4,
}) {
  if (width < singleColumnBelow) return 1;
  final columns = (width / minCardWidth).floor();
  return columns.clamp(2, maxColumns);
}
