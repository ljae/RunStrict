import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ---------------------------------------------------------------------------
  // COLOR PALETTE (RunStrict Brand Colors - Extracted from Logo)
  // ---------------------------------------------------------------------------
  // RunStrict Red - Vibrant red from "Run" in logo
  static const Color athleticRed = Color(0xFFFF003C); // Logo Red
  static const Color athleticRedShadow = Color(0xFFCC0030); // Darker variant

  // RunStrict Blue - Bright cyan-blue from "Strict" in logo
  static const Color electricBlue = Color(0xFF008DFF); // Logo Blue
  static const Color electricBlueDeep = Color(0xFF0070CC); // Deeper variant

  // RunStrict Purple - CHAOS team (unlocks D-140)
  static const Color chaosPurple = Color(0xFF8B5CF6); // Purple team
  static const Color chaosPurpleDeep = Color(0xFF7C3AED); // Deeper variant

  // ---------------------------------------------------------------------------
  // ANIMATION CURVES (Modern, Smooth Transitions)
  // ---------------------------------------------------------------------------
  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve bouncyCurve = Curves.elasticOut;
  static const Curve snappyCurve = Curves.easeInOutQuart;
  static const Curve smoothCurve = Curves.easeInOutCubic;

  // Animation Durations
  static const Duration fastDuration = Duration(milliseconds: 150);
  static const Duration normalDuration = Duration(milliseconds: 300);
  static const Duration slowDuration = Duration(milliseconds: 500);
  static const Duration dramaticDuration = Duration(milliseconds: 800);

  // Minimal Grayscale
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Backgrounds - Texture & Depth
  static const Color backgroundStart = Color(0xFF0F172A);
  static const Color backgroundEnd = Color(0xFF0F172A); // Flat background
  static const Color surfaceColor = Color(0xFF1E293B);

  // Minimal Highlights
  static const Color accentColor = Color(0xFFF8FAFC);

  // ---------------------------------------------------------------------------
  // GRADIENTS (Subtle or Removed)
  // ---------------------------------------------------------------------------
  static const LinearGradient primaryGradientBlue = LinearGradient(
    colors: [electricBlue, electricBlue], // Flat for minimal
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradientRed = LinearGradient(
    colors: [athleticRed, athleticRed], // Flat for minimal
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [backgroundStart, backgroundEnd],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ---------------------------------------------------------------------------
  // THEME DATA
  // ---------------------------------------------------------------------------
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundStart,
      primaryColor: electricBlue,

      // Color Scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: electricBlue,
        brightness: Brightness.dark,
        primary: electricBlue,
        secondary: athleticRed,
        surface: surfaceColor,
        background: backgroundStart,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
      ),

      // Typography - Bebas Neue for headers, Sora for body
      textTheme: TextTheme(
        displayLarge: GoogleFonts.bebasNeue(
          fontSize: 57,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          letterSpacing: 1.0,
        ),
        displayMedium: GoogleFonts.bebasNeue(
          fontSize: 45,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          letterSpacing: 0.5,
        ),
        displaySmall: GoogleFonts.bebasNeue(
          fontSize: 36,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        headlineLarge: GoogleFonts.bebasNeue(
          fontSize: 32,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        headlineMedium: GoogleFonts.bebasNeue(
          fontSize: 28,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        headlineSmall: GoogleFonts.bebasNeue(
          fontSize: 24,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.sora(
          fontSize: 22,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        titleMedium: GoogleFonts.sora(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          letterSpacing: 0.1,
        ),
        titleSmall: GoogleFonts.sora(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          letterSpacing: 0.1,
        ),
        bodyLarge: GoogleFonts.sora(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          letterSpacing: 0.2,
        ),
        bodyMedium: GoogleFonts.sora(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          letterSpacing: 0.2,
        ),
        bodySmall: GoogleFonts.sora(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          letterSpacing: 0.2,
        ),
        labelLarge: GoogleFonts.sora(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          letterSpacing: 1.0,
        ),
      ),

      // Card Theme - Minimal
      cardTheme: CardThemeData(
        color: surfaceColor.withOpacity(0.5),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),

      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: electricBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.sora(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor.withOpacity(0.5),
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: electricBlue, width: 1.5),
        ),
        hintStyle: GoogleFonts.sora(color: textSecondary.withOpacity(0.5)),
      ),

      dividerColor: Colors.white.withOpacity(0.05),
    );
  }

  // ---------------------------------------------------------------------------
  // STATIC UTILITIES
  // ---------------------------------------------------------------------------

  /// Returns the appropriate gradient for the team
  static LinearGradient teamGradient(bool isRed) {
    return isRed ? primaryGradientRed : primaryGradientBlue;
  }

  /// Returns the appropriate color for the team
  static Color teamColor(bool isRed) {
    return isRed ? athleticRed : electricBlue;
  }

  /// Returns a minimal shadow (removed neon glow)
  static List<BoxShadow> glowShadow(Color color, {double intensity = 1.0}) {
    return [
      BoxShadow(
        color: color.withOpacity((0.15 * intensity).clamp(0.0, 1.0)),
        blurRadius: (20 * intensity).abs(), // Ensure non-negative
        spreadRadius: -5 * intensity,
        offset: const Offset(0, 10),
      ),
    ];
  }

  /// Returns a minimal decoration with subtle glass/texture feel
  static BoxDecoration meshDecoration({Color? color, bool isRed = false}) {
    final baseColor = color ?? surfaceColor;

    return BoxDecoration(
      color: baseColor.withOpacity(0.6), // More transparency
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 30,
          offset: const Offset(0, 10),
        ),
      ],
      // Optional: Add image provider for noise texture here if implementing
    );
  }

  /// Returns a minimal border decoration
  static BoxDecoration tubularBorder(Color color, {double width = 2.0}) {
    return BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: color.withOpacity(0.5), width: width),
    );
  }

  /// DEPRECATED: Use tubularBorder instead
  static BoxDecoration hexBorder(Color color, {double width = 2.0}) {
    return tubularBorder(color, width: width);
  }

  // Spacing Constants
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;
}
