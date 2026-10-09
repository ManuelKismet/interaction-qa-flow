import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _forest = Color(0xFF255C57);
  static const _paper = Color(0xFFF7F4EE);
  static const _ink = Color(0xFF17201B);

  /// Compact visible controls on phones without changing accessibility scaling.
  static Widget responsiveBuilder(BuildContext context, Widget? child) {
    final width = MediaQuery.sizeOf(context).width;
    final base = Theme.of(context);
    if (width >= 600) return child ?? const SizedBox.shrink();
    final small = width < 380;
    final textTheme = base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontSize: small ? 26 : 28,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(fontSize: 22),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: small ? 18 : 20,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 15, height: 1.4),
    );
    // Keep 48 logical pixels for taps; save space in labels and horizontal padding.
    final compactButton = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: small ? 12 : 16, vertical: 8),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      tapTargetSize: MaterialTapTargetSize.padded,
    );
    return Theme(
      data: base.copyWith(
        textTheme: textTheme,
        iconTheme: base.iconTheme.copyWith(size: 20),
        appBarTheme: base.appBarTheme.copyWith(
          titleTextStyle: textTheme.titleLarge,
        ),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          contentPadding: EdgeInsets.symmetric(
            horizontal: small ? 12 : 14,
            vertical: 14,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: base.elevatedButtonTheme.style?.merge(compactButton),
        ),
        filledButtonTheme: FilledButtonThemeData(style: compactButton),
        outlinedButtonTheme: OutlinedButtonThemeData(style: compactButton),
        textButtonTheme: TextButtonThemeData(style: compactButton),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            iconSize: 20,
            minimumSize: const Size(48, 48),
          ),
        ),
        navigationBarTheme: base.navigationBarTheme.copyWith(
          height:
              64 +
              (MediaQuery.textScalerOf(context).scale(12) - 12).clamp(
                    0.0,
                    double.infinity,
                  ) *
                  2,
          labelBehavior: small
              ? NavigationDestinationLabelBehavior.onlyShowSelected
              : NavigationDestinationLabelBehavior.alwaysShow,
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }

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
