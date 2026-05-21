import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../colors/app_colors.dart';
import '../typography/app_typography.dart';
import '../spacing/app_spacing.dart';

/// Design System — Material 3 Theme Configuration
abstract final class AppTheme {
  static ThemeData get light => _buildTheme(Brightness.light);
  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = isDark ? _darkColorScheme : _lightColorScheme;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: 'Inter',

      // ── Scaffold ────────────────────────────────────────────────────────
      scaffoldBackgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.background,

      // ── AppBar ──────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
        foregroundColor: isDark ? AppColors.textOnDark : AppColors.textPrimary,
        titleTextStyle: AppTypography.titleLarge.copyWith(
          color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
        ),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(
          color: isDark ? AppColors.white : AppColors.grey700,
          size: AppSpacing.iconMd,
        ),
      ),

      // ── Cards ───────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(
            color: isDark ? AppColors.dividerDark : AppColors.divider,
            width: 1,
          ),
        ),
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        margin: EdgeInsets.zero,
      ),

      // ── Elevated Button ─────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.grey200,
          disabledForegroundColor: AppColors.grey400,
          minimumSize: const Size.fromHeight(AppSpacing.buttonHeightMd),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          textStyle: AppTypography.buttonLabel,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
        ),
      ),

      // ── Outlined Button ─────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(AppSpacing.buttonHeightMd),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          textStyle: AppTypography.buttonLabel,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
        ),
      ),

      // ── Text Button ─────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTypography.buttonLabel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
      ),

      // ── Input Decoration ────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.surfaceVariantDark : AppColors.grey50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(
            color: isDark ? AppColors.dividerDark : AppColors.grey300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(
            color: isDark ? AppColors.dividerDark : AppColors.grey300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: isDark ? AppColors.grey400 : AppColors.grey500,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: isDark ? AppColors.grey500 : AppColors.grey400,
        ),
        errorStyle: AppTypography.labelSmall.copyWith(color: AppColors.error),
      ),

      // ── Divider ─────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.dividerDark : AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      // ── Bottom Navigation Bar ────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        elevation: 8,
        height: AppSpacing.bottomNavHeight,
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
        indicatorColor: AppColors.primarySurface,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(
              color: AppColors.primary,
              size: AppSpacing.iconMd,
            );
          }
          return IconThemeData(
            color: isDark ? AppColors.grey400 : AppColors.grey500,
            size: AppSpacing.iconMd,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.labelSmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            );
          }
          return AppTypography.labelSmall.copyWith(
            color: isDark ? AppColors.grey400 : AppColors.grey500,
          );
        }),
      ),

      // ── Chips ───────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? AppColors.surfaceVariantDark
            : AppColors.grey100,
        selectedColor: AppColors.primarySurface,
        labelStyle: AppTypography.labelMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),

      // ── Dialog ──────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
        titleTextStyle: AppTypography.titleLarge.copyWith(
          color: isDark ? AppColors.white : AppColors.textPrimary,
        ),
      ),

      // ── SnackBar ────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.grey700 : AppColors.grey900,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Progress Indicator ───────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.primarySurface,
        circularTrackColor: AppColors.primarySurface,
      ),

      // ── Text Theme ──────────────────────────────────────────────────────
      textTheme:
          TextTheme(
            displayLarge: AppTypography.displayLarge,
            displayMedium: AppTypography.displayMedium,
            displaySmall: AppTypography.displaySmall,
            headlineLarge: AppTypography.headlineLarge,
            headlineMedium: AppTypography.headlineMedium,
            headlineSmall: AppTypography.headlineSmall,
            titleLarge: AppTypography.titleLarge,
            titleMedium: AppTypography.titleMedium,
            titleSmall: AppTypography.titleSmall,
            bodyLarge: AppTypography.bodyLarge,
            bodyMedium: AppTypography.bodyMedium,
            bodySmall: AppTypography.bodySmall,
            labelLarge: AppTypography.labelLarge,
            labelMedium: AppTypography.labelMedium,
            labelSmall: AppTypography.labelSmall,
          ).apply(
            bodyColor: isDark ? AppColors.white : AppColors.textPrimary,
            displayColor: isDark ? AppColors.white : AppColors.textPrimary,
          ),
    );
  }

  static const ColorScheme _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.white,
    primaryContainer: AppColors.primarySurface,
    onPrimaryContainer: AppColors.primaryDark,
    secondary: AppColors.secondary,
    onSecondary: AppColors.white,
    secondaryContainer: AppColors.secondarySurface,
    onSecondaryContainer: Color(0xFF0369A1),
    tertiary: AppColors.accent,
    onTertiary: AppColors.white,
    tertiaryContainer: Color(0xFFEEF2FF),
    onTertiaryContainer: Color(0xFF4338CA),
    error: AppColors.error,
    onError: AppColors.white,
    errorContainer: AppColors.errorLight,
    onErrorContainer: Color(0xFFB91C1C),
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.grey100,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.grey300,
    outlineVariant: AppColors.grey200,
    shadow: AppColors.black,
    scrim: AppColors.black,
    inverseSurface: AppColors.grey900,
    onInverseSurface: AppColors.white,
    inversePrimary: AppColors.primaryLight,
  );

  static const ColorScheme _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.primaryLight,
    onPrimary: AppColors.white,
    primaryContainer: AppColors.primaryDark,
    onPrimaryContainer: AppColors.primarySurface,
    secondary: AppColors.secondaryLight,
    onSecondary: Color(0xFF0C4A6E),
    secondaryContainer: Color(0xFF0369A1),
    onSecondaryContainer: AppColors.secondarySurface,
    tertiary: Color(0xFF818CF8),
    onTertiary: Color(0xFF312E81),
    tertiaryContainer: Color(0xFF4338CA),
    onTertiaryContainer: Color(0xFFEEF2FF),
    error: Color(0xFFFCA5A5),
    onError: Color(0xFF7F1D1D),
    errorContainer: Color(0xFF991B1B),
    onErrorContainer: AppColors.errorLight,
    surface: AppColors.surfaceDark,
    onSurface: AppColors.white,
    surfaceContainerHighest: AppColors.surfaceVariantDark,
    onSurfaceVariant: AppColors.grey300,
    outline: AppColors.grey600,
    outlineVariant: AppColors.grey700,
    shadow: AppColors.black,
    scrim: AppColors.black,
    inverseSurface: AppColors.grey100,
    onInverseSurface: AppColors.grey900,
    inversePrimary: AppColors.primary,
  );
}
