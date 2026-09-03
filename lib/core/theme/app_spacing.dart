import 'package:flutter/material.dart';

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

  /// The navigation sidebar. Wide enough that no French destination label is
  /// ever truncated (the rebuild brief), and it carries the store selector and
  /// the user menu now that there is no top bar.
  static const double sidebarWidthExpanded = 280;

  /// Icons only — a 7" tablet, or a 10" held in portrait.
  static const double sidebarWidthCollapsed = 88;

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
  /// Below this, card grids drop from three columns to two. Chosen for 7"
  /// tablets and for portrait orientation on a 10".
  static const double railCollapse = 900;

  /// Below this, the navigation sidebar collapses to an icon strip. Higher than
  /// [railCollapse]: a 280dp sidebar on a sub-1100dp landscape tablet leaves
  /// too little for this app's dense tables and forms.
  static const double sidebarCollapse = 1100;

  /// Below this, master–detail splits collapse to full-page navigation.
  static const double splitView = 1100;

  /// Phone territory. Not a Phase 1 target, but layouts should degrade rather
  /// than overflow.
  static const double compact = 600;
}

/// Elevation, as soft shadows rather than borders.
///
/// Phase 1 outlined every surface. A screen of hairline-boxed rectangles reads
/// as a spreadsheet; the same content on softly lifted surfaces reads as an
/// application. The shadows are deliberately low-opacity and short-offset —
/// enough to separate a card from the page, not enough to look like a
/// drop-shadow effect.
abstract final class AppElevation {
  /// The resting state of a card.
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0F0F1417), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A0F1417), blurRadius: 6, offset: Offset(0, 2)),
  ];

  /// A card under the pointer, or one holding the current selection.
  static const List<BoxShadow> cardHovered = [
    BoxShadow(color: Color(0x140F1417), blurRadius: 4, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x140F1417), blurRadius: 14, offset: Offset(0, 6)),
  ];

  /// Dialogs, menus, and the pinned form action bar.
  static const List<BoxShadow> raised = [
    BoxShadow(color: Color(0x1F1F2933), blurRadius: 24, offset: Offset(0, 8)),
  ];

  /// Sits under a sticky table header so rows appear to scroll beneath it.
  static const List<BoxShadow> stickyHeader = [
    BoxShadow(color: Color(0x120F1417), blurRadius: 6, offset: Offset(0, 3)),
  ];
}

/// Motion.
///
/// Short and quick. The user is mid-service; animation here exists to show that
/// one screen came from another, not to be admired. Anything over about 250ms
/// starts to feel like waiting.
///
/// Every duration must go through [AppMotion.duration], which returns
/// [Duration.zero] when the platform asks for reduced motion.
abstract final class AppMotion {
  /// Hover, press, selection — near-instant feedback.
  static const Duration fast = Duration(milliseconds: 120);

  /// The default: panel expansion, list item entrance, elevation change.
  static const Duration normal = Duration(milliseconds: 180);

  /// Page transitions, which travel further.
  static const Duration page = Duration(milliseconds: 220);

  /// Decelerating — things arriving should settle rather than stop dead.
  static const Curve enter = Curves.easeOutCubic;

  /// Symmetric, for state changes that are not arrivals.
  static const Curve standard = Curves.easeInOut;

  /// Collapses to zero when the OS accessibility setting asks it to.
  ///
  /// Honouring `disableAnimations` is not optional politeness: for a user with
  /// vestibular sensitivity, motion they did not ask for is a symptom trigger.
  static Duration duration(BuildContext context, Duration value) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false
      ? Duration.zero
      : value;
}
