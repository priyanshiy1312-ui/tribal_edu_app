import 'package:flutter/material.dart';

class AppColors {
  static const orange = Color(0xFFF08A1F);
  static const orangeDark = Color(0xFFE8600C);
  static const green = Color(0xFF4CAF50);
  static const greenDark = Color(0xFF2E7D32);
  static const blue = Color(0xFF29ABE2);
  static const navy = Color(0xFF173A63);
  static const background = Color(0xFFF7F8FA);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.orange,
        primary: AppColors.orange,
        secondary: AppColors.green,
        tertiary: AppColors.blue,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shadowColor: Colors.black26,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: AppColors.orange,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: AppColors.navy),
      ),
    );
  }
}

