import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state_provider.dart';
import '../widgets/season_countdown_widget.dart';
import '../widgets/flip_points_widget.dart';
import '../services/season_service.dart';
import '../services/points_service.dart';
import 'map_screen.dart';
import 'running_screen.dart';
import 'crew_screen.dart';
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
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: _buildModernAppBar(context, appState, currentAccent),
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
        bottomNavigationBar: _buildIconNavigationBar(context, currentAccent),
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar(
    BuildContext context,
    AppStateProvider appState,
    Color accentColor,
  ) {
    final pointsService = context.watch<PointsService>();
    final topPadding = MediaQuery.of(context).padding.top;

    return PreferredSize(
      preferredSize: Size.fromHeight(topPadding + 68),
      child: Container(
        padding: EdgeInsets.only(top: topPadding),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                height: 52,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/runner_logo_transparent.png',
                        height: 24,
                        fit: BoxFit.contain,
                      ),
                      const Spacer(),
                      SeasonCountdownWidget(
                        seasonService: _seasonService,
                        compact: true,
                      ),
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
