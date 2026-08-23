import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Assembles [ThemeData] from the palette, type scale and spacing constants.
///
/// The colour scheme is written out explicitly rather than derived with
/// `ColorScheme.fromSeed`. Seeding produces a tonally harmonious palette, but
/// it also quietly reassigns the exact hues chosen in [AppColors] — and this
/// app's status triad has to stay exactly where it was put.
///
/// Only a light theme ships in Phase 1. A kitchen tablet lives under bright
/// service lighting, and the brief asks for a dark theme nowhere. Adding one
/// later means a second [ColorScheme] here and nothing else, provided screens
/// keep reading colours from the scheme rather than from [AppColors] directly.
abstract final class AppTheme {
  static ThemeData get light {
    const colorScheme = _colorScheme;
    const textTheme = AppTypography.textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: AppColors.background,

      // Material shrinks touch targets on desktop-class devices. This app is
      // touch-first regardless of platform, so keep them at full size.
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,

      // ---------------------------------------------------------------------
      // Buttons
      //
      // Every variant is at least AppSizing.buttonHeight tall. Widths are left
      // to the caller: French labels ("Enregistrer une livraison") are long,
      // and a fixed width would clip them.
      // ---------------------------------------------------------------------
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: AppColors.neutral200,
          disabledForegroundColor: AppColors.textDisabled,
          minimumSize: const Size(0, AppSizing.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: textTheme.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(0, AppSizing.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          side: const BorderSide(color: AppColors.borderStrong, width: 1.5),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          minimumSize: const Size(0, AppSizing.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(
            AppSizing.minTapTarget,
            AppSizing.minTapTarget,
          ),
          foregroundColor: AppColors.textSecondary,
        ),
      ),

      // ---------------------------------------------------------------------
      // Inputs
      //
      // Filled rather than outlined: a filled field reads as "tap here" from
      // further away. Borders only appear on focus and error.
      // ---------------------------------------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(color: AppColors.textDisabled),
        errorStyle: textTheme.bodySmall?.copyWith(color: AppColors.error),
      ),

      // ---------------------------------------------------------------------
      // Surfaces
      // ---------------------------------------------------------------------
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: AppSizing.topBarHeight,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
      ),

      // ---------------------------------------------------------------------
      // Navigation rail — the app chrome, in steel.
      // ---------------------------------------------------------------------
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.steel800,
        indicatorColor: AppColors.primary600,
        selectedIconTheme: const IconThemeData(
          color: AppColors.white,
          size: AppSizing.iconLg,
        ),
        unselectedIconTheme: const IconThemeData(
          color: AppColors.neutral300,
          size: AppSizing.iconLg,
        ),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.white,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.neutral300,
        ),
        minWidth: AppSizing.railWidthCollapsed,
        minExtendedWidth: AppSizing.railWidthExpanded,
      ),

      // ---------------------------------------------------------------------
      // Feedback
      //
      // The snackbar is how the app answers "did that save?", so it is dark,
      // opaque and slow enough to read while looking away and back.
      // ---------------------------------------------------------------------
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.neutral900,
        contentTextStyle: textTheme.bodyLarge?.copyWith(color: AppColors.white),
        actionTextColor: AppColors.primary500,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        insetPadding: const EdgeInsets.all(AppSpacing.xl),
        elevation: 4,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyLarge,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(
          color: AppColors.neutral900,
          borderRadius: AppRadius.smAll,
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: AppColors.white),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),

      // ---------------------------------------------------------------------
      // Data display
      // ---------------------------------------------------------------------
      dataTableTheme: DataTableThemeData(
        headingRowHeight: AppSizing.tableHeaderHeight,
        dataRowMinHeight: AppSizing.tableRowHeight,
        dataRowMaxHeight: AppSizing.tableRowHeight,
        horizontalMargin: AppSpacing.lg,
        columnSpacing: AppSpacing.xl,
        headingTextStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
        dataTextStyle: textTheme.bodyLarge,
        dividerThickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: AppSpacing.md,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        selectedColor: AppColors.primaryContainer,
        labelStyle: textTheme.labelMedium,
        side: const BorderSide(color: AppColors.border),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.white
              : AppColors.neutral500;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.primary600
              : AppColors.neutral200;
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary600,
        linearTrackColor: AppColors.neutral200,
      ),
    );
  }

  static const ColorScheme _colorScheme = ColorScheme(
    brightness: Brightness.light,

    // Primary — actions only.
    primary: AppColors.primary600,
    onPrimary: AppColors.white,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.onPrimaryContainer,

    // Secondary — steel chrome.
    secondary: AppColors.steel600,
    onSecondary: AppColors.white,
    secondaryContainer: AppColors.neutral100,
    onSecondaryContainer: AppColors.neutral800,

    // Tertiary is unused by design. Pointed at steel so that any Material
    // component reaching for it stays inside the palette instead of falling
    // back to a default purple.
    tertiary: AppColors.steel500,
    onTertiary: AppColors.white,
    tertiaryContainer: AppColors.neutral100,
    onTertiaryContainer: AppColors.neutral800,

    error: AppColors.error,
    onError: AppColors.white,
    errorContainer: AppColors.errorContainer,
    onErrorContainer: AppColors.onErrorContainer,

    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    surfaceContainerLowest: AppColors.white,
    surfaceContainerLow: AppColors.neutral50,
    surfaceContainer: AppColors.surfaceVariant,
    surfaceContainerHigh: AppColors.neutral100,
    surfaceContainerHighest: AppColors.neutral200,

    outline: AppColors.borderStrong,
    outlineVariant: AppColors.border,

    shadow: AppColors.neutral950,
    scrim: AppColors.neutral950,
    inverseSurface: AppColors.neutral900,
    onInverseSurface: AppColors.white,
    inversePrimary: AppColors.primary500,

    // Material 3 tints elevated surfaces with the primary colour by default,
    // which turns every card faintly teal. Suppressed.
    surfaceTint: Colors.transparent,
  );
}
