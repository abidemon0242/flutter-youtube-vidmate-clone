import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF7F9FC),
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryStart,
      brightness: Brightness.light,
      primary: AppColors.primaryStart,
      secondary: AppColors.accent,
      surface: Colors.white,
      error: AppColors.danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF7F9FC),
      foregroundColor: Color(0xFF1A1A2E),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1A1A2E),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: Color(0xFF1A1A2E),
        fontSize: 24,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: TextStyle(
        color: Color(0xFF1A1A2E),
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(color: Color(0xFF1A1A2E), fontSize: 16),
      bodyMedium: TextStyle(color: Color(0xFF5A6A7A), fontSize: 14),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFE8EEF5),
      selectedColor: AppColors.primaryStart,
      labelStyle: const TextStyle(color: Color(0xFF1A1A2E)),
      secondaryLabelStyle: const TextStyle(color: Colors.white),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 1,
      shadowColor: Colors.black12,
    ),
    iconTheme: const IconThemeData(color: Color(0xFF1A1A2E)),
    dividerTheme: const DividerThemeData(color: Color(0xFFE0E6ED)),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryStart,
      brightness: Brightness.dark,
      primary: AppColors.primaryStart,
      secondary: AppColors.accent,
      surface: AppColors.darkSurface,
      error: AppColors.danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.white,
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(color: AppColors.textPrimary, fontSize: 16),
      bodyMedium: TextStyle(color: AppColors.textSecondary, fontSize: 14),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.card,
      selectedColor: AppColors.primaryStart,
      labelStyle: const TextStyle(color: AppColors.white),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
    ),
    iconTheme: const IconThemeData(color: AppColors.white),
    dividerTheme: const DividerThemeData(color: Color(0xFF2A3545)),
  );
}
