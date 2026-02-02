import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state_provider.dart';
import '../providers/run_provider.dart';
import '../providers/leaderboard_provider.dart';
import '../providers/hex_data_provider.dart';
import '../widgets/season_countdown_widget.dart';
import '../widgets/flip_points_widget.dart';
import '../services/season_service.dart';
import '../services/points_service.dart';
import '../services/buff_service.dart';
import '../services/app_lifecycle_manager.dart';
import 'map_screen.dart';
import 'running_screen.dart';
import 'team_screen.dart';
import 'run_history_screen.dart';
import 'leaderboard_screen.dart';

/// Main home screen with premium icon-driven navigation
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Season service for D-day countdown
  late final SeasonService _seasonService;

  final List<Widget> _screens = const [
    MapScreen(),
    RunningScreen(),
    TeamScreen(),
    RunHistoryScreen(),
    LeaderboardScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Initialize season service (in production, startDate would come from backend)
    _seasonService = SeasonService();

    // Points service is now provided globally via Provider
    // Crew data loading is now handled by CrewScreen to support Join/Create flows

    // Initialize app lifecycle manager for OnResume data refresh
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLifecycleManager();
    });
  }

  void _initializeLifecycleManager() {
    final runProvider = context.read<RunProvider>();

    AppLifecycleManager().initialize(
      isRunning: () => runProvider.isRunning,
      onRefresh: () => _refreshAppData(),
    );
  }

  /// Refresh app data on resume (called by AppLifecycleManager).
  ///
  /// Refreshes:
  /// - Hex map data (clear cache to force re-fetch)
  /// - Leaderboard rankings
  Future<void> _refreshAppData() async {
    debugPrint('HomeScreen: Refreshing app data on resume');

    // Capture providers before async gap
    final leaderboardProvider = context.read<LeaderboardProvider>();

    try {
      // Clear hex cache to force fresh data on next map view
      HexDataProvider().clearAllHexData();

      // Refresh leaderboard data
      await leaderboardProvider.refreshLeaderboard();

      debugPrint('HomeScreen: App data refresh completed');
    } catch (e) {
      debugPrint('HomeScreen: Error refreshing app data: $e');
    }
  }

  @override
  void dispose() {
    AppLifecycleManager().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final userTeam = appState.userTeam;
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    // Determine current accent color based on team (supports red, blue, AND purple)
    final Color currentAccent = userTeam?.color ?? AppTheme.electricBlue;

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: _buildModernAppBar(
          context,
          appState,
          currentAccent,
          isLandscape,
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.03,
                child: Container(color: Colors.white),
              ),
            ),
            _screens[_currentIndex],
          ],
        ),
        bottomNavigationBar: _buildIconNavigationBar(
          context,
          currentAccent,
          isLandscape,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar(
    BuildContext context,
    AppStateProvider appState,
    Color accentColor,
    bool isLandscape,
  ) {
    final pointsService = context.watch<PointsService>();
    final topPadding = MediaQuery.of(context).padding.top;
    final contentHeight = isLandscape ? 52.0 : 68.0;

    return PreferredSize(
      preferredSize: Size.fromHeight(topPadding + contentHeight),
      child: Container(
        padding: EdgeInsets.only(top: topPadding),
        child: Container(
          margin: isLandscape
              ? const EdgeInsets.fromLTRB(16, 4, 16, 4)
              : const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withOpacity(0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: isLandscape ? 40 : 52,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/runner_logo_transparent.png',
                        height: isLandscape ? 20 : 24,
                        fit: BoxFit.contain,
                      ),
                      const Spacer(),
                      SeasonCountdownWidget(
                        seasonService: _seasonService,
                        compact: true,
                      ),
                      const SizedBox(width: 8),
                      _BuffBadge(accentColor: accentColor),
                      const SizedBox(width: 8),
                      FlipPointsWidget(
                        pointsService: pointsService,
                        accentColor: accentColor,
                        compact: true,
                      ),
                    ],
                  ),
                ),
              ),
              // Team accent glow line at bottom edge
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withOpacity(0.0),
                      accentColor.withOpacity(0.3),
                      accentColor.withOpacity(0.3),
                      accentColor.withOpacity(0.0),
                    ],
                    stops: const [0.0, 0.3, 0.7, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconNavigationBar(
    BuildContext context,
    Color accentColor,
    bool isLandscape,
  ) {
    return Container(
      height: isLandscape ? 60 : 90, // Slightly taller for floating effect
      padding: isLandscape
          ? const EdgeInsets.fromLTRB(24, 0, 24, 10)
          : const EdgeInsets.fromLTRB(24, 0, 24, 30), // Lift up from bottom
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor.withOpacity(
            0.85,
          ), // Higher opacity for legibility
          borderRadius: BorderRadius.circular(32), // Fully rounded pill
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Even spacing
          children: [
            _buildNavBarItem(0, Icons.map_rounded, accentColor, isLandscape),
            _buildNavBarItem(
              1,
              Icons.directions_run_rounded,
              accentColor,
              isLandscape,
            ),
            _buildNavBarItem(2, Icons.groups_rounded, accentColor, isLandscape),
            _buildNavBarItem(
              3,
              Icons.bar_chart_rounded,
              accentColor,
              isLandscape,
            ),
            _buildNavBarItem(
              4,
              Icons.emoji_events_rounded,
              accentColor,
              isLandscape,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBarItem(
    int index,
    IconData icon,
    Color accentColor,
    bool isLandscape,
  ) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: isLandscape ? 40 : 48,
        height: isLandscape ? 40 : 48,
        decoration: isSelected
            ? BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              )
            : BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
        child: Icon(
          icon,
          size: isLandscape ? 20 : 24,
          color: isSelected
              ? accentColor
              : AppTheme.textSecondary.withOpacity(0.7),
        ),
      ),
    );
  }
}

/// Compact buff multiplier badge for header.
///
/// Shows current buff multiplier (e.g., "2x") in a style matching
/// SeasonCountdownWidget and FlipPointsWidget.
class _BuffBadge extends StatelessWidget {
  final Color accentColor;

  const _BuffBadge({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: BuffService(),
      builder: (context, _) {
        final multiplier = BuffService().multiplier;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: multiplier > 1
                  ? accentColor.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.08),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bolt_rounded,
                size: 10,
                color: multiplier > 1 ? accentColor : AppTheme.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                '${multiplier}x',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: multiplier > 1 ? accentColor : AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
