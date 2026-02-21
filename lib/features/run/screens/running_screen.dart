import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../providers/run_provider.dart';
import '../../auth/providers/app_state_provider.dart';
import '../../team/providers/buff_provider.dart';
import '../../../core/providers/user_repository_provider.dart';
import '../../../data/models/team.dart';
import '../../map/widgets/route_map.dart';
import '../../../core/widgets/energy_hold_button.dart';

class RunningScreen extends ConsumerStatefulWidget {
  const RunningScreen({super.key});

  @override
  ConsumerState<RunningScreen> createState() => _RunningScreenState();
}

class _RunningScreenState extends ConsumerState<RunningScreen>
    with TickerProviderStateMixin {
  // Animations
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Countdown animation
  late AnimationController _countdownController;
  late Animation<double> _countdownScaleAnimation;
  late Animation<double> _countdownOpacityAnimation;

  // UI State
  bool _isInitializing = false;
  bool _isCountingDown = false;
  int _countdownValue = 3; // 3, 2, 1, then GO (0)
  String? _errorMessage;
  StreamSubscription? _eventSubscription;

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

    // Countdown animation (each number takes 700ms)
    _countdownController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _countdownScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.5,
          end: 1.2,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.2,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 60,
      ),
    ]).animate(_countdownController);

    _countdownOpacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_countdownController);

    // Listen for run events
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _eventSubscription = ref.read(runProvider.notifier).eventStream.listen((
        event,
      ) {
        // Events handled here (e.g., run completion)
        debugPrint('RunProvider event: $event');
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownController.dispose();
    _eventSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startRun() async {
    // Prevent double-tap - ignore if already starting, counting down, or running
    final run = ref.read(runProvider);
    debugPrint(
      '>>> _startRun called, _isInitializing=$_isInitializing, _isCountingDown=$_isCountingDown, isRunning=${run.isRunning}',
    );
    if (_isInitializing || _isCountingDown || run.isRunning) {
      debugPrint(
        '>>> _startRun BLOCKED - already initializing, counting down, or running',
      );
      return;
    }

    debugPrint('>>> _startRun STARTING COUNTDOWN');
    setState(() {
      _isCountingDown = true;
      _countdownValue = 3;
      _errorMessage = null;
    });

    // Start the countdown sequence
    await _runCountdown();
  }

  Future<void> _runCountdown() async {
    // Countdown: 3, 2, 1, GO
    // Start run during "1" so it's ready by "GO"
    Future<void>? startRunFuture;
    String? startRunError;

    for (int i = 3; i >= 0; i--) {
      if (!mounted || !_isCountingDown) return;

      setState(() {
        _countdownValue = i;
      });

      _countdownController.forward(from: 0);

      // Start run during "1" - gives ~800ms head start before "GO" ends
      if (i == 1 && startRunFuture == null) {
        startRunFuture = _executeRunStartAsync().catchError((e) {
          startRunError = e.toString().replaceAll('Exception: ', '');
        });
      }

      await Future.delayed(const Duration(milliseconds: 800));
    }

    // Wait for run to actually start (should be done by now)
    if (startRunFuture != null) {
      await startRunFuture;
    }

    // Check for errors
    if (startRunError != null && mounted) {
      setState(() {
        _isCountingDown = false;
        _errorMessage = startRunError;
      });
      return;
    }

    // Hide countdown - run should already be active
    if (mounted) {
      setState(() {
        _isCountingDown = false;
      });
    }
  }

  Future<void> _executeRunStartAsync() async {
    final team = ref.read(userRepositoryProvider)?.team ??
        ref.read(appStateProvider.notifier).userTeam ??
        Team.red;

    await ref.read(runProvider.notifier).startRun(team: team);
  }

  Future<void> _stopRun() async {
    if (mounted) {
      await ref.read(runProvider.notifier).stopRun();
      // Reset all states for next run cycle
      setState(() {
        _isInitializing = false;
        _isCountingDown = false;
        _countdownValue = 3;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch state for reactivity, read notifier for computed getters
    ref.watch(runProvider);
    final run = ref.read(runProvider.notifier);

    // Use team's color directly (supports red, blue, AND purple)
    final userTeam = ref.watch(userRepositoryProvider)?.team;
    final teamColor = userTeam?.color ?? AppTheme.electricBlue;
    final isRed = userTeam == Team.red;

    return Scaffold(
      backgroundColor: AppTheme.backgroundStart,
      body: Stack(
        children: [
          OrientationBuilder(
            builder: (context, orientation) {
              return orientation == Orientation.landscape
                  ? _buildLandscapeLayout(run, teamColor, isRed)
                  : _buildPortraitLayout(run, teamColor, isRed);
            },
          ),
          // Countdown Overlay
          if (_isCountingDown) _buildCountdownOverlay(teamColor),
          // Error Message (Overlay on top of everything)
          if (_errorMessage != null)
            Positioned(
              top: 100,
              left: 24,
              right: 24,
              child: _buildErrorBanner(),
            ),
        ],
      ),
    );
  }

  Widget _buildPortraitLayout(
    RunNotifier runningProvider,
    Color teamColor,
    bool isRed,
  ) {
    return Container(
      color: AppTheme.backgroundStart,
      child: Stack(
        children: [
          // Full Screen Map Background
          Positioned.fill(
            child: RouteMap(
              key: const ValueKey('running_screen_map'),
              route: runningProvider.routePoints,
              routeVersion: runningProvider.routeVersion,
              showLiveLocation: true,
              aspectRatio: 1.0,
              interactive: true,
              showHexGrid: true,
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
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout(
    RunNotifier runningProvider,
    Color teamColor,
    bool isRed,
  ) {
    return Row(
      children: [
        // Map on the left (takes most space)
        Expanded(
          flex: 3,
          child: RouteMap(
            key: const ValueKey('running_screen_map'),
            route: runningProvider.routePoints,
            routeVersion: runningProvider.routeVersion,
            showLiveLocation: true,
            aspectRatio: 1.0,
            interactive: true,
            showHexGrid: true,
            navigationMode: true,
            teamColor: teamColor,
            isRedTeam: isRed,
            isRunning: runningProvider.isRunning,
          ),
        ),

        // Stats & Controls on the right
        Expanded(
          flex: 2,
          child: Container(
            color: AppTheme.backgroundStart,
            child: SafeArea(
              left: false,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTopBar(runningProvider, teamColor),
                      const SizedBox(height: 10),
                      // Scale down main stats to fit
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _buildMainStats(runningProvider, teamColor),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildSecondaryStats(runningProvider, teamColor),
                      const SizedBox(height: 20),
                      _buildControls(runningProvider, teamColor),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(RunNotifier provider, Color teamColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withOpacity(0.3),
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

  Widget _buildMainStats(RunNotifier provider, Color teamColor) {
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

  Widget _buildSecondaryStats(RunNotifier provider, Color teamColor) {
    final buffState = ref.watch(buffProvider);
    final multiplier = buffState.effectiveMultiplier;
    final showMultiplier = multiplier > 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.3),
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
          // Buff multiplier display (only show when > 1x)
          if (showMultiplier) ...[
            Container(
              width: 1,
              height: 36,
              color: Colors.white.withOpacity(0.1),
            ),
            Expanded(
              child: _buildStatItem(
                icon: Icons.flash_on,
                value: '${multiplier}x',
                label: 'BUFF',
                color: Colors.amber,
              ),
            ),
          ],
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

  Widget _buildControls(RunNotifier provider, Color teamColor) {
    // Determine state priority:
    // 1. isRunning → show stop button
    // 2. _isCountingDown → hide button (overlay visible)
    // 3. else → show start button (ready state)
    // Note: removed 'initializing' state - countdown overlay handles transition
    final controlState = provider.isRunning
        ? 'running'
        : (_isCountingDown ? 'countdown' : 'ready');

    return KeyedSubtree(
      key: ValueKey('controls_$controlState'),
      child: _buildControlsContent(provider, teamColor, controlState),
    );
  }

  Widget _buildControlsContent(
    RunNotifier provider,
    Color teamColor,
    String state,
  ) {
    if (state == 'countdown') {
      // During countdown, hide the button (overlay covers screen)
      return const SizedBox(height: 80);
    }

    if (state == 'running') {
      // Running state: Full-width stop button (use team color for icon/border)
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: EnergyHoldButton(
          icon: Icons.stop_rounded,
          baseColor: AppTheme.surfaceColor.withOpacity(0.9),
          fillColor: teamColor,
          iconColor: teamColor,
          onComplete: _stopRun,
          isHoldRequired: true,
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }

    // Ready state: Pulsing start button (hold 1.0s)
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

  Widget _buildCountdownOverlay(Color teamColor) {
    final displayText = _countdownValue > 0 ? '$_countdownValue' : 'GO';

    return Positioned.fill(
      child: Container(
        color: AppTheme.backgroundStart.withOpacity(0.9),
        child: Center(
          child: AnimatedBuilder(
            animation: _countdownController,
            builder: (context, child) {
              return Transform.scale(
                scale: _countdownScaleAnimation.value,
                child: Opacity(
                  opacity: _countdownOpacityAnimation.value.clamp(0.0, 1.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Countdown number or GO
                      Text(
                        displayText,
                        style: GoogleFonts.outfit(
                          fontSize: _countdownValue > 0 ? 200 : 160,
                          fontWeight: FontWeight.w900,
                          color: _countdownValue > 0 ? Colors.white : teamColor,
                          height: 1.0,
                          shadows: [
                            Shadow(
                              color: teamColor.withOpacity(0.6),
                              blurRadius: 40,
                              offset: const Offset(0, 0),
                            ),
                            Shadow(
                              color: teamColor.withOpacity(0.3),
                              blurRadius: 80,
                              offset: const Offset(0, 0),
                            ),
                          ],
                        ),
                      ),
                      if (_countdownValue > 0) ...[
                        const SizedBox(height: 24),
                        Text(
                          'GET READY',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                            letterSpacing: 4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
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
