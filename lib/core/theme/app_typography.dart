import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The type scale.
///
/// Sized for a tablet resting on a counter or wall-mounted — roughly an arm's
/// length away, further than a phone. Every size here is a step or two larger
/// than the Material default for the same slot, and nothing renders below
/// [_minReadable].
///
/// French runs 15–25% longer than English for the same content, so text styles
/// must wrap rather than clip. Anything that lays out against a fixed width
/// needs checking against real French strings, not placeholders.
abstract final class AppTypography {
  /// Falls back silently to the platform default until the Inter `.ttf` files
  /// are placed in `fonts/` and the `fonts:` block in `pubspec.yaml` is
  /// uncommented. See the README.
  static const String fontFamily = 'Inter';

  /// Nothing in the app may be smaller than this. A rushed user at arm's
  /// length cannot read 11pt.
  static const double _minReadable = 13;

  static const TextTheme textTheme = TextTheme(
    // Display — the store selector heading, and little else.
    displaySmall: TextStyle(
      fontSize: 36,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: AppColors.textPrimary,
    ),

    // Headline — page titles.
    headlineLarge: TextStyle(
      fontSize: 32,
      height: 1.25,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      color: AppColors.textPrimary,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      height: 1.3,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
      color: AppColors.textPrimary,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),

    // Title — section headers, card headers, dialog titles.
    titleLarge: TextStyle(
      fontSize: 22,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    titleMedium: TextStyle(
      fontSize: 18,
      height: 1.4,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    titleSmall: TextStyle(
      fontSize: 16,
      height: 1.4,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),

    // Body — the default. bodyLarge is the workhorse.
    bodyLarge: TextStyle(
      fontSize: 17,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary,
    ),
    bodyMedium: TextStyle(
      fontSize: 15,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary,
    ),
    bodySmall: TextStyle(
      fontSize: _minReadable,
      height: 1.45,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
    ),

    // Label — buttons, badges, table headers, rail entries.
    labelLarge: TextStyle(
      fontSize: 16,
      height: 1.3,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: AppColors.textPrimary,
    ),
    labelMedium: TextStyle(
      fontSize: 14,
      height: 1.3,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      color: AppColors.textPrimary,
    ),
    labelSmall: TextStyle(
      fontSize: _minReadable,
      height: 1.3,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
      color: AppColors.textSecondary,
    ),
  );

  // ---------------------------------------------------------------------------
  // Numeric styles
  //
  // Quantities and prices sit in columns and get compared against each other,
  // so they use tabular (monospaced) figures — otherwise digits shift width
  // between rows and the column looks ragged. This matters most on the price
  // comparison report, which is the app's headline feature.
  // ---------------------------------------------------------------------------

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// Quantities and prices inside tables and list rows.
  static const TextStyle numeric = TextStyle(
    fontSize: 17,
    height: 1.4,
    fontWeight: FontWeight.w500,
    fontFeatures: _tabular,
    color: AppColors.textPrimary,
  );

  /// The large number on a dashboard summary tile.
  static const TextStyle numericLarge = TextStyle(
    fontSize: 34,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    fontFeatures: _tabular,
    color: AppColors.textPrimary,
  );

  /// Secondary figures — "il y a 3 jours", row counts, deltas.
  static const TextStyle numericSmall = TextStyle(
    fontSize: 15,
    height: 1.4,
    fontWeight: FontWeight.w500,
    fontFeatures: _tabular,
    color: AppColors.textSecondary,
  );
}
