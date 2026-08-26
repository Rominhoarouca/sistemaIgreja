import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../colors/app_colors.dart';
import '../typography/app_typography.dart';
import '../spacing/app_spacing.dart';

/// Design System — Material 3 Theme Configuration
/// Direção visual "premium e sóbria" (azul profundo #1E3A8A), light e dark.
abstract final class AppTheme {
  static ThemeData get light => _buildTheme(Brightness.light);
  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = isDark ? _darkColorScheme : _lightColorScheme;

    // Cor de destaque interativa: primary no light, azul acessível no dark.
    final accent = isDark ? AppColors.primaryLight : AppColors.primary;
    final textColor = isDark ? AppColors.textDark : AppColors.textPrimary;
    final borderColor = isDark ? AppColors.dividerDark : AppColors.border;
    final inputBorder = isDark ? AppColors.dividerDark : AppColors.borderInput;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: AppTypography.bodyMedium.fontFamily,

      // ── Scaffold ────────────────────────────────────────────────────────
      scaffoldBackgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.background,

      // ── AppBar (topbar 68px, fundo surface) ─────────────────────────────
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        toolbarHeight: AppSpacing.topbarHeight,
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
        foregroundColor: textColor,
        titleTextStyle: AppTypography.titleLarge.copyWith(color: textColor),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(
          color: isDark ? AppColors.text2Dark : AppColors.grey700,
          size: AppSpacing.iconMd,
        ),
        shape: Border(bottom: BorderSide(color: borderColor)),
      ),

      // ── Cards (raio 16, borda sutil, sombra leve) ───────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(color: borderColor, width: 1),
        ),
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        margin: EdgeInsets.zero,
      ),

      // ── Elevated Button (primário #1E3A8A, hover #16307A, Sora) ─────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: accent,
              foregroundColor: AppColors.white,
              disabledBackgroundColor: isDark
                  ? AppColors.chipDark
                  : AppColors.grey200,
              disabledForegroundColor: isDark
                  ? AppColors.mutedDark
                  : AppColors.grey400,
              minimumSize: const Size.fromHeight(AppSpacing.buttonHeightMd),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              textStyle: AppTypography.buttonLabel,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.md,
              ),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.pressed)) {
                  return isDark
                      ? AppColors.white.withValues(alpha: .08)
                      : AppColors.primaryHover.withValues(alpha: .6);
                }
                return null;
              }),
            ),
      ),

      // ── Outlined Button ─────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? AppColors.linkDark : AppColors.primary,
          minimumSize: const Size.fromHeight(AppSpacing.buttonHeightMd),
          side: BorderSide(
            color: isDark ? AppColors.primaryLight : inputBorder,
          ),
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
          foregroundColor: isDark ? AppColors.linkDark : AppColors.primary,
          textStyle: AppTypography.buttonLabel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
      ),

      // ── Input Decoration (borda #D0D5DD, foco #1E3A8A) ──────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.surfaceVariantDark : AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: isDark ? AppColors.text3Dark : AppColors.grey600,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: isDark ? AppColors.mutedDark : AppColors.textMuted,
        ),
        errorStyle: AppTypography.labelSmall.copyWith(color: AppColors.error),
      ),

      // ── Divider ─────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.borderSoftDark : AppColors.borderSoft,
        thickness: 1,
        space: 1,
      ),

      // ── Bottom Navigation Bar (82px) ────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: AppSpacing.bottomNavHeight,
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
        indicatorColor: isDark ? AppColors.chipDark : AppColors.chip,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
              color: isDark ? AppColors.linkDark : AppColors.primary,
              size: AppSpacing.iconMd,
            );
          }
          return IconThemeData(
            color: isDark ? AppColors.text3Dark : AppColors.grey500,
            size: AppSpacing.iconMd,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.labelSmall.copyWith(
              color: isDark ? AppColors.linkDark : AppColors.primary,
              fontWeight: FontWeight.w600,
            );
          }
          return AppTypography.labelSmall.copyWith(
            color: isDark ? AppColors.text3Dark : AppColors.grey500,
          );
        }),
      ),

      // ── Chips (pill, seleção azul) ──────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? AppColors.surfaceVariantDark
            : AppColors.grey50,
        selectedColor: isDark ? AppColors.chipDark : AppColors.chip,
        // Cor explícita: sem ela o rótulo herdava um cinza claro que, sobre o
        // fundo também claro do chip não-selecionado, ficava ilegível.
        labelStyle: AppTypography.labelMedium.copyWith(color: textColor),
        secondaryLabelStyle: AppTypography.labelMedium.copyWith(
          color: isDark ? AppColors.linkDark : AppColors.primary,
        ),
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
      ),

      // ── Dialog (modal raio 18) ──────────────────────────────────────────
      dialogTheme: DialogThemeData(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
        titleTextStyle: AppTypography.titleLarge.copyWith(color: textColor),
        barrierColor: AppColors.modalOverlay,
      ),

      // ── Bottom sheet (mobile) ───────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
        modalBackgroundColor: isDark
            ? AppColors.surfaceDark
            : AppColors.surface,
        modalBarrierColor: AppColors.modalOverlay,
        showDragHandle: true,
        dragHandleColor: isDark ? AppColors.dividerDark : AppColors.grey300,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl2),
          ),
        ),
      ),

      // ── SnackBar (toast) ────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.chipDark : AppColors.grey900,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Progress Indicator ───────────────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: isDark ? AppColors.chipDark : AppColors.chip,
        circularTrackColor: isDark ? AppColors.chipDark : AppColors.chip,
      ),

      // ── Tab bar (abas segmentadas) ──────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: isDark ? AppColors.linkDark : AppColors.primary,
        unselectedLabelColor: isDark
            ? AppColors.text3Dark
            : AppColors.textTertiary,
        labelStyle: AppTypography.labelLarge,
        unselectedLabelStyle: AppTypography.labelLarge.copyWith(
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: accent,
        dividerColor: borderColor,
      ),

      // ── Text Theme ──────────────────────────────────────────────────────
      textTheme: TextTheme(
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
      ).apply(bodyColor: textColor, displayColor: textColor),
    );
  }

  static const ColorScheme _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.white,
    primaryContainer: AppColors.chip,
    onPrimaryContainer: AppColors.primary,
    secondary: AppColors.secondary,
    onSecondary: AppColors.white,
    secondaryContainer: AppColors.chip2,
    onSecondaryContainer: AppColors.primary,
    tertiary: AppColors.gold,
    onTertiary: AppColors.navy900,
    tertiaryContainer: AppColors.warningLight,
    onTertiaryContainer: AppColors.warning,
    error: AppColors.error,
    onError: AppColors.white,
    errorContainer: AppColors.errorLight,
    onErrorContainer: Color(0xFFB42318),
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.grey100,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.borderInput,
    outlineVariant: AppColors.borderContainer,
    shadow: AppColors.black,
    scrim: AppColors.modalOverlay,
    inverseSurface: AppColors.grey900,
    onInverseSurface: AppColors.white,
    inversePrimary: AppColors.linkDark,
  );

  static const ColorScheme _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.primaryLight,
    onPrimary: AppColors.white,
    primaryContainer: AppColors.chipDark,
    onPrimaryContainer: AppColors.linkDark,
    secondary: AppColors.chartBlue,
    onSecondary: AppColors.navy900,
    secondaryContainer: AppColors.chip2Dark,
    onSecondaryContainer: AppColors.linkDark,
    tertiary: AppColors.gold,
    onTertiary: AppColors.navy900,
    tertiaryContainer: AppColors.warningDarkBg,
    onTertiaryContainer: AppColors.warningDarkFg,
    error: AppColors.errorDarkFg,
    onError: AppColors.errorDarkBg,
    errorContainer: AppColors.errorDarkBg,
    onErrorContainer: AppColors.errorDarkFg,
    surface: AppColors.surfaceDark,
    onSurface: AppColors.textDark,
    surfaceContainerHighest: AppColors.chipDark,
    onSurfaceVariant: AppColors.text2Dark,
    outline: AppColors.dividerDark,
    outlineVariant: AppColors.borderSoftDark,
    shadow: AppColors.black,
    scrim: AppColors.modalOverlay,
    inverseSurface: AppColors.grey100,
    onInverseSurface: AppColors.grey900,
    inversePrimary: AppColors.primary,
  );
}
