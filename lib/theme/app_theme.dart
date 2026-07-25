import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Theme Colors
  static const Color background = Color(0xFF050408); // Obsidian Black
  static const Color surface = Color(0xFF13111A);    // Midnight Violet surface
  static const Color accent = Color(0xFF00E5FF);     // Premium Neon Teal
  static const Color secondaryAccent = Color(0xFF8B5CF6); // Premium Neon Violet
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E8A99);

  // Gradient definitions for glassmorphic elements
  static const LinearGradient cardGradient = LinearGradient(
    colors: [
      Color(0x1F2A303E),
      Color(0x0D1E222B),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Universal Ambient Backdrop Gradient (Deep Obsidian to Midnight Violet)
  static const RadialGradient backgroundGradient = RadialGradient(
    center: Alignment(0.0, -0.3),
    radius: 1.5,
    colors: [
      Color(0xFF0E0C16), // Midnight Violet
      Color(0xFF050408), // Deep Obsidian
    ],
  );

  static BoxDecoration glassDecoration({
    double radius = 16,
    double opacity = 0.08,
    Color borderColor = Colors.white12,
  }) {
    return BoxDecoration(
      color: Colors.white.withAlpha((opacity * 255).toInt()),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: 1),
    );
  }

  static ThemeData get darkTheme {
    final baseTheme = ThemeData.dark();
    return baseTheme.copyWith(
      scaffoldBackgroundColor: Colors.transparent, // transparent to show ambient gradient
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: secondaryAccent,
        surface: surface,
        error: Colors.redAccent,
      ),
      textTheme: GoogleFonts.outfitTextTheme(baseTheme.textTheme).copyWith(
        headlineLarge: GoogleFonts.outfit(
          textStyle: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        headlineMedium: GoogleFonts.outfit(
          textStyle: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        titleLarge: GoogleFonts.outfit(
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        bodyLarge: GoogleFonts.outfit(
          textStyle: const TextStyle(
            fontSize: 16,
            color: textPrimary,
          ),
        ),
        bodyMedium: GoogleFonts.outfit(
          textStyle: const TextStyle(
            fontSize: 14,
            color: textSecondary,
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 4,
        margin: EdgeInsets.all(8),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: accent,
        thumbColor: accent,
        inactiveTrackColor: Colors.white24,
      ),
    );
  }
}
