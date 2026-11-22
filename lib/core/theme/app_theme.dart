import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../constants/app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme => _build(
    brightness: Brightness.dark,
    background: AppColors.background,
    surface: AppColors.darkSurface,
    card: AppColors.card,
    text: AppColors.textPrimary,
    textMuted: AppColors.textSecondary,
  );

  static ThemeData get lightTheme => _build(
    brightness: Brightness.light,
    background: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    card: AppColors.lightCard,
    text: AppColors.lightTextPrimary,
    textMuted: AppColors.lightTextSecondary,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color card,
    required Color text,
    required Color textMuted,
  }) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.primaryStart,
      onPrimary: AppColors.white,
      secondary: AppColors.accent,
      onSecondary: AppColors.dark,
      error: AppColors.danger,
      onError: AppColors.white,
      surface: background,
      onSurface: text,
      onSurfaceVariant: textMuted,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: card,
      surfaceContainerHighest: dark ? const Color(0xFF2A3546) : const Color(0xFFE4E9F0),
      outlineVariant: dark ? const Color(0xFF2C3848) : const Color(0xFFD5DCE6),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(color: text, fontSize: 24, fontWeight: FontWeight.w800),
        titleLarge: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(color: text, fontSize: 16),
        bodyMedium: TextStyle(color: textMuted, fontSize: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: AppColors.primaryStart,
        labelStyle: TextStyle(color: text),
        secondaryLabelStyle: const TextStyle(color: AppColors.white),
        checkmarkColor: AppColors.white,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: dark ? 0 : 1,
        shadowColor: Colors.black12,
      ),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: surface, surfaceTintColor: Colors.transparent),
      dialogTheme: DialogThemeData(backgroundColor: surface, surfaceTintColor: Colors.transparent),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: background,
        selectedItemColor: AppColors.primaryStart,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
      ),
      iconTheme: IconThemeData(color: text),
    );
  }
}

/// Theme-aware colors for widgets. Use these instead of fixed dark colors.
extension AppThemeColors on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  Color get textPrimary => colors.onSurface;
  Color get textSecondary => colors.onSurfaceVariant;
  Color get cardColor => colors.surfaceContainerHigh;
  Color get surfaceColor => colors.surfaceContainer;

  /// Background for missing images; stands out from cards in both themes.
  Color get placeholderColor => colors.surfaceContainerHighest;
}
