import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// DİKKAT: TEMPORARY / PLACEHOLDER TEMA YAPISI
///
/// Nihai tasarım kararları kullanıcı tarafından verilecektir.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surfaceLight,
      ),
      scaffoldBackgroundColor: AppColors.backgroundLight,
      textTheme: const TextTheme(
        displayLarge: AppTypography.displayLarge,
        displayMedium: AppTypography.displayMedium,
        titleLarge: AppTypography.headline,
        titleMedium: AppTypography.titleMedium,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        labelSmall: AppTypography.labelSmall,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surfaceDark,
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark,
      textTheme: const TextTheme(
        displayLarge: AppTypography.displayLarge,
        displayMedium: AppTypography.displayMedium,
        titleLarge: AppTypography.headline,
        titleMedium: AppTypography.titleMedium,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        labelSmall: AppTypography.labelSmall,
      ),
    );
  }
}
