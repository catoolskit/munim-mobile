import 'package:flutter/material.dart';

class MunimTheme {
  static const Color navy       = Color(0xFF0F1F3D);
  static const Color navyHover  = Color(0xFF1B3156);
  static const Color gold       = Color(0xFFF4C430);
  static const Color goldDark   = Color(0xFFD4A820);
  static const Color accent     = Color(0xFF1856A0);
  static const Color bg         = Color(0xFFF4F6FA);
  static const Color card       = Color(0xFFFFFFFF);
  static const Color border     = Color(0xFFE1E6EF);
  static const Color text       = Color(0xFF1B2438);
  static const Color muted      = Color(0xFF6B7690);
  static const Color ok         = Color(0xFF1E8E5A);
  static const Color danger     = Color(0xFFC0392B);

  static ThemeData theme() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        primary: accent,
        secondary: gold,
        background: bg,
        surface: card,
      ),
      scaffoldBackgroundColor: bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18, fontWeight: FontWeight.bold,
          color: Colors.white, letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardTheme(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accent, width: 2),
        ),
        labelStyle: const TextStyle(color: muted, fontSize: 13),
        hintStyle: const TextStyle(color: muted, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
    );
  }

  // Shared card decoration
  static BoxDecoration cardBox({double radius = 12}) => BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border),
  );

  // Label style
  static const TextStyle labelStyle = TextStyle(
    fontSize: 12, color: muted, fontWeight: FontWeight.w500);

  // Value style
  static const TextStyle valueStyle = TextStyle(
    fontSize: 14, color: text, fontWeight: FontWeight.w600);

  // Heading style
  static const TextStyle headingStyle = TextStyle(
    fontSize: 18, color: text, fontWeight: FontWeight.bold);

  // Amount style
  static const TextStyle amountStyle = TextStyle(
    fontSize: 16, color: accent, fontWeight: FontWeight.bold);
}
