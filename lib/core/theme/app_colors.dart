import 'package:flutter/material.dart';

/// The application palette.
///
/// Grounded in the kitchen world rather than generic SaaS blue: chalkboard
/// slate neutrals, brushed-steel chrome, and a single saturated action colour.
///
/// Two rules this file exists to enforce:
///
/// 1. **The action colour is teal, the in-stock colour is green.** They are
///    deliberately different hues. If the primary button and the "En stock"
///    badge share a hue, a busy screen reads as one green mush and the status
///    signal stops carrying meaning.
/// 2. **Status is never communicated by colour alone.** Each entry in
///    [StockStatusColors] pairs with an icon and a text label at the call site
///    (see the badge widget in Stage 4). Roughly 1 in 12 men has a red/green
///    colour vision deficiency, and this app's core signal is red/amber/green.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Neutrals — chalkboard slate. Surfaces, text, borders.
  // ---------------------------------------------------------------------------

  static const Color neutral950 = Color(0xFF0F1417);
  static const Color neutral900 = Color(0xFF171D21);
  static const Color neutral800 = Color(0xFF232B31);
  static const Color neutral700 = Color(0xFF333D45);
  static const Color neutral600 = Color(0xFF4A565F);
  static const Color neutral500 = Color(0xFF64717B);
  static const Color neutral400 = Color(0xFF8A959E);
  static const Color neutral300 = Color(0xFFB4BDC4);
  static const Color neutral200 = Color(0xFFD6DCE1);
  static const Color neutral100 = Color(0xFFE9EDF0);
  static const Color neutral50 = Color(0xFFF5F7F9);
  static const Color white = Color(0xFFFFFFFF);

  // ---------------------------------------------------------------------------
  // Steel — the app chrome. Navigation rail and top bar.
  // ---------------------------------------------------------------------------

  static const Color steel800 = Color(0xFF2A3945);
  static const Color steel700 = Color(0xFF3A4A57);
  static const Color steel600 = Color(0xFF4C6072);
  static const Color steel500 = Color(0xFF5E7688);

  // ---------------------------------------------------------------------------
  // Primary — teal. Reserved for primary actions ONLY.
  //
  // Do not use this for decoration, headers, or emphasis. Its entire job is to
  // answer "what do I tap next?" at a glance, and it can only do that if it
  // appears roughly once per screen.
  // ---------------------------------------------------------------------------

  static const Color primary700 = Color(0xFF0B5F58);
  static const Color primary600 = Color(0xFF0F766E);
  static const Color primary500 = Color(0xFF148F84);
  static const Color primaryContainer = Color(0xFFD3EDE9);
  static const Color onPrimaryContainer = Color(0xFF06403B);

  // ---------------------------------------------------------------------------
  // Status triad — in stock / low stock / out of stock.
  //
  // Must be distinguishable instantly, from a distance, on a greasy screen.
  // ---------------------------------------------------------------------------

  static const StockStatusColors inStock = StockStatusColors(
    solid: Color(0xFF2E7D32),
    foreground: Color(0xFF1B5E20),
    container: Color(0xFFDBEEDD),
  );

  static const StockStatusColors lowStock = StockStatusColors(
    solid: Color(0xFFC77700),
    foreground: Color(0xFF7A4A00),
    container: Color(0xFFFCEBCF),
  );

  static const StockStatusColors outOfStock = StockStatusColors(
    solid: Color(0xFFC62828),
    foreground: Color(0xFF8E1B1B),
    container: Color(0xFFFADEDE),
  );

  /// The pointage "en pause" colour. Deliberately in the teal family rather
  /// than amber: on the kiosk board a break is a normal, benign state, not a
  /// warning, and the redesign asks for the primary accent here. It is a tinted
  /// badge (container + dark teal text), never a filled teal surface, so it
  /// does not compete with the one teal *action* per card.
  static const StockStatusColors onBreak = StockStatusColors(
    solid: primary600,
    foreground: onPrimaryContainer,
    container: primaryContainer,
  );

  // ---------------------------------------------------------------------------
  // Feedback — snackbars, banners, form validation.
  // ---------------------------------------------------------------------------

  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFC77700);
  static const Color error = Color(0xFFC62828);
  static const Color errorContainer = Color(0xFFFADEDE);
  static const Color onErrorContainer = Color(0xFF8E1B1B);

  /// Danger, readable on the dark steel chrome — [error] is too deep to carry
  /// contrast there. Used for "Se déconnecter" in the sidebar user menu.
  static const Color errorOnChrome = Color(0xFFF08A8A);

  /// The offline banner. Intentionally informational rather than alarming —
  /// offline is the normal state for this app, not a failure.
  static const Color offline = Color(0xFF4C6072);
  static const Color offlineContainer = Color(0xFFE3E9ED);

  // ---------------------------------------------------------------------------
  // Structure
  // ---------------------------------------------------------------------------

  static const Color background = Color(0xFFF5F7F9);
  static const Color surface = white;
  static const Color surfaceVariant = Color(0xFFEFF2F5);
  static const Color border = Color(0xFFD6DCE1);
  static const Color borderStrong = Color(0xFFB4BDC4);

  /// A near-invisible edge for elevated surfaces. Cards are separated by their
  /// shadow, not by an outline; this only stops white-on-white going mushy at
  /// the boundary.
  static const Color hairline = Color(0xFFE9EDF0);

  /// Body text. Deliberately not pure black — slate reads softer on a bright
  /// kitchen screen without giving up contrast (12.6:1 on [surface]).
  static const Color textPrimary = neutral900;

  /// Secondary text. This is the lightest text permitted anywhere in the app
  /// (4.8:1 on [surface]). Nothing lighter — the brief bans low-contrast grey.
  static const Color textSecondary = neutral600;

  /// Disabled/placeholder only. Never for information the user must read.
  static const Color textDisabled = neutral400;
}

/// The colour set for one stock status.
///
/// [solid] is for filled indicators (dots, bars, chart series). [container] +
/// [foreground] pair for badges — light tinted background, dark readable text.
@immutable
class StockStatusColors {
  const StockStatusColors({
    required this.solid,
    required this.foreground,
    required this.container,
  });

  final Color solid;
  final Color foreground;
  final Color container;
}
