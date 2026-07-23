import 'package:flutter/material.dart';

class AppTheme {
  // Theme Colors
  static const Color background = Color(0xFF0C0F14); // Deep Midnight Blue
  static const Color surface = Color(0xFF1E222B);    // Elevated Card surface
  static const Color accent = Color(0xFFE50914);     // Cinematic Red (like Netflix)
  static const Color secondaryAccent = Color(0xFFFFB800); // Premium Gold for ratings
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8A8E99);

  // Gradient definitions for glassmorphic elements
  static const LinearGradient cardGradient = LinearGradient(
    colors: [
      Color(0x1F2A303E),
      Color(0x0D1E222B),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Universal Ambient Backdrop Gradient (Indigo to Charcoal)
  static const RadialGradient backgroundGradient = RadialGradient(
    center: Alignment(-0.3, -0.5),
    radius: 1.6,
    colors: [
      Color(0xFF1C2230), // Cosmic Navy Indigo
      Color(0xFF090B0F), // Deep Midnight Charcoal
    ],
  );

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: Colors.transparent, // transparent to show ambient gradient
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: secondaryAccent,
        surface: surface,
        error: Colors.redAccent,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textSecondary,
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
