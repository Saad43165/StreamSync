import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Colors ───────────────────────────────────────────────────────────────
  static const Color background = Color(0xFF07070D);    // Obsidian Black
  static const Color surface = Color(0xFF12111C);       // Midnight Violet surface
  static const Color surfaceRaised = Color(0xFF1A1928); // Sheets, dialogs, menus
  static const Color card = Color(0xFF161524);          // Poster/list tiles
  static const Color accent = Color(0xFF00E5FF);        // Neon Teal
  static const Color secondaryAccent = Color(0xFF8B5CF6); // Neon Violet
  static const Color gold = Color(0xFFF5C842);          // Ratings
  static const Color success = Color(0xFF4ADE80);
  static const Color danger = Color(0xFFFF5C6C);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9A96AB);
  static const Color textMuted = Color(0xFF6B6880);
  static const Color divider = Color(0x14FFFFFF);
  static const Color stroke = Color(0x1AFFFFFF);

  /// Avatar/accent color for each local profile.
  static Color profileColor(String profile) => switch (profile) {
        'Family' => secondaryAccent,
        'Kids' => success,
        _ => accent,
      };

  // ── Spacing & shape ──────────────────────────────────────────────────────
  /// Horizontal page gutter used by every screen.
  static const double gutter = 20;
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;

  // ── Gradients ────────────────────────────────────────────────────────────
  static const LinearGradient cardGradient = LinearGradient(
    colors: [
      Color(0x1F2A303E),
      Color(0x0D1E222B),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Primary call-to-action fill (Watch, Play, Continue).
  static const LinearGradient ctaGradient = LinearGradient(
    colors: [Color(0xFF7C5CFF), Color(0xFF5B8CFF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Universal Ambient Backdrop Gradient (Deep Obsidian to Midnight Violet)
  static const RadialGradient backgroundGradient = RadialGradient(
    center: Alignment(0.0, -0.3),
    radius: 1.5,
    colors: [
      Color(0xFF0E0C16), // Midnight Violet
      background,
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
    final textTheme = GoogleFonts.outfitTextTheme(baseTheme.textTheme).copyWith(
      headlineLarge: GoogleFonts.outfit(
        textStyle: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.6,
        ),
      ),
      headlineMedium: GoogleFonts.outfit(
        textStyle: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      titleLarge: GoogleFonts.outfit(
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      titleMedium: GoogleFonts.outfit(
        textStyle: const TextStyle(
          fontSize: 15,
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
      labelSmall: GoogleFonts.outfit(
        textStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textSecondary,
          letterSpacing: 1.4,
        ),
      ),
    );

    final roundedMd = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd));

    return baseTheme.copyWith(
      scaffoldBackgroundColor: background, // dark — prevents white flash on nav
      canvasColor: background,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        onPrimary: background,
        secondary: secondaryAccent,
        onSecondary: textPrimary,
        surface: surface,
        onSurface: textPrimary,
        surfaceContainerHighest: surfaceRaised,
        error: danger,
        outline: stroke,
      ),
      textTheme: textTheme,
      dividerColor: divider,
      dividerTheme: const DividerThemeData(color: divider, thickness: 1, space: 1),
      splashFactory: InkRipple.splashFactory,
      highlightColor: Colors.white.withValues(alpha: 0.04),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(backgroundColor: background),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: gutter,
        titleTextStyle: textTheme.headlineMedium,
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: const EdgeInsets.all(8),
        shape: roundedMd,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        textColor: textPrimary,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(fontSize: 13),
        shape: roundedMd,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: stroke),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium?.copyWith(height: 1.45),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceRaised,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surfaceRaised,
        dragHandleColor: Color(0x33FFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceRaised,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: textPrimary),
        actionTextColor: accent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: stroke),
        ),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      ),
      // Fields style their own containers; keep defaults to colors only so
      // existing `border: InputBorder.none` fields aren't double-decorated.
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: textMuted),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: background,
          minimumSize: const Size(64, 48),
          shape: roundedMd,
          textStyle: textTheme.titleMedium,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: background,
          elevation: 0,
          minimumSize: const Size(64, 48),
          shape: roundedMd,
          textStyle: textTheme.titleMedium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: Color(0x33FFFFFF)),
          minimumSize: const Size(64, 48),
          shape: roundedMd,
          textStyle: textTheme.titleMedium,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          shape: roundedMd,
          textStyle: textTheme.titleMedium?.copyWith(fontSize: 14),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: textPrimary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        selectedColor: accent.withValues(alpha: 0.16),
        side: const BorderSide(color: stroke),
        labelStyle: textTheme.bodyMedium?.copyWith(color: textPrimary, fontSize: 13),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: textPrimary,
        unselectedLabelColor: textSecondary,
        indicatorColor: accent,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: divider,
        labelStyle: textTheme.titleMedium,
        unselectedLabelStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? background : textSecondary),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? accent : Colors.white.withValues(alpha: 0.10)),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: Color(0x1FFFFFFF),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: stroke),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surfaceRaised,
          borderRadius: BorderRadius.circular(radiusSm),
          border: Border.all(color: stroke),
        ),
        textStyle: const TextStyle(color: textPrimary, fontSize: 12),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: accent,
        thumbColor: accent,
        inactiveTrackColor: Colors.white24,
      ),
    );
  }
}
