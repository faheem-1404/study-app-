import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0E4D45),
      brightness: Brightness.light,
    ).copyWith(
      primary: const Color(0xFF0E4D45),
      onPrimary: Colors.white,
      secondary: const Color(0xFFD97D2B),
      onSecondary: Colors.white,
      tertiary: const Color(0xFF145E6D),
      surface: const Color(0xFFFFFBF6),
      surfaceContainerHighest: const Color(0xFFF6EBDD),
      outline: const Color(0xFFBFAF9D),
      outlineVariant: const Color(0xFFE5D8C8),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF9F3EB),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface.withValues(alpha: 0.82),
        foregroundColor: scheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFFFCF8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      textTheme: Typography.material2021().black.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
    );
  }

  static ThemeData get darkTheme {
    const Color goldAccent = Color(0xFFD4AF37);
    const Color darkBg = Color(0xFF0D0D0D);
    const Color cardBg = Color(0xFF1A1A1A);
    const Color successGreen = Color(0xFF4CAF50);
    const Color alertRed = Color(0xFFFF4C4C);
    const Color silverText = Color(0xFFC0C0C0);

    final ColorScheme scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: goldAccent,
      onPrimary: darkBg,
      secondary: successGreen,
      onSecondary: darkBg,
      tertiary: alertRed,
      onTertiary: Colors.white,
      surface: cardBg,
      onSurface: silverText,
      surfaceContainerHighest: const Color(0xFF2A2A2A),
      outline: const Color(0xFF444444),
      outlineVariant: const Color(0xFF2A2A2A),
      error: alertRed,
      onError: Colors.white,
      scrim: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: darkBg,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: cardBg,
        foregroundColor: goldAccent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: goldAccent,
          foregroundColor: darkBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          foregroundColor: goldAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          side: const BorderSide(color: goldAccent),
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: goldAccent, width: 1.5),
        ),
      ),
      textTheme: Typography.material2021().white.apply(
            bodyColor: silverText,
            displayColor: goldAccent,
          ),
    );
  }
}