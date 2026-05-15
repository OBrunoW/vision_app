import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const Color identityBlueBright = Color(0xFF2563EB);
  static const Color identityMint = Color(0xFF34D399);
  static const Color identitySky = Color(0xFF93C5FD);

  static const Color _gptLightBg = Color(0xFFFFFFFF);
  static const Color _gptLightSurface = Color(0xFFF7F7F8);
  static const Color _gptLightOnSurface = Color(0xFF202123);
  static const Color _gptLightOutline = Color(0xFFECECEC);

  static const Color _gptDarkBg = Color(0xFF0F172A);
  static const Color _gptDarkSurface = Color(0xFF0F172A);
  static const Color _gptDarkOnSurface = Color(0xFFECECEC);
  static const Color _gptDarkOutline = Color(0xFF334155);

  static ThemeData light() {
    final base = ColorScheme.fromSeed(
      seedColor: identityBlueBright,
      brightness: Brightness.light,
      primary: identityBlueBright,
      onPrimary: Colors.white,
      secondary: identityMint,
      onSecondary: Color(0xFF042F2E),
      surface: _gptLightSurface,
      onSurface: _gptLightOnSurface,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: base.copyWith(
        surfaceContainerHighest: _gptLightOutline,
        outline: _gptLightOutline,
      ),
      scaffoldBackgroundColor: _gptLightBg,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _gptLightBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _gptLightOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _gptLightOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: identityBlueBright, width: 1.5),
        ),
        labelStyle: const TextStyle(color: Color(0xFF6B7280)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: identityBlueBright,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: identityBlueBright),
      ),
    );
  }

  static ThemeData dark() {
    final base = ColorScheme.fromSeed(
      seedColor: identityBlueBright,
      brightness: Brightness.dark,
      primary: identitySky,
      onPrimary: Color(0xFF0F172A),
      secondary: identityMint,
      onSecondary: Color(0xFF022C22),
      surface: _gptDarkSurface,
      onSurface: _gptDarkOnSurface,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: base.copyWith(
        surfaceContainerHighest: _gptDarkOutline,
        outline: _gptDarkOutline,
      ),
      scaffoldBackgroundColor: _gptDarkBg,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _gptDarkOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _gptDarkOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: identitySky, width: 1.5),
        ),
        labelStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: identityBlueBright,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: identitySky),
      ),
    );
  }
}
