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
