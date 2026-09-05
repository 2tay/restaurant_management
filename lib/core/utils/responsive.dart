import 'package:flutter/widgets.dart';

import '../theme/app_spacing.dart';

/// Which of the four layout bands the window currently falls in.
///
/// Screens branch on this rather than on raw widths, so a threshold moves in
/// one place. The bands are the Material 3 ones, cut at [AppBreakpoints].
enum WindowSize {
  /// < 600dp. A phone. No persistent sidebar, one column, rows stack.
  phone,

  /// 600–840dp. A large phone in landscape or a 7" tablet in portrait.
  compact,

  /// 840–1200dp. A 10" tablet in portrait, or a small desktop window.
  medium,

  /// >= 1200dp. The design baseline: 10" landscape and up.
  expanded,
}

/// Breakpoint helpers.
///
/// The design baseline is a 10" tablet in landscape (~1280x800), but layouts
/// must hold from 360dp up. These exist so screens ask "is there room for a
/// split view?" rather than hardcoding widths.
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  bool get isLandscape =>
      MediaQuery.orientationOf(this) == Orientation.landscape;

  WindowSize get windowSize {
    final width = screenWidth;
    if (width < AppBreakpoints.compact) return WindowSize.phone;
    if (width < AppBreakpoints.medium) return WindowSize.compact;
    if (width < AppBreakpoints.expanded) return WindowSize.medium;
    return WindowSize.expanded;
  }

  /// Phone territory: the shell hides its sidebar behind a drawer, and any row
  /// of more than two things stacks.
  bool get isPhone => screenWidth < AppBreakpoints.compact;

  /// Kept as the original name for the ~600dp threshold. Identical to
  /// [isPhone]; both read naturally in different call sites and there is no
  /// value in breaking the dozen existing uses.
  bool get isCompact => isPhone;

  /// The navigation sidebar shows icons only. True below the design baseline —
  /// a 7" tablet, a 10" in portrait, or a 10" landscape narrower than ~1100dp,
  /// where a 280dp sidebar would leave the dense content area too cramped.
  ///
  /// Only meaningful when the sidebar is on screen at all; below [isPhone] it
  /// has moved into a drawer and this says nothing useful.
  bool get isSidebarCollapsed => screenWidth < AppBreakpoints.sidebarCollapse;

  /// There is room for a list and a detail pane side by side. Below this,
  /// tapping a row pushes a full page instead.
  bool get canSplitView => screenWidth >= AppBreakpoints.splitView;

  /// The user has turned text up. Independent of width: a row that fits at
  /// 1280dp can still be unreadable at 200% type, and the fix is the same one
  /// narrowness calls for — stack it.
  ///
  /// The threshold is ~1.3x, past which two- and three-column rows of French
  /// labels stop fitting on a tablet.
  bool get isLargeText => MediaQuery.textScalerOf(this).scale(14) > 18;

  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// A window with little vertical room — a 1024x600 tablet in landscape, or a
  /// phone with the keyboard up.
  ///
  /// Width breakpoints cannot see this. 1024x600 is a *wide* window by every
  /// horizontal measure and still one of the worst screens in the app, because
  /// the page chrome above a list is a fixed height and 600dp is not much to
  /// take it out of. Anything that trims vertically keys off this.
  bool get isShort => screenHeight < 700;

  /// Outer padding for a content page.
  ///
  /// Tighter on a phone, where 24dp a side is a tenth of the screen, and
  /// tighter top and bottom on a short window, where the vertical is what the
  /// content is short of.
  EdgeInsets get pageInsets => EdgeInsets.symmetric(
    horizontal: isPhone ? AppSpacing.lg : AppSpacing.pagePadding,
    vertical: isPhone || isShort ? AppSpacing.lg : AppSpacing.pagePadding,
  );

  /// Margin between a dialog and the edge of the window.
  ///
  /// Material's default is a flat 40dp a side, which on a 360dp phone spends
  /// nearly a quarter of the width on air and leaves a French confirmation
  /// message wrapping to six lines.
  EdgeInsets get dialogInsets => EdgeInsets.symmetric(
    horizontal: isPhone ? AppSpacing.lg : AppSpacing.xxxl,
    vertical: AppSpacing.xl,
  );

  /// Picks a value for the current band.
  ///
  /// [phone] and [expanded] are required — the two ends must always have an
  /// answer. The middle bands fall back to the nearest one below them, so
  /// `responsive(phone: 1, expanded: 3)` gives 1, 1, 3, 3 rather than forcing
  /// every call site to spell out all four.
  T responsive<T>({required T phone, T? compact, T? medium, required T expanded}) {
    switch (windowSize) {
      case WindowSize.phone:
        return phone;
      case WindowSize.compact:
        return compact ?? phone;
      case WindowSize.medium:
        return medium ?? compact ?? phone;
      case WindowSize.expanded:
        return expanded;
    }
  }

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
/// Shared between the pointage history cards and the payroll history cards —
/// the table's small-screen alternative on both pages — so the same width
/// reads as the same column count on each.
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
