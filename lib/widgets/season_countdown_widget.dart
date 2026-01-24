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
        final pulseValue = _pulseController.value;
        final borderOpacity = urgency > 0.3
            ? 0.15 + (urgency * 0.3 * pulseValue)
            : 0.08;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: urgency > 0.3
                  ? accentColor.withValues(alpha: borderOpacity)
                  : Colors.white.withValues(alpha: 0.08),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Season label (S1)
              Text(
                _seasonService.seasonLabel,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textMuted,
                  letterSpacing: 0,
                ),
              ),
              _dot(),
              // D-day countdown
              _buildDDay(accentColor, urgency),
              _dot(),
              // Server time countdown (minutes until midnight GMT+2)
              Text(
                _currentTime,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        width: 2,
        height: 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.textMuted.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildDDay(Color accentColor, double urgency) {
    final remaining = _seasonService.daysRemaining;
    final isDDay = _seasonService.isDDay;
    final isVoid = _seasonService.isSeasonEnded;

    if (isDDay) {
      return Text(
        'D-DAY',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: accentColor,
          letterSpacing: 0.5,
        ),
      );
    }

    if (isVoid) {
      return Text(
        'VOID',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: accentColor,
          letterSpacing: 0.5,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'D-',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9,
            fontWeight: FontWeight.w400,
            color: AppTheme.textMuted,
            letterSpacing: 0,
          ),
        ),
        Text(
          '$remaining',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: urgency > 0.3 ? accentColor : AppTheme.textPrimary,
            letterSpacing: -0.3,
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
