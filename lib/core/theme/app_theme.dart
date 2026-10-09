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
  /// [base] with its filled and outlined buttons sized for a screen [width]
  /// — see [AppSizing.buttonHeightFor]. Applied once above the whole app, so
  /// every button, dialog and sheet follows the screen it is on without each
  /// call site asking.
  static ThemeData sizedFor(ThemeData base, double width) {
    final height = AppSizing.buttonHeightFor(width);
    if (height == AppSizing.buttonHeight) return base;

    final size = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, height)),
      // Less side padding on a phone, where two buttons share a row.
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: width < AppBreakpoints.compact
              ? AppSpacing.lg
              : AppSpacing.xl,
        ),
      ),
    );
    return base.copyWith(
      filledButtonTheme: FilledButtonThemeData(
        style: size.merge(base.filledButtonTheme.style),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: size.merge(base.outlinedButtonTheme.style),
      ),
    );
  }

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
      // Every variant is at least AppSizing.buttonHeight tall — less on a
      // tablet or a phone, see [sizedFor]. Widths are left
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
      // Matches AppCard: lifted rather than outlined.
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 1,
        shadowColor: AppColors.neutral950.withValues(alpha: 0.10),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(color: AppColors.hairline),
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

      // The navigation sidebar draws its own white chrome — see
      // `app_sidebar.dart`. It is a plain widget, not a `NavigationRail`, so
      // there is no rail theme to set here.

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
        elevation: 6,
        shadowColor: AppColors.neutral950.withValues(alpha: 0.18),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyLarge,
      ),
      // White throughout, header included — Material's default grey ground
      // read as a disabled panel. The selected day is the one teal fill; today
      // is only ringed, so the two never look alike.
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: AppColors.neutral950.withValues(alpha: 0.18),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        headerBackgroundColor: AppColors.white,
        headerForegroundColor: AppColors.textPrimary,
        // Sizes as seen on screen — `showAppDatePicker` compensates for the
        // scale it draws the dialog at.
        headerHelpStyle: textTheme.labelMedium?.copyWith(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
        headerHeadlineStyle: textTheme.headlineSmall?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        dividerColor: AppColors.border,
        weekdayStyle: textTheme.labelMedium?.copyWith(
          fontSize: 12,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        dayStyle: textTheme.bodyMedium?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        yearStyle: textTheme.bodyMedium?.copyWith(fontSize: 14),
        dayShape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        ),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.white;
          if (states.contains(WidgetState.disabled)) {
            return AppColors.textDisabled;
          }
          return AppColors.textPrimary;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary600
              : Colors.transparent,
        ),
        dayOverlayColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.white.withValues(alpha: 0.12)
              : AppColors.primary600.withValues(alpha: 0.08),
        ),
        todayForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.white
              : AppColors.primary600,
        ),
        todayBackgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary600
              : Colors.transparent,
        ),
        todayBorder: const BorderSide(color: AppColors.primary600, width: 1.5),
        yearForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.white
              : AppColors.textPrimary,
        ),
        yearBackgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary600
              : Colors.transparent,
        ),
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
        ),
        confirmButtonStyle: TextButton.styleFrom(
          backgroundColor: AppColors.primary600,
          foregroundColor: AppColors.white,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
      ),
      // White with brand-green text, lifted off white pages by the menus'
      // shadow rather than a border.
      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: AppRadius.smAll,
          boxShadow: AppElevation.raised,
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: AppColors.primary600,
          fontWeight: FontWeight.w500,
        ),
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
        // 64dp is a floor, not a ceiling. Pinning both ends held every row to
        // exactly 64 — which is right at the default type size and clips the
        // cell at 150%, where the user who turned the text up sees the bottom
        // of every figure sliced off. A row that grows is the whole point of a
        // minimum.
        dataRowMinHeight: AppSizing.tableRowHeight,
        dataRowMaxHeight: double.infinity,
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
