import 'package:flutter/material.dart';

/// Digital Brutalist Cyberpunk Theme
/// Black base, sharp angles, neon accents, terminal aesthetic
/// Updated with RunStrict logo colors
class CyberpunkTheme {
  // Base Colors - Pure black and dark grays
  static const Color void0 = Color(0xFF000000);
  static const Color void1 = Color(0xFF0A0A0A);
  static const Color void2 = Color(0xFF141414);
  static const Color void3 = Color(0xFF1E1E1E);

  // Team Colors - RunStrict Logo Colors
  static const Color teamRed = Color(0xFFFF003C); // Logo Red
  static const Color teamBlue = Color(0xFF008DFF); // Logo Blue

  // ---------------------------------------------------------------------------
  // ANIMATION CURVES (Modern, Smooth Transitions)
  // ---------------------------------------------------------------------------
  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve glitchCurve = Curves.easeInOutBack;
  static const Curve terminalCurve = Curves.linear;

  // Animation Durations
  static const Duration fastDuration = Duration(milliseconds: 100);
  static const Duration normalDuration = Duration(milliseconds: 250);
  static const Duration slowDuration = Duration(milliseconds: 450);

  // System Colors
  static const Color matrixGreen = Color(0xFF00FF41);
  static const Color neonMagenta = Color(0xFFFF00FF);
  static const Color warningYellow = Color(0xFFFFFF00);
  static const Color white = Color(0xFFFFFFFF);

  // Gradients - Updated for RunStrict branding
  static const LinearGradient redGlow = LinearGradient(
    colors: [teamRed, Color(0xFFFF335F)], // Logo Red gradient
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient blueGlow = LinearGradient(
    colors: [teamBlue, Color(0xFF33A4FF)], // Logo Blue gradient
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient twinGlow = LinearGradient(
    colors: [teamRed, neonMagenta, teamBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Border Styles
  static BoxDecoration panelDecoration({
    Color? borderColor,
    Color? backgroundColor,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? void1,
      border: Border.all(color: borderColor ?? matrixGreen, width: 2),
      boxShadow:
          shadows ?? neonGlow(borderColor ?? matrixGreen, intensity: 0.5),
    );
  }

  static BoxDecoration angularPanel({
    Color? borderColor,
    Color? backgroundColor,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? void1,
      border: Border(
        left: BorderSide(color: borderColor ?? matrixGreen, width: 3),
        top: BorderSide(color: borderColor ?? matrixGreen, width: 1),
        right: BorderSide(color: borderColor ?? matrixGreen, width: 1),
        bottom: BorderSide(color: borderColor ?? matrixGreen, width: 1),
      ),
    );
  }

  // Glows and Shadows
  static List<BoxShadow> neonGlow(Color color, {double intensity = 1.0}) {
    return [
      BoxShadow(
        color: color.withOpacity(0.6 * intensity),
        blurRadius: 20,
        spreadRadius: 2,
      ),
      BoxShadow(
        color: color.withOpacity(0.3 * intensity),
        blurRadius: 40,
        spreadRadius: 5,
      ),
    ];
  }

  static List<BoxShadow> innerGlow(Color color) {
    return [
      BoxShadow(
        color: color.withOpacity(0.4),
        blurRadius: 10,
        spreadRadius: -2,
      ),
    ];
  }

  // Typography
  static TextTheme textTheme = const TextTheme(
    // Display - Large headers
    displayLarge: TextStyle(
      fontFamily: 'Orbitron',
      fontSize: 48,
      fontWeight: FontWeight.w900,
      letterSpacing: 2.0,
      height: 1.0,
    ),
    displayMedium: TextStyle(
      fontFamily: 'Orbitron',
      fontSize: 36,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
    ),
    displaySmall: TextStyle(
      fontFamily: 'Orbitron',
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.0,
    ),

    // Headlines - Section headers
    headlineLarge: TextStyle(
      fontFamily: 'Exo 2',
      fontSize: 28,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    ),
    headlineMedium: TextStyle(
      fontFamily: 'Exo 2',
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    headlineSmall: TextStyle(
      fontFamily: 'Exo 2',
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),

    // Body - Regular text
    bodyLarge: TextStyle(
      fontFamily: 'Exo 2',
      fontSize: 16,
      fontWeight: FontWeight.w400,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'Exo 2',
      fontSize: 14,
      fontWeight: FontWeight.w400,
    ),
    bodySmall: TextStyle(
      fontFamily: 'Exo 2',
      fontSize: 12,
      fontWeight: FontWeight.w400,
    ),

    // Labels - UI text
    labelLarge: TextStyle(
      fontFamily: 'JetBrains Mono',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 1.0,
    ),
    labelMedium: TextStyle(
      fontFamily: 'JetBrains Mono',
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.8,
    ),
    labelSmall: TextStyle(
      fontFamily: 'JetBrains Mono',
      fontSize: 10,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
  );

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: void0,
      primaryColor: matrixGreen,
      colorScheme: const ColorScheme.dark(
        primary: matrixGreen,
        secondary: neonMagenta,
        surface: void1,
        error: teamRed,
      ),
      textTheme: textTheme.apply(bodyColor: white, displayColor: white),
      appBarTheme: const AppBarTheme(
        backgroundColor: void0,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }
}
