import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _forest = Color(0xFF255C57);
  static const _paper = Color(0xFFF7F4EE);
  static const _ink = Color(0xFF17201B);

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _forest,
      brightness: Brightness.light,
      surface: _paper,
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _paper,
      fontFamily: 'Georgia',
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: _ink,
          fontSize: 34,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
        titleLarge: TextStyle(
          color: _ink,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: _ink, fontSize: 16, height: 1.5),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: TextStyle(color: _ink.withValues(alpha: 0.48)),
        contentPadding: const EdgeInsets.all(20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFC8BDA7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFC8BDA7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _forest, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _forest,
          foregroundColor: Colors.white,
          minimumSize: const Size(112, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Color(0xFFFFFBF4),
        indicatorColor: Color(0xFFDCE9E5),
        selectedIconTheme: IconThemeData(color: _forest),
        selectedLabelTextStyle: TextStyle(
          color: _forest,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}