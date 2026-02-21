import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Neon Cyberpunk theme for the runner app
/// Updated with RunStrict logo colors
class NeonTheme {
  // Core neon colors - RunStrict Logo Colors
  static const Color neonCyan = Color(0xFF008DFF); // Logo Blue (primary)
  static const Color neonMagenta = Color(0xFFFF003C); // Logo Red (secondary)
  static const Color neonPurple = Color(0xFFB026FF); // Purple accent
  static const Color neonGreen = Color(0xFF00FF88); // Success/positive

  // ---------------------------------------------------------------------------
  // ANIMATION CURVES (Modern, Smooth Transitions)
  // ---------------------------------------------------------------------------
  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve glowCurve = Curves.easeInOutSine;
  static const Curve pulseCurve = Curves.easeInOutQuad;
  static const Curve dramaticCurve = Curves.easeInOutQuart;

  // Animation Durations
  static const Duration fastDuration = Duration(milliseconds: 150);
  static const Duration normalDuration = Duration(milliseconds: 300);
  static const Duration slowDuration = Duration(milliseconds: 500);
  static const Duration glowDuration = Duration(milliseconds: 1500);

  // Background colors
  static const Color deepSpace = Color(0xFF0A0014);
  static const Color darkPurple = Color(0xFF1A0033);
  static const Color surfaceDark = Color(0xFF1E0A33);

  // Functional colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB8B8D1);
  static const Color textTertiary = Color(0xFF6B6B8A);

  // Gradient definitions
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [neonCyan, neonPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [neonMagenta, neonPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [deepSpace, darkPurple],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Get the main theme
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: deepSpace,

      colorScheme: const ColorScheme.dark(
        primary: neonCyan,
        secondary: neonMagenta,
        tertiary: neonPurple,
        surface: surfaceDark,
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
      ),

      // Typography with Rajdhani + Barlow
      textTheme: TextTheme(
        // Display styles - Rajdhani (geometric, athletic)
        displayLarge: GoogleFonts.rajdhani(
          fontSize: 72,
          fontWeight: FontWeight.w700,
          height: 1.0,
          letterSpacing: -1.5,
          color: textPrimary,
        ),
        displayMedium: GoogleFonts.rajdhani(
          fontSize: 56,
          fontWeight: FontWeight.w700,
          height: 1.0,
          letterSpacing: -1.0,
          color: textPrimary,
        ),
        displaySmall: GoogleFonts.rajdhani(
          fontSize: 40,
          fontWeight: FontWeight.w600,
          height: 1.1,
          letterSpacing: -0.5,
          color: textPrimary,
        ),

        // Headline styles - Rajdhani
        headlineLarge: GoogleFonts.rajdhani(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: textPrimary,
        ),
        headlineMedium: GoogleFonts.rajdhani(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          height: 1.2,
          color: textPrimary,
        ),
        headlineSmall: GoogleFonts.rajdhani(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          height: 1.3,
          color: textPrimary,
        ),

        // Title styles - Rajdhani
        titleLarge: GoogleFonts.rajdhani(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 1.3,
          letterSpacing: 0.5,
          color: textPrimary,
        ),
        titleMedium: GoogleFonts.rajdhani(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.4,
          letterSpacing: 0.5,
          color: textPrimary,
        ),
        titleSmall: GoogleFonts.rajdhani(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.4,
          letterSpacing: 0.5,
          color: textSecondary,
        ),

        // Body styles - Barlow (clean, readable)
        bodyLarge: GoogleFonts.barlow(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.barlow(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: textSecondary,
        ),
        bodySmall: GoogleFonts.barlow(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: textTertiary,
        ),

        // Label styles - Barlow
        labelLarge: GoogleFonts.barlow(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.4,
          letterSpacing: 1.2,
          color: textPrimary,
        ),
        labelMedium: GoogleFonts.barlow(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.4,
          letterSpacing: 1.0,
          color: textSecondary,
        ),
        labelSmall: GoogleFonts.barlow(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 1.4,
          letterSpacing: 1.0,
          color: textTertiary,
        ),
      ),

      // App bar theme
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.rajdhani(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: neonCyan, size: 24),
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: neonCyan.withOpacity(0.2), width: 1),
        ),
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: neonCyan,
          foregroundColor: deepSpace,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.rajdhani(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ),

      // Outlined button theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: neonCyan,
          side: BorderSide(color: neonCyan.withOpacity(0.5), width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.rajdhani(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ),

      // Icon theme
      iconTheme: const IconThemeData(color: neonCyan, size: 24),
    );
  }

  /// Glow effect for neon elements
  static List<BoxShadow> neonGlow(Color color, {double intensity = 1.0}) {
    return [
      BoxShadow(
        color: color.withOpacity(0.6 * intensity),
        blurRadius: 20,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: color.withOpacity(0.3 * intensity),
        blurRadius: 40,
        spreadRadius: 5,
      ),
    ];
  }

  /// Soft inner glow for cards
  static List<BoxShadow> innerGlow(Color color) {
    return [
      BoxShadow(
        color: color.withOpacity(0.1),
        blurRadius: 10,
        spreadRadius: -5,
      ),
    ];
  }

  /// Elevated card effect
  static List<BoxShadow> elevatedCard() {
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.5),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ];
  }
}
