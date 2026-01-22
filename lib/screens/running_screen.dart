import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../theme/app_theme.dart';
import '../theme/neon_theme.dart';
import '../providers/run_provider.dart';
import '../providers/app_state_provider.dart';
import '../models/team.dart';
import '../services/location_service.dart';
import '../widgets/route_map.dart';
import '../widgets/energy_hold_button.dart';

class RunningScreen extends StatefulWidget {
  const RunningScreen({super.key});

  @override
  State<RunningScreen> createState() => _RunningScreenState();
}

class _RunningScreenState extends State<RunningScreen>
    with TickerProviderStateMixin {
  // Animations
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // UI State
  bool _isInitializing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // Pulse animation for Start button
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startRun() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      // Determine if runner is purple (Twin Crew)
      // For now, we simulate this if they are in a crew
      final appState = context.read<AppStateProvider>();
      final isPurple = appState.currentUser?.crewId != null;
      final team = appState.userTeam ?? Team.blue; // Default to blue if null

      await context.read<RunProvider>().startRun(
        team: team,
        isPurpleRunner: isPurple,
      );

      // Run started - stay on RunningScreen
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  void _pauseRun() {
    context.read<RunProvider>().pauseRun();
  }

  void _resumeRun() {
    context.read<RunProvider>().resumeRun();
  }

  Future<void> _stopRun() async {
    final confirmed = await _showStopConfirmation();
    if (confirmed == true && mounted) {
      await context.read<RunProvider>().stopRun();
    }
  }

  Future<bool?> _showStopConfirmation() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: AppTheme.athleticRed.withOpacity(0.5),
            width: 2,
          ),
        ),
        title: Row(
          children: [
            Icon(Icons.stop_circle_outlined, color: AppTheme.athleticRed),
            const SizedBox(width: 12),
            Text(
              'END RUN?',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Your progress will be saved.',
          style: GoogleFonts.inter(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'CANCEL',
              style: GoogleFonts.inter(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.athleticRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'END',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final runningProvider = context.watch<RunProvider>();

    final isRed = appState.userTeam?.name == 'red';
    final teamColor = isRed ? AppTheme.athleticRed : AppTheme.electricBlue;

    return Scaffold(
      backgroundColor: AppTheme.backgroundStart,
      body: Container(
        // Remove gradient, use flat background
        color: AppTheme.backgroundStart,
        child: Stack(
          children: [
            // Full Screen Map Background (Always visible)
            Positioned.fill(
              child: RouteMap(
                key: const ValueKey('running_screen_map'),
                route: runningProvider.routePoints,
                routeVersion: runningProvider.routeVersion,
                showLiveLocation: true,
                aspectRatio: 1.0,
                interactive: true,
                showHexGrid: true,
                // Enable navigation mode (bearing tracking)
                navigationMode: true,
                teamColor: teamColor,
                isRedTeam: isRed,
                isRunning: runningProvider.isRunning,
              ),
            ),

            // Minimal overlay for readability
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppTheme.backgroundStart.withOpacity(0.6),
                        Colors.transparent,
                        AppTheme.backgroundStart.withOpacity(0.8),
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // Main Content
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(runningProvider, teamColor),
                  const Spacer(),
                  _buildMainStats(runningProvider, teamColor),
                  const Spacer(),
                  _buildSecondaryStats(runningProvider, teamColor),
                  const SizedBox(height: 24),
                  const SizedBox(height: 16),
                  _buildControls(runningProvider, teamColor),
                  const SizedBox(height: 40),
                ],
              ),
            ),

            // Error Message
            if (_errorMessage != null)
              Positioned(
                top: 100,
                left: 24,
                right: 24,
                child: _buildErrorBanner(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(RunProvider provider, Color teamColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Placeholder for alignment
          const SizedBox(width: 48),

          // Title - Minimal pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor.withOpacity(0.4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (provider.isRunning)
                  _buildPulsingDot(teamColor)
                else if (provider.isPaused)
                  Icon(Icons.pause, color: Colors.amber, size: 14)
                else
                  Icon(Icons.directions_run, color: teamColor, size: 14),
                const SizedBox(width: 8),
                Text(
                  provider.isRunning
                      ? 'TRACKING ACTIVE'
                      : provider.isPaused
                      ? 'PAUSED'
                      : 'READY',
                  style: GoogleFonts.outfit(
                    color: provider.isRunning
                        ? teamColor
                        : provider.isPaused
                        ? Colors.amber
                        : AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ),

          // GPS Signal Indicator - Minimal
          _buildGpsIndicator(provider, teamColor),
        ],
      ),
    );
  }

  Widget _buildPulsingDot(Color color) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            // Removed heavy shadow for minimal look
          ),
        );
      },
    );
  }

  Widget _buildGpsIndicator(RunProvider provider, Color teamColor) {
    final quality = provider.signalQuality;
    final color = switch (quality) {
      GpsSignalQuality.excellent => Colors.green,
      GpsSignalQuality.good => Colors.lightGreen,
      GpsSignalQuality.fair => Colors.amber,
      GpsSignalQuality.poor => Colors.orange,
      GpsSignalQuality.none => Colors.red,
    };

    final bars = switch (quality) {
      GpsSignalQuality.excellent => 4,
      GpsSignalQuality.good => 3,
      GpsSignalQuality.fair => 2,
      GpsSignalQuality.poor => 1,
      GpsSignalQuality.none => 0,
    };

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.gps_fixed, color: color, size: 16),
          const SizedBox(width: 6),
          Row(
            children: List.generate(4, (index) {
              return Container(
                margin: const EdgeInsets.only(right: 2),
                width: 3,
                height: 6 + (index * 2).toDouble(), // Less height variation
                decoration: BoxDecoration(
                  color: index < bars ? color : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMainStats(RunProvider provider, Color teamColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Distance
        Text(
          provider.distance.toStringAsFixed(2),
          style: GoogleFonts.outfit(
            fontSize: 96,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 0.9,
            // Minimal shadow, ensure non-negative blur
            shadows: [
              Shadow(
                color: teamColor.withOpacity(0.3),
                blurRadius: 20, // Static positive value
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
        Text(
          'KILOMETERS',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryStats(RunProvider provider, Color teamColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.timer_outlined,
            value: provider.formattedTime,
            label: 'TIME',
            color: Colors.white,
          ),
          Container(width: 1, height: 50, color: Colors.white.withOpacity(0.1)),
          _buildStatItem(
            icon: Icons.speed,
            value: provider.formattedPace,
            label: 'PACE',
            color: teamColor,
          ),
          // Removed Calories Icon
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color.withOpacity(0.8), size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildControls(RunProvider provider, Color teamColor) {
    if (_isInitializing) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: teamColor.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: CircularProgressIndicator(color: teamColor, strokeWidth: 3),
        ),
      );
    }

    if (provider.isActive) {
      if (provider.isPaused) {
        // Split view: Stop and Resume
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: EnergyHoldButton(
                  // label: 'STOP',
                  icon: Icons.stop_rounded,
                  baseColor: AppTheme.surfaceColor,
                  fillColor: AppTheme.athleticRed,
                  iconColor: AppTheme.athleticRed,
                  onComplete: _stopRun,
                  isHoldRequired: true,
                  duration: const Duration(milliseconds: 1500),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: EnergyHoldButton(
                  // label: 'RESUME',
                  icon: Icons.play_arrow_rounded,
                  baseColor: teamColor.withOpacity(0.2),
                  fillColor: teamColor,
                  iconColor: Colors.white,
                  onComplete: _resumeRun,
                  isHoldRequired: true,
                  duration: const Duration(milliseconds: 1000),
                ),
              ),
            ],
          ),
        );
      }

      // Running state: Wide Hold Button
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: EnergyHoldButton(
          // label: 'PAUSE',
          icon: Icons.pause_circle_outline_rounded,
          baseColor: AppTheme.surfaceColor.withOpacity(0.9),
          fillColor: teamColor,
          iconColor: teamColor,
          onComplete: _pauseRun,
          isHoldRequired: true,
        ),
      );
    }

    // Start Button
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: EnergyHoldButton(
              // label: 'GO',
              icon: Icons.directions_run,
              baseColor: teamColor.withOpacity(0.2),
              fillColor: teamColor,
              iconColor: Colors.white,
              onComplete: _startRun,
              isHoldRequired: true,
              duration: const Duration(milliseconds: 1000),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlButton({
    required VoidCallback onTap,
    required IconData icon,
    required Color color,
    required Color iconColor,
    required double size,
    bool withGlow = false,
    Color? borderColor,
    String? label,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          // Minimal or no shadow
          boxShadow: withGlow
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: -5,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [],
          border: Border.all(
            color: borderColor ?? Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: iconColor,
              size: size * 0.35,
            ), // Slightly smaller icon
            if (label != null) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: iconColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.athleticRed.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _errorMessage = null),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
