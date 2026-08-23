import 'package:flutter/widgets.dart';

/// Spacing, sizing and radius constants.
///
/// A 4dp base grid. Use these rather than literal numbers so density can be
/// tuned in one place — a tablet held at arm's length in a kitchen needs more
/// breathing room than the phone-oriented Material defaults provide.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Outer padding of a content page inside the shell.
  static const double pagePadding = xl;

  /// Gap between cards and between rows in a list.
  static const double gap = lg;

  static const EdgeInsets pageInsets = EdgeInsets.all(pagePadding);
  static const EdgeInsets cardInsets = EdgeInsets.all(lg);
}

/// Corner radii.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;

  /// Fully rounded — badges and chips.
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Interactive element sizing.
///
/// These are floors, not suggestions. The user is standing, moving fast, and
/// may have wet hands.
abstract final class AppSizing {
  /// Absolute minimum for any tappable element. Enforced by the brief.
  static const double minTapTarget = 48;

  /// Primary actions get more than the minimum.
  static const double buttonHeight = 56;
  static const double buttonHeightLarge = 64;

  /// Text fields match button height so forms align on a single rhythm.
  static const double inputHeight = 56;

  /// The +/- targets on the quantity stepper. Oversized on purpose: this is
  /// the single most-tapped control in the app.
  static const double stepperButton = 64;

  static const double railWidthExpanded = 232;
  static const double railWidthCollapsed = 88;
  static const double topBarHeight = 72;

  /// Data table rows. Material's 48dp default is too tight to scan quickly.
  static const double tableRowHeight = 64;
  static const double tableHeaderHeight = 56;

  static const double iconSm = 18;
  static const double iconMd = 22;
  static const double iconLg = 28;
}

/// Layout breakpoints, in logical pixels.
///
/// The design baseline is a 10" tablet in landscape (~1280x800). Helper
/// functions that consume these land in `core/utils/responsive.dart` in
/// Stage 3, alongside the navigation shell that first needs them.
abstract final class AppBreakpoints {
  /// Below this, the navigation rail collapses to icons only. Chosen for 7"
  /// tablets and for portrait orientation on a 10".
  static const double railCollapse = 900;

  /// Below this, master–detail splits collapse to full-page navigation.
  static const double splitView = 1100;

  /// Phone territory. Not a Phase 1 target, but layouts should degrade rather
  /// than overflow.
  static const double compact = 600;
}

/// Shadows. Used sparingly — this is a data tool, not a landing page.
abstract final class AppElevation {
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0D0F1417), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A0F1417), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> raised = [
    BoxShadow(color: Color(0x141F2933), blurRadius: 16, offset: Offset(0, 4)),
  ];
}
