import 'package:flutter/material.dart';

class AppTheme {
  // Modern Monochrome Cockpit Palette
  // Deep matte obsidian black - zero backlight bleed at night, infinite OLED contrast
  static const Color background = Color(0xFF0C0D10);
  static const Color surface = Color(0xFF14171E);
  static const Color surfaceElevated = Color(0xFF1D222A);
  static const Color border = Color(0xFF2C323E);

  // Modern Monochrome Accents
  // Platinum / Crisp Pure White for active numbers, gauges, icons & daylight legibility
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color platinumWhite = Color(0xFFF1F5F9);
  static const Color silver = Color(0xFFCBD5E1);
  static const Color slateLight = Color(0xFF94A3B8);

  // Accent mappings migrated to Monochrome (removes glaring neon blues & greens at night)
  static const Color neonCyan = Color(0xFFFFFFFF); // Crisp platinum white
  static const Color neonBlue = Color(0xFFCBD5E1); // Refined silver
  static const Color electricGreen = Color(0xFFE2E8F0); // Subtle platinum highlight
  static const Color warningOrange = Color(0xFFE2E8F0); // Neutral silver (or safety highlight)
  static const Color alertRed = Color(0xFFEF4444); // Retained exclusively for safety alerts (overspeed)
  static const Color neonPurple = Color(0xFF94A3B8); // Slate accent
  static const Color pinkAccent = Color(0xFFCBD5E1);

  // Text Colors (High daylight contrast, zero night glare)
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF64748B);

  // Soft Ambient Diffused Shadows (Anti-glare: replaces glaring neon blur)
  static List<BoxShadow> cyanGlow([double blur = 8, double spread = 0]) => [
        BoxShadow(
          color: Colors.white.withOpacity(0.08),
          blurRadius: blur,
          spreadRadius: spread,
        ),
      ];

  static List<BoxShadow> redGlow([double blur = 10, double spread = 0]) => [
        BoxShadow(
          color: alertRed.withOpacity(0.3),
          blurRadius: blur,
          spreadRadius: spread,
        ),
      ];

  static List<BoxShadow> greenGlow([double blur = 8, double spread = 0]) => [
        BoxShadow(
          color: Colors.white.withOpacity(0.08),
          blurRadius: blur,
          spreadRadius: spread,
        ),
      ];

  static List<BoxShadow> purpleGlow([double blur = 8, double spread = 0]) => [
        BoxShadow(
          color: Colors.white.withOpacity(0.08),
          blurRadius: blur,
          spreadRadius: spread,
        ),
      ];

  // Glassmorphic Panel Decoration (Matte Titanium Slate)
  static BoxDecoration glassCard({
    Color? borderColor,
    double radius = 14,
    Color? fillColor,
  }) {
    return BoxDecoration(
      color: fillColor ?? surface.withOpacity(0.92),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? border.withOpacity(0.7),
        width: 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.55),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // Material Theme Data
  static ThemeData get themeData {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: background,
      primaryColor: pureWhite,
      cardColor: surface,
      colorScheme: const ColorScheme.dark(
        primary: pureWhite,
        secondary: silver,
        surface: surface,
        error: alertRed,
        onPrimary: Colors.black,
        onSurface: textPrimary,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(
          color: textSecondary,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          color: textMuted,
          fontSize: 12,
        ),
      ),
    );
  }
}

