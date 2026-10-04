import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static TextTheme _buildTextTheme(TextTheme base) {
    return GoogleFonts.outfitTextTheme(base).copyWith(
      displayLarge: GoogleFonts.outfit(
          fontSize: 32, fontWeight: FontWeight.bold),
      displayMedium: GoogleFonts.outfit(
          fontSize: 28, fontWeight: FontWeight.bold),
      displaySmall: GoogleFonts.outfit(
          fontSize: 24, fontWeight: FontWeight.bold),
      headlineMedium: GoogleFonts.outfit(
          fontSize: 20, fontWeight: FontWeight.w600),
      titleLarge: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: GoogleFonts.outfit(
          fontSize: 16, fontWeight: FontWeight.w500),
      bodyLarge: GoogleFonts.outfit(
          fontSize: 16, fontWeight: FontWeight.normal),
      bodyMedium: GoogleFonts.outfit(
          fontSize: 14, fontWeight: FontWeight.normal),
      labelLarge: GoogleFonts.outfit(
          fontSize: 14, fontWeight: FontWeight.w500),
      labelMedium: GoogleFonts.outfit(
          fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall: GoogleFonts.outfit(
          fontSize: 10, fontWeight: FontWeight.w500),
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF9FAFB),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF4F46E5),
        secondary: Color(0xFF6366F1),
        surface: Color(0xFFFFFFFF),
        error: Color(0xFFEF4444),
        onPrimary: Color(0xFFFFFFFF),
        onSecondary: Color(0xFFFFFFFF),
        onSurface: Color(0xFF111827),
        onError: Color(0xFFFFFFFF),
      ),
      textTheme: _buildTextTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF9FAFB),
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF111827)),
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF6366F1),
        secondary: Color(0xFF4F46E5),
        surface: Color(0xFF1E293B),
        error: Color(0xFFEF4444),
        onPrimary: Color(0xFFF8FAFC),
        onSecondary: Color(0xFFF8FAFC),
        onSurface: Color(0xFFF8FAFC),
        onError: Color(0xFF0F172A),
      ),
      textTheme: _buildTextTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F172A),
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFFF8FAFC)),
      ),
    );
  }
}
