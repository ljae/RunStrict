import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/season_service.dart';
import '../theme/app_theme.dart';

/// Compact season status badge for AppBar.
///
/// Displays three data points in minimal monospace style:
///   S1 · D-280 · 14:32
/// - Season number (muted)
/// - D-day countdown (accent colored when urgent)
/// - Server time GMT+2 in 24h format (muted, updates every minute)
class SeasonCountdownWidget extends StatefulWidget {
  final SeasonService? seasonService;
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
  late SeasonService _seasonService;
  Timer? _minuteTimer;
  String _currentTime = '';

  @override
  void initState() {
    super.initState();
    _seasonService = widget.seasonService ?? SeasonService();
    _currentTime = _seasonService.serverTimeDisplay;

    // Pulse animation for urgency
    _pulseController = AnimationController(
      vsync: this,
      duration: _getPulseDuration(),
    );

    if (_seasonService.urgencyLevel > 0.3) {
      _pulseController.repeat(reverse: true);
    }

    // Update time display every 30 seconds
    _minuteTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {
          _currentTime = _seasonService.serverTimeDisplay;
        });
      }
    });
  }

  Duration _getPulseDuration() {
    final urgency = _seasonService.urgencyLevel;
    if (urgency >= 0.8) return const Duration(milliseconds: 800);
    if (urgency >= 0.5) return const Duration(milliseconds: 1200);
    return const Duration(milliseconds: 2000);
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Color _getAccentColor(double urgency) {
    if (urgency >= 0.8) return AppTheme.athleticRed;
    if (urgency >= 0.5) return const Color(0xFFF59E0B);
    if (urgency >= 0.3) return const Color(0xFFFBBF24);
    return AppTheme.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final urgency = _seasonService.urgencyLevel;
    final accentColor = _getAccentColor(urgency);

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          // Removed drum decoration for a cleaner, minimal look
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Season label (S1)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  _seasonService.seasonLabel,
                  style: GoogleFonts.bebasNeue(
                    fontSize: 14,
                    color: AppTheme.textMuted.withValues(alpha: 0.7),
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // D-day countdown (HERO)
              _buildDDay(accentColor, urgency),

              const SizedBox(width: 8),

              // Server time
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  _currentTime,
                  style: GoogleFonts.bebasNeue(
                    fontSize: 14,
                    color: AppTheme.textMuted.withValues(alpha: 0.7),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Removed _drumTextShadows as we want a clean flat look

  Widget _buildDDay(Color accentColor, double urgency) {
    final remaining = _seasonService.daysRemaining;
    final isDDay = _seasonService.isDDay;
    final isVoid = _seasonService.isSeasonEnded;

    if (isDDay) {
      return Text(
        'D-DAY',
        style: GoogleFonts.bebasNeue(
          fontSize: 18,
          color: accentColor,
          letterSpacing: 1.0,
        ),
      );
    }

    if (isVoid) {
      return Text(
        'VOID',
        style: GoogleFonts.bebasNeue(
          fontSize: 18,
          color: accentColor,
          letterSpacing: 1.0,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          'D-',
          style: GoogleFonts.bebasNeue(
            fontSize: 18,
            color: urgency > 0.3
                ? accentColor.withValues(alpha: 0.8)
                : AppTheme.textSecondary,
          ),
        ),
        Text(
          '$remaining',
          style: GoogleFonts.bebasNeue(
            fontSize: 18,
            color: urgency > 0.3 ? accentColor : AppTheme.textPrimary,
            letterSpacing: 0.5,
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

  const _SeasonProgressBar({required this.progress, required this.accentColor});

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
              colors: [AppTheme.electricBlue, accentColor],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
