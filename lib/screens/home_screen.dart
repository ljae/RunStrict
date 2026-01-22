import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../providers/app_state_provider.dart';
import '../providers/crew_provider.dart';
import '../widgets/season_countdown_widget.dart';
import '../widgets/flip_points_widget.dart';
import '../services/season_service.dart';
import '../services/points_service.dart';
import 'map_screen.dart';
import 'running_screen.dart';
import 'crew_screen.dart';
import 'results_screen.dart';
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
    CrewScreen(),
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
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final userTeam = appState.userTeam;

    // Determine current accent color based on team, default to Neon Blue
    final Color currentAccent = userTeam?.name == 'red'
        ? AppTheme.athleticRed
        : AppTheme.electricBlue;

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent, // Allow gradient to show through
        appBar: _buildModernAppBar(context, appState, currentAccent),
        body: Stack(
          children: [
            // Subtle texture overlay (optional, could be an image or noise pattern)
            Positioned.fill(
              child: Opacity(
                opacity: 0.03,
                child: Container(
                  color: Colors.white, // Placeholder for texture
                ),
              ),
            ),
            _screens[_currentIndex],
          ],
        ),
        bottomNavigationBar: _buildIconNavigationBar(context, currentAccent),
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar(
    BuildContext context,
    AppStateProvider appState,
    Color accentColor,
  ) {
    // Get the global PointsService from Provider
    final pointsService = context.watch<PointsService>();

    return AppBar(
      backgroundColor: Colors.transparent, // Minimal - let background show
      elevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // RunStrict Logo
          Image.asset(
            'assets/images/runner_logo_transparent.png',
            height: 32,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 12),
          // D-day Countdown
          SeasonCountdownWidget(
            seasonService: _seasonService,
            compact: true,
          ),
          const SizedBox(width: 8),
          // Flip Points Counter
          FlipPointsWidget(
            pointsService: pointsService,
            accentColor: accentColor,
            compact: true,
          ),
        ],
      ),
      actions: [
        // Minimal User Avatar
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Container(
            width: 32,
            height: 32,
            decoration: AppTheme.tubularBorder(accentColor, width: 1.5),
            child: Center(
              child: Icon(Icons.person_rounded, size: 18, color: accentColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIconNavigationBar(BuildContext context, Color accentColor) {
    return Container(
      height: 90, // Slightly taller for floating effect
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 30), // Lift up from bottom
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
            _buildNavBarItem(0, Icons.map_rounded, accentColor),
            _buildNavBarItem(1, Icons.directions_run_rounded, accentColor),
            _buildNavBarItem(2, Icons.groups_rounded, accentColor),
            _buildNavBarItem(3, Icons.bar_chart_rounded, accentColor),
            _buildNavBarItem(4, Icons.emoji_events_rounded, accentColor),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBarItem(int index, IconData icon, Color accentColor) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: 48,
        height: 48,
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
          size: 24,
          color: isSelected
              ? accentColor
              : AppTheme.textSecondary.withOpacity(0.7),
        ),
      ),
    );
  }
}
