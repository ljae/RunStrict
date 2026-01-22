import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/season_service.dart';
import '../theme/app_theme.dart';

/// A minimal, professional D-day countdown widget for the MapScreen.
///
/// Displays remaining days as "D-280" through "D-1", then "D-DAY" on the final day.
/// Features a subtle pulsing animation that intensifies as D-Day approaches.
class SeasonCountdownWidget extends StatefulWidget {
  /// The season service providing countdown data.
  /// If null, creates a default SeasonService.
  final SeasonService? seasonService;

  /// Whether to show the compact version (just the badge).
  final bool compact;

  const SeasonCountdownWidget({
    super.key,
    this.seasonService,
    this.compact = false,
  });

  @override
  State<SeasonCountdownWidget> createState() => _SeasonCountdownWidgetState();
}

class _SeasonCountdownWidgetState extends State<SeasonCountdownWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late SeasonService _seasonService;

  @override
  void initState() {
    super.initState();
    _seasonService = widget.seasonService ?? SeasonService();

    // Pulse animation - speed and intensity based on urgency
    _pulseController = AnimationController(
      vsync: this,
      duration: _getPulseDuration(),
    );

    _pulseAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Only animate if there's urgency
    if (_seasonService.urgencyLevel > 0.3) {
      _pulseController.repeat(reverse: true);
    }
  }

  Duration _getPulseDuration() {
    final urgency = _seasonService.urgencyLevel;
    if (urgency >= 0.8) return const Duration(milliseconds: 800);
    if (urgency >= 0.5) return const Duration(milliseconds: 1200);
    if (urgency >= 0.3) return const Duration(milliseconds: 2000);
    return const Duration(milliseconds: 3000);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Get the accent color based on urgency level.
  Color _getAccentColor(double urgency) {
    if (urgency >= 0.8) {
      // Critical: Red
      return AppTheme.athleticRed;
    } else if (urgency >= 0.5) {
      // Warning: Amber
      return const Color(0xFFF59E0B);
    } else if (urgency >= 0.3) {
      // Caution: Soft amber
      return const Color(0xFFFBBF24);
    }
    // Calm: Neutral gray
    return AppTheme.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final displayText = _seasonService.displayString;
    final urgency = _seasonService.urgencyLevel;
    final accentColor = _getAccentColor(urgency);
    final isDDay = _seasonService.isDDay;
    final isVoid = _seasonService.isSeasonEnded;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final pulseValue = _pulseAnimation.value;
        final glowIntensity = urgency * 0.4 * pulseValue;
        final borderOpacity = 0.15 + (urgency * 0.3 * pulseValue);

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 10 : 14,
            vertical: widget.compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            // Glassmorphic background
            color: AppTheme.surfaceColor.withOpacity(0.85),
            borderRadius: BorderRadius.circular(widget.compact ? 8 : 10),
            border: Border.all(
              color: accentColor.withOpacity(borderOpacity),
              width: isDDay || isVoid ? 1.5 : 1.0,
            ),
            boxShadow: [
              // Subtle drop shadow
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              // Glow effect (only when urgent)
              if (urgency > 0.3)
                BoxShadow(
                  color: accentColor.withOpacity(glowIntensity),
                  blurRadius: 20,
                  spreadRadius: -2,
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Subtle indicator dot
              if (!widget.compact) ...[
                _UrgencyIndicator(
                  urgency: urgency,
                  color: accentColor,
                  pulseValue: pulseValue,
                ),
                const SizedBox(width: 8),
              ],

              // Main countdown text
              _CountdownText(
                text: displayText,
                color: accentColor,
                urgency: urgency,
                compact: widget.compact,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Small pulsing dot indicator showing urgency level.
class _UrgencyIndicator extends StatelessWidget {
  final double urgency;
  final Color color;
  final double pulseValue;

  const _UrgencyIndicator({
    required this.urgency,
    required this.color,
    required this.pulseValue,
  });

  @override
  Widget build(BuildContext context) {
    final size = 6.0 + (urgency * 2 * pulseValue);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.8 + (0.2 * pulseValue)),
        boxShadow: urgency > 0.5
            ? [
                BoxShadow(
                  color: color.withOpacity(0.5 * pulseValue),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}

/// The main countdown text display.
class _CountdownText extends StatelessWidget {
  final String text;
  final Color color;
  final double urgency;
  final bool compact;

  const _CountdownText({
    required this.text,
    required this.color,
    required this.urgency,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    // Parse the display text to style "D-" and number separately
    final isDDay = text == 'D-DAY';
    final isVoid = text == 'VOID';

    if (isDDay || isVoid) {
      // Special state: full emphasis
      return Text(
        text,
        style: GoogleFonts.jetBrainsMono(
          fontSize: compact ? 12 : 14,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 1.5,
        ),
      );
    }

    // Normal countdown: "D-" prefix + number
    final parts = text.split('-');
    if (parts.length != 2) {
      return Text(text,
          style: GoogleFonts.jetBrainsMono(
            fontSize: compact ? 12 : 14,
            color: color,
          ));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        // "D-" prefix (muted)
        Text(
          'D-',
          style: GoogleFonts.jetBrainsMono(
            fontSize: compact ? 10 : 11,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary.withOpacity(0.7),
            letterSpacing: 0.5,
          ),
        ),
        // Number (emphasized)
        Text(
          parts[1],
          style: GoogleFonts.jetBrainsMono(
            fontSize: compact ? 13 : 15,
            fontWeight: FontWeight.w600,
            color: urgency > 0.3 ? color : AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

/// A larger, more prominent version of the countdown for special screens.
class SeasonCountdownLarge extends StatelessWidget {
  final SeasonService? seasonService;

  const SeasonCountdownLarge({super.key, this.seasonService});

  @override
  Widget build(BuildContext context) {
    final service = seasonService ?? SeasonService();
    final urgency = service.urgencyLevel;

    Color accentColor;
    if (urgency >= 0.8) {
      accentColor = AppTheme.athleticRed;
    } else if (urgency >= 0.5) {
      accentColor = const Color(0xFFF59E0B);
    } else {
      accentColor = AppTheme.textSecondary;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Large countdown number
        Text(
          service.displayString,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 48,
            fontWeight: FontWeight.w700,
            color: urgency > 0.3 ? accentColor : AppTheme.textPrimary,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        // Subtitle
        Text(
          'UNTIL THE VOID',
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 16),
        // Progress bar
        _SeasonProgressBar(
          progress: service.seasonProgress,
          accentColor: accentColor,
        ),
      ],
    );
  }
}

/// A horizontal progress bar showing season progression.
class _SeasonProgressBar extends StatelessWidget {
  final double progress;
  final Color accentColor;

  const _SeasonProgressBar({
    required this.progress,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      width: 200,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.electricBlue,
                accentColor,
              ],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
