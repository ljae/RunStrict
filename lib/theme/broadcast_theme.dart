import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Professional Broadcast Theme for Runner App
/// Electoral broadcast aesthetic with dark control room theme
/// Updated with RunStrict logo colors
class BroadcastTheme {
  // Brand Colors - RunStrict Logo Colors
  static const Color redTeam = Color(0xFFFF003C); // Logo Red
  static const Color redTeamLight = Color(0xFFFF335F); // Lighter variant
  static const Color redTeamDark = Color(0xFFCC0030); // Darker variant

  static const Color blueTeam = Color(0xFF008DFF); // Logo Blue
  static const Color blueTeamLight = Color(0xFF33A4FF); // Lighter variant
  static const Color blueTeamDark = Color(0xFF0070CC); // Darker variant

  // ---------------------------------------------------------------------------
  // ANIMATION CURVES (Modern, Smooth Transitions)
  // ---------------------------------------------------------------------------
  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve dramaticCurve = Curves.easeInOutQuart;
  static const Curve bouncyCurve = Curves.elasticOut;
  static const Curve slideCurve = Curves.easeOutExpo;

  // Animation Durations
  static const Duration fastDuration = Duration(milliseconds: 150);
  static const Duration normalDuration = Duration(milliseconds: 300);
  static const Duration slowDuration = Duration(milliseconds: 500);
  static const Duration dramaticDuration = Duration(milliseconds: 800);

  static const Color contested = Color(0xFF8B5CF6);
  static const Color contestedGlow = Color(0xFFA78BFA);

  // Broadcast Studio Colors
  static const Color bgPrimary = Color(0xFF0A0E1A);
  static const Color bgSecondary = Color(0xFF111827);
  static const Color bgTertiary = Color(0xFF1F2937);

  // Accent Colors
  static const Color accentGold = Color(0xFFF59E0B);
  static const Color accentAlert = Color(0xFFEF4444);

  // Text Colors
  static const Color textPrimary = Color(0xFFF9FAFB);
  static const Color textSecondary = Color(0xFFD1D5DB);
  static const Color textMuted = Color(0xFF9CA3AF);

  // Border Colors
  static const Color borderSubtle = Color(0x1AFFFFFF);
  static const Color borderStrong = Color(0x33FFFFFF);

  /// Get theme data for the app
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgPrimary,
      colorScheme: ColorScheme.dark(
        primary: blueTeam,
        secondary: redTeam,
        surface: bgSecondary,
        error: accentAlert,
        onPrimary: textPrimary,
        onSecondary: textPrimary,
        onSurface: textPrimary,
      ),

      // Typography
      textTheme: TextTheme(
        displayLarge: GoogleFonts.bebasNeue(
          fontSize: 96,
          fontWeight: FontWeight.w400,
          letterSpacing: 1.5,
          color: textPrimary,
        ),
        displayMedium: GoogleFonts.bebasNeue(
          fontSize: 60,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
          color: textPrimary,
        ),
        displaySmall: GoogleFonts.bebasNeue(
          fontSize: 48,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          color: textPrimary,
        ),
        headlineLarge: GoogleFonts.bebasNeue(
          fontSize: 40,
          fontWeight: FontWeight.w400,
          letterSpacing: 1.0,
          color: textPrimary,
        ),
        headlineMedium: GoogleFonts.bebasNeue(
          fontSize: 34,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.25,
          color: textPrimary,
        ),
        headlineSmall: GoogleFonts.bebasNeue(
          fontSize: 24,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.notoSansKr(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: textPrimary,
        ),
        titleMedium: GoogleFonts.notoSansKr(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
          color: textPrimary,
        ),
        titleSmall: GoogleFonts.notoSansKr(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.notoSansKr(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.notoSansKr(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.25,
          color: textPrimary,
        ),
        bodySmall: GoogleFonts.notoSansKr(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.4,
          color: textSecondary,
        ),
        labelLarge: GoogleFonts.spaceMono(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.25,
          color: textPrimary,
        ),
        labelMedium: GoogleFonts.spaceMono(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.5,
          color: textSecondary,
        ),
        labelSmall: GoogleFonts.spaceMono(
          fontSize: 10,
          fontWeight: FontWeight.w400,
          letterSpacing: 1.5,
          color: textMuted,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: bgSecondary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderSubtle),
        ),
      ),

      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xF2111827), // 95% opacity
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.bebasNeue(
          fontSize: 24,
          fontWeight: FontWeight.w400,
          letterSpacing: 1.5,
          color: textPrimary,
        ),
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Color(0xF2111827),
        selectedItemColor: blueTeamLight,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentGold,
          foregroundColor: bgPrimary,
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.notoSansKr(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgTertiary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: blueTeam, width: 2),
        ),
        labelStyle: GoogleFonts.notoSansKr(color: textMuted),
        hintStyle: GoogleFonts.notoSansKr(color: textMuted),
      ),
    );
  }

  /// Linear gradient for red team - RunStrict Logo Red
  static LinearGradient get redGradient => const LinearGradient(
    colors: [redTeamDark, redTeam, redTeamLight],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Linear gradient for blue team - RunStrict Logo Blue
  static LinearGradient get blueGradient => const LinearGradient(
    colors: [blueTeamDark, blueTeam, blueTeamLight],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Linear gradient for contested areas
  static LinearGradient get contestedGradient => LinearGradient(
    colors: [contested, contestedGlow],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Box shadow for red team elements
  static List<BoxShadow> get redShadow => [
    BoxShadow(color: redTeam.withOpacity(0.3), blurRadius: 20, spreadRadius: 0),
  ];

  /// Box shadow for blue team elements
  static List<BoxShadow> get blueShadow => [
    BoxShadow(
      color: blueTeam.withOpacity(0.3),
      blurRadius: 20,
      spreadRadius: 0,
    ),
  ];

  /// Box shadow for contested elements
  static List<BoxShadow> get contestedShadow => [
    BoxShadow(
      color: contested.withOpacity(0.5),
      blurRadius: 30,
      spreadRadius: 0,
    ),
  ];
}
