import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Hues
  static const Color primary = Color(0xFF4F46E5); // Indigo 600
  static const Color primaryDark = Color(0xFF3730A3);
  static const Color primaryLight = Color(0xFFEEF2FF);
  
  static const Color background = Color(0xFFF8FAFC); // Slate 50
  static const Color surface = Colors.white;
  static const Color surfaceSubtle = Color(0xFFF1F5F9);
  
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400
  
  static const Color borderSubtle = Color(0xFFE2E8F0); // Slate 200
  static const Color borderStrong = Color(0xFFCBD5E1); // Slate 300

  // Status colors
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color successLight = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color danger = Color(0xFFEF4444); // Red
  static const Color dangerLight = Color(0xFFFEF2F2);
  static const Color info = Color(0xFF06B6D4); // Cyan
  static const Color infoLight = Color(0xFFECFEFF);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.light(
      primary: primary,
      secondary: primaryDark,
      surface: surface,
      error: danger,
      onPrimary: Colors.white,
      onSurface: textPrimary,
    ),
    textTheme: GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
        color: textPrimary,
        fontWeight: FontWeight.w800,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        color: textPrimary,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        color: textPrimary,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: GoogleFonts.inter(
        color: textPrimary,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: GoogleFonts.inter(
        color: textSecondary,
        fontWeight: FontWeight.w400,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      foregroundColor: textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: borderSubtle, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textPrimary,
        side: const BorderSide(color: borderSubtle),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
    ),
  );
}
