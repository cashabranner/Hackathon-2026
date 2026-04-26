import 'package:flutter/material.dart';

class AppTheme {
  static const _seed = Color(0xFF14B8A6); // teal-500

  // Brand palette
  static const emerald = Color(0xFF34D399);
  static const teal = Color(0xFF14B8A6);
  static const tealDark = Color(0xFF0F766E);
  static const indigo = Color(0xFF4F46E5);
  static const purple = Color(0xFF7C3AED);
  static const amber = Color(0xFFF59E0B);
  static const coral = Color(0xFFF43F5E);
  static const slate = Color(0xFF111827);
  static const gray700 = Color(0xFF374151);
  static const gray600 = Color(0xFF4B5563);
  static const gray500 = Color(0xFF6B7280);
  static const gray200 = Color(0xFFE5E7EB);
  static const surface = Color(0xFFF8FAFC);
  static const surfaceCard = Colors.white;
  static const indigoBorder = Color(0xFFE0E7FF);
  static const inputFill = Color(0xFFF9FAFB);

  static const pageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFEFF6FF),
      Color(0xFFEEF2FF),
      Color(0xFFFAF5FF),
    ],
  );

  static const brandGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [emerald, teal],
  );

  static const indigoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [indigo, purple],
  );

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: Brightness.light,
        surface: surface,
        onSurface: slate,
      ),
      scaffoldBackgroundColor: surface,
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: indigoBorder),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: slate,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: slate,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: gray200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: gray200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: emerald, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: teal,
        inactiveTrackColor: gray200,
        thumbColor: teal,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: teal,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: teal,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      textTheme: base.textTheme.copyWith(
        headlineLarge: const TextStyle(
            color: slate,
            fontWeight: FontWeight.w600,
            fontSize: 30,
            height: 1.2),
        headlineMedium: const TextStyle(
            color: slate,
            fontWeight: FontWeight.w600,
            fontSize: 24,
            height: 1.25),
        titleLarge: const TextStyle(
            color: slate, fontWeight: FontWeight.w600, fontSize: 20),
        titleMedium: const TextStyle(
            color: slate, fontWeight: FontWeight.w600, fontSize: 16),
        bodyLarge: const TextStyle(color: gray600, fontSize: 15, height: 1.45),
        bodyMedium: const TextStyle(color: gray600, fontSize: 14, height: 1.4),
        labelLarge: const TextStyle(
            color: slate, fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }

  static ThemeData get dark => light;
}
