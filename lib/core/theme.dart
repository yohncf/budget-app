import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Vibrant custom color palette
  static const Color darkBackground = Color(0xFF09090B);
  static const Color darkCard = Color(0xFF141417);
  static const Color mainAction = Color(0xFF80C000);
  static const Color secondaryColor = Color(0xFF4D0097);

  static const Color primaryPurple = mainAction;
  static const Color accentCyan = Color(0xFF01FFFF);

  static const Color successGreen = Color(0xFF10B981);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color dangerRed = Color(0xFFEF4444);
  static const Color textPrimary = Color(0xFFF3F4F6);
  static const Color textSecondary = Color(0xFF9CA3AF);

  // Vibrant, distinct colors for categories in dark mode
  static const List<Color> categoryColors = [
    Color(0xFF8B5CF6), // Purple
    Color(0xFF3B82F6), // Blue
    Color(0xFF10B981), // Emerald Green
    Color(0xFFF59E0B), // Amber Orange
    Color(0xFFEF4444), // Red
    Color(0xFFEC4899), // Pink
    Color(0xFF06B6D4), // Cyan
    Color(0xFF84CC16), // Lime Green
    Color(0xFFEAB308), // Yellow
    Color(0xFF6366F1), // Indigo
    Color(0xFFD946EF), // Magenta
    Color(0xFF14B8A6), // Teal
    Color(0xFFF97316), // Orange
    Color(0xFF059669), // Green
    Color(0xFF4F46E5), // Dark Indigo
    Color(0xFFDB2777), // Dark Pink
  ];

  // Premium Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [mainAction, Color(0xFF5E8C00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [secondaryColor, Color(0xFF2E0062)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [darkBackground, Color(0xFF040405)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF18181F), Color(0xFF0F0F12)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: mainAction,
      scaffoldBackgroundColor: darkBackground,
      cardColor: darkCard,
      textTheme: TextTheme(
        displayLarge: GoogleFonts.outfit(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: GoogleFonts.outfit(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.normal,
        ),
        bodyMedium: GoogleFonts.inter(
          color: textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF23232A), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1D1D22),
        hintStyle: const TextStyle(color: textSecondary),
        labelStyle: const TextStyle(color: textPrimary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF23232A), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: mainAction, width: 2),
        ),
      ),
      colorScheme: const ColorScheme.dark(
        primary: mainAction,
        secondary: secondaryColor,
        surface: darkCard,
        error: dangerRed,
      ),
    );
  }
}

