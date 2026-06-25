import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // New Color System
  static const Color primaryColor = Color(0xFF0F9D8A); // Premium Teal
  static const Color secondaryColor = Color(0xFF14CBA8); // Mint Green
  static const Color accentColor = Color(0xFF0F9D8A);
  
  static const Color backgroundColor = Color(0xFFF8FAFC); // Slate-50 Background
  static const Color cardColor = Colors.white; // Pure White Cards
  
  static const Color lightBackgroundColor = Color(0xFFF8FAFC);
  static const Color lightCardColor = Colors.white;
  static const Color darkBackgroundColor = Color(0xFFF8FAFC);
  static const Color darkCardColor = Colors.white;

  // Semantic Colors
  static const Color textPrimaryColor = Color(0xFF111827); // Dark Charcoal
  static const Color textSecondaryColor = Color(0xFF6B7280); // Medium Grey
  static const Color successColor = Color(0xFF22C55E); // Success Green
  static const Color warningColor = Color(0xFFF59E0B); // Warning Amber
  static const Color errorColor = Color(0xFFEF4444); // Error Red

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBackgroundColor,
    cardColor: lightCardColor,
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: lightCardColor,
      error: errorColor,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: lightBackgroundColor,
      elevation: 0,
      iconTheme: IconThemeData(color: textPrimaryColor),
      titleTextStyle: TextStyle(color: textPrimaryColor, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
      headlineLarge: GoogleFonts.inter(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        color: textPrimaryColor,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: textPrimaryColor,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        color: textSecondaryColor,
      ),
    ),
  );

  static final ThemeData darkTheme = lightTheme; // Enforce clean light theme globally

  static BoxDecoration gradientDecoration = const BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFFEFFDFB), Color(0xFFF8FAFC)], // Minimal mint tint to clean background slate
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );

  static BoxDecoration glassCardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16), // Consistent 16px radius
    border: Border.all(
      color: Colors.black.withOpacity(0.04), // Ultra soft border
      width: 1.0,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.02), // Soft shadow
        blurRadius: 16,
        offset: const Offset(0, 8),
      ),
    ],
  );

  static BoxDecoration neonBorderDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16), // Consistent 16px radius
    border: Border.all(
      color: const Color(0xFF0F9D8A).withOpacity(0.2), // Soft primary glow border
      width: 1.0,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF0F9D8A).withOpacity(0.03),
        blurRadius: 12,
        spreadRadius: 1,
      ),
    ],
  );
}
