import 'package:flutter/material.dart';

class AppColors {
  static const background = Colors.white;
  static const surface = Colors.white;
  static const line = Color(0xFFE5E7EB);
  static const text = Color(0xFF1F2937);
  static const muted = Color(0xFF8A94A3);
  static const accent = Color(0xFF6D35E8);
  static const accentSoft = Color(0xFFF2EDFF);
  static const accentLine = Color(0xFFD8CBFF);
  static const danger = Color(0xFFE74C3C);
  static const dangerSoft = Color(0xFFFFF4F2);
  static const green = Color(0xFF2FB477);
  static const goldSoft = Color(0xFFFFF7DF);
  static const note = Color(0xFFFFF4C2);
  static const noteLine = Color(0xFFF59E0B);
}

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        primary: AppColors.accent,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: null,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45),
        bodySmall: TextStyle(fontSize: 12, height: 1.45),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
