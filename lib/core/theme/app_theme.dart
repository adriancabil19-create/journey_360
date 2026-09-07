import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Builds the light and dark [ThemeData] for Journey360's glassmorphic UI.
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.accent,
        brightness: brightness,
      ).copyWith(surface: c.surface),
      extensions: [c],
    );

    final textColor = c.onSurface;
    return base.copyWith(
      // A clearly visible keyboard-focus highlight for InkWell-based controls.
      focusColor: c.accent.withValues(alpha: 0.30),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textColor,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: c.accentSoft,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceHigh,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(color: c.glassBorder, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.onSurface,
        contentTextStyle: TextStyle(color: c.surface),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        hintStyle: TextStyle(color: c.onSurfaceMuted),
        labelStyle: TextStyle(color: c.onSurfaceMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.accent, width: 1.6),
        ),
      ),
      textTheme: base.textTheme
          .apply(bodyColor: textColor, displayColor: textColor)
          .copyWith(
            displaySmall: TextStyle(
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: -0.5,
            ),
            headlineSmall: TextStyle(
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
            titleLarge: TextStyle(
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
            titleMedium: TextStyle(
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
            bodyMedium: TextStyle(color: c.onSurfaceMuted, height: 1.4),
            labelLarge: TextStyle(
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
    );
  }
}
