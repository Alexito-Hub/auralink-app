import 'package:flutter/material.dart';
import 'app_colors.dart';
class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primaryLight,
      scaffoldBackgroundColor: AppColors.bgLight,
      fontFamily: 'monospace',
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryLight,
        secondary: AppColors.accentLight,
        surface: AppColors.surfaceLight,
        onSurface: AppColors.textLight,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: AppColors.textLight.withValues(alpha: 0.05)),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -1, color: AppColors.textLight),
        titleLarge: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textLight),
        bodyMedium: TextStyle(color: AppColors.textLight, fontSize: 13),
      ),
    );
  }
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primaryDark,
      scaffoldBackgroundColor: AppColors.bgDark,
      fontFamily: 'monospace',
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryDark,
        secondary: AppColors.accentDark,
        surface: AppColors.surfaceDark,
        onSurface: AppColors.textDark,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: AppColors.textDark.withValues(alpha: 0.05)),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -1, color: AppColors.textDark),
        titleLarge: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark),
        bodyMedium: TextStyle(color: AppColors.textDark, fontSize: 13),
      ),
    );
  }
}
