import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/run_provider.dart';
import '../providers/app_state_provider.dart';
import '../models/team.dart';
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
      final appState = context.read<AppStateProvider>();
      final team = appState.userTeam ?? Team.blue;

      await context.read<RunProvider>().startRun(team: team);

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

  Future<void> _stopRun() async {
    if (mounted) {
      await context.read<RunProvider>().stopRun();
    }
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
                  const SizedBox(height: 16),
                  _buildSecondaryStats(runningProvider, teamColor),
                  const SizedBox(height: 12),
                  _buildMainStats(runningProvider, teamColor),
                  const Spacer(),
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
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withOpacity(0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (provider.isRunning) ...[
                _buildPulsingDot(teamColor),
                const SizedBox(width: 8),
                Text(
                  'RUNNING',
                  style: GoogleFonts.outfit(
                    color: teamColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
              ] else ...[
                Icon(Icons.directions_run, color: teamColor, size: 14),
                const SizedBox(width: 8),
                Text(
                  'READY',
                  style: GoogleFonts.outfit(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ],
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              icon: Icons.timer_outlined,
              value: provider.formattedTime,
              label: 'TIME',
              color: Colors.white,
            ),
          ),
          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.1)),
          Expanded(
            child: _buildStatItem(
              icon: Icons.speed,
              value: provider.formattedPace,
              label: 'PACE',
              color: teamColor,
            ),
          ),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color.withOpacity(0.8), size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 20,
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

    if (provider.isRunning) {
      // Running state: Full-width stop button
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: EnergyHoldButton(
          icon: Icons.stop_rounded,
          baseColor: AppTheme.surfaceColor.withOpacity(0.9),
          fillColor: AppTheme.athleticRed,
          iconColor: AppTheme.athleticRed,
          onComplete: _stopRun,
          isHoldRequired: true,
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }

    // Ready state: Pulsing start button
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: EnergyHoldButton(
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
