import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/h3_config.dart';
import '../theme/app_theme.dart';
import '../models/team.dart';
import '../providers/leaderboard_provider.dart';
import '../providers/app_state_provider.dart';

/// Leaderboard Screen - Season Rankings by Flip Points
/// Redesigned: "Premium Athletic Minimal"
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with TickerProviderStateMixin {
  String _teamFilter = 'ALL';
  GeographicScope _scopeFilter = GeographicScope.all;
  late AnimationController _pulseController;
  late AnimationController _entranceController;
  final bool _useMockData = false;

  // Mock Data
  final List<LeaderboardRunner> _allRunners = [
    LeaderboardRunner(
      id: 'user_1',
      name: 'SpeedKing',
      team: Team.red,
      flipPoints: 2847,
      totalDistanceKm: 154.2,
      avatar: '🦊',
      crewName: 'Phoenix Squad',
      lastHexId: '89283082803ffff',
      zoneHexId: '88283082807ffff',
      cityHexId: '86283080fffffff',
      avgPaceMinPerKm: 5.25,
      stabilityScore: 92,
    ),
    LeaderboardRunner(
      id: 'user_2',
      name: 'AquaDash',
      team: Team.blue,
      flipPoints: 2654,
      totalDistanceKm: 148.5,
      avatar: '🐬',
      crewName: 'Tidal Force',
      lastHexId: '89283082813ffff',
      zoneHexId: '88283082817ffff',
      cityHexId: '86283080fffffff',
      avgPaceMinPerKm: 5.45,
      stabilityScore: 88,
    ),
    LeaderboardRunner(
      id: 'user_3',
      name: 'CrimsonBlur',
      team: Team.red,
      flipPoints: 2412,
      totalDistanceKm: 142.8,
      avatar: '🔥',
      crewName: 'Phoenix Squad',
      lastHexId: '89283082823ffff',
      zoneHexId: '88283082827ffff',
      cityHexId: '86283080fffffff',
      avgPaceMinPerKm: 5.10,
      stabilityScore: 85,
    ),
    LeaderboardRunner(
      id: 'user_4',
      name: 'WaveRider',
      team: Team.blue,
      flipPoints: 2198,
      totalDistanceKm: 135.0,
      avatar: '🌊',
      crewName: 'Ocean Runners',
      lastHexId: '89283082833ffff',
      zoneHexId: '88283082837ffff',
      cityHexId: '86283080fffffff',
      avgPaceMinPerKm: 6.00,
      stabilityScore: 78,
    ),
    LeaderboardRunner(
      id: 'user_5',
      name: 'ChaosAgent',
      team: Team.purple,
      flipPoints: 2156,
      totalDistanceKm: 68.2,
      avatar: '💀',
      crewName: 'Void Walkers',
      lastHexId: '89283082843ffff',
      zoneHexId: '88283082847ffff',
      cityHexId: '86283080fffffff',
      avgPaceMinPerKm: 4.80,
      stabilityScore: 45,
    ),
    LeaderboardRunner(
      id: 'user_6',
      name: 'NightOwl',
      team: Team.red,
      flipPoints: 1987,
      totalDistanceKm: 128.4,
      avatar: '🦉',
      crewName: 'Night Runners',
      lastHexId: '89283082853ffff',
      zoneHexId: '88283082857ffff',
      cityHexId: '86283080fffffff',
      avgPaceMinPerKm: 5.55,
      stabilityScore: 82,
    ),
    LeaderboardRunner(
      id: 'user_7',
      name: 'StormChaser',
      team: Team.blue,
      flipPoints: 1845,
      totalDistanceKm: 122.1,
      avatar: '⚡',
      crewName: 'Thunder Crew',
      lastHexId: '89283082863ffff',
      zoneHexId: null,
      cityHexId: '86283080fffffff',
      avgPaceMinPerKm: 5.30,
      stabilityScore: 75,
    ),
    LeaderboardRunner(
      id: 'user_8',
      name: 'VoidWalker',
      team: Team.purple,
      flipPoints: 1756,
      totalDistanceKm: 44.5,
      avatar: '🌀',
      crewName: 'Void Walkers',
      lastHexId: '89283082873ffff',
      zoneHexId: null,
      cityHexId: '86283080fffffff',
      avgPaceMinPerKm: 4.50,
      stabilityScore: 38,
    ),
    LeaderboardRunner(
      id: 'user_9',
      name: 'BlazeRunner',
      team: Team.red,
      flipPoints: 1634,
      totalDistanceKm: 115.7,
      avatar: '🌟',
      crewName: 'Blaze Squad',
      lastHexId: '89283082883ffff',
      zoneHexId: null,
      cityHexId: '86283080fffffff',
      avgPaceMinPerKm: 5.80,
      stabilityScore: 70,
    ),
    LeaderboardRunner(
      id: 'user_10',
      name: 'OceanSpirit',
      team: Team.blue,
      flipPoints: 1523,
      totalDistanceKm: 109.3,
      avatar: '🐋',
      crewName: 'Ocean Runners',
      lastHexId: '89283082893ffff',
      zoneHexId: null,
      cityHexId: '86283080fffffff',
      avgPaceMinPerKm: 6.20,
      stabilityScore: 65,
    ),
    LeaderboardRunner(
      id: 'user_11',
      name: 'PhoenixRise',
      team: Team.red,
      flipPoints: 1412,
      totalDistanceKm: 105.0,
      avatar: '🦅',
      crewName: 'Phoenix Squad',
      avgPaceMinPerKm: 5.40,
      stabilityScore: 80,
    ),
    LeaderboardRunner(
      id: 'user_12',
      name: 'DeepDive',
      team: Team.blue,
      flipPoints: 1298,
      totalDistanceKm: 98.6,
      avatar: '🐙',
      crewName: 'Tidal Force',
      avgPaceMinPerKm: 5.90,
      stabilityScore: 72,
    ),
    LeaderboardRunner(
      id: 'user_13',
      name: 'ShadowTraitor',
      team: Team.purple,
      flipPoints: 1245,
      totalDistanceKm: 32.1,
      avatar: '👁️',
      crewName: 'Shadow Protocol',
      avgPaceMinPerKm: 4.30,
      stabilityScore: 28,
    ),
    LeaderboardRunner(
      id: 'user_14',
      name: 'SparkPlug',
      team: Team.red,
      flipPoints: 1156,
      totalDistanceKm: 95.2,
      avatar: '✨',
      crewName: 'Blaze Squad',
      avgPaceMinPerKm: 5.70,
      stabilityScore: 68,
    ),
    LeaderboardRunner(
      id: 'user_15',
      name: 'TidalWave',
      team: Team.blue,
      flipPoints: 1087,
      totalDistanceKm: 92.1,
      avatar: '🌊',
      crewName: 'Thunder Crew',
      avgPaceMinPerKm: 6.10,
      stabilityScore: 60,
    ),
  ];

  List<LeaderboardRunner> _getFilteredRunners(BuildContext context) {
    final leaderboardProvider = context.watch<LeaderboardProvider>();
    final entries = leaderboardProvider.entries;

    List<LeaderboardRunner> runners;

    if (_useMockData || entries.isEmpty) {
      runners = List<LeaderboardRunner>.from(_allRunners);
    } else {
      runners = entries
          .map(
            (e) => LeaderboardRunner(
              id: e.id,
              name: e.name,
              team: e.team,
              flipPoints: e.seasonPoints,
              totalDistanceKm: e.totalDistanceKm,
              avatar: e.avatar,
              crewName: null,
              avgPaceMinPerKm: e.avgPaceMinPerKm,
              stabilityScore: e.stabilityScore,
            ),
          )
          .toList();
    }

    if (_teamFilter != 'ALL') {
      final teamFilter = _teamFilter == 'RED'
          ? Team.red
          : _teamFilter == 'BLUE'
          ? Team.blue
          : Team.purple;
      runners = runners.where((r) => r.team == teamFilter).toList();
    }

    switch (_scopeFilter) {
      case GeographicScope.zone:
        runners = runners.where((r) => r.zoneHexId != null).toList();
        runners = runners.take(6).toList();
        break;
      case GeographicScope.city:
        runners = runners.where((r) => r.cityHexId != null).toList();
        runners = runners.take(10).toList();
        break;
      case GeographicScope.all:
        break;
    }

    return runners;
  }

  String? _getCurrentUserId(BuildContext context) {
    return context.read<AppStateProvider>().currentUser?.id;
  }

  bool _isCurrentUserVisible(
    BuildContext context,
    List<LeaderboardRunner> runners,
  ) {
    final userId = _getCurrentUserId(context);
    if (userId == null) return false;
    return runners.any((r) => r.id == userId);
  }

  int _getCurrentUserRank(
    BuildContext context,
    List<LeaderboardRunner> runners,
  ) {
    final userId = _getCurrentUserId(context);
    if (userId == null) return -1;
    final index = runners.indexWhere((r) => r.id == userId);
    return index >= 0 ? index + 1 : -1;
  }

  LeaderboardRunner? _getCurrentUserData(BuildContext context) {
    final userId = _getCurrentUserId(context);
    if (userId == null) return null;

    final leaderboardProvider = context.read<LeaderboardProvider>();
    final entries = leaderboardProvider.entries;

    if (_useMockData || entries.isEmpty) {
      try {
        return _allRunners.firstWhere((r) => r.id == userId);
      } catch (_) {
        return null;
      }
    }

    final entry = leaderboardProvider.getUser(userId);
    if (entry == null) return null;

    return LeaderboardRunner(
      id: entry.id,
      name: entry.name,
      team: entry.team,
      flipPoints: entry.seasonPoints,
      totalDistanceKm: entry.totalDistanceKm,
      avatar: entry.avatar,
      avgPaceMinPerKm: entry.avgPaceMinPerKm,
      stabilityScore: entry.stabilityScore,
    );
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeaderboardProvider>().fetchLeaderboard();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final runners = _getFilteredRunners(context);
    final currentUserId = _getCurrentUserId(context);
    final isUserVisible = _isCurrentUserVisible(context, runners);
    final currentUserData = _getCurrentUserData(context);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      color: AppTheme.backgroundStart,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  _buildConsolidatedFilterBar(),
                  Expanded(
                    child: runners.isEmpty
                        ? _buildEmptyState()
                        : CustomScrollView(
                            physics: const BouncingScrollPhysics(),
                            slivers: [
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 20),
                              ),
                              if (runners.isNotEmpty)
                                SliverToBoxAdapter(
                                  child: _buildPodium(runners, isLandscape),
                                ),
                              if (runners.length > 3)
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    20,
                                    20,
                                    100,
                                  ),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate((
                                      context,
                                      index,
                                    ) {
                                      final listIndex = index + 3;
                                      if (listIndex >= runners.length) {
                                        return null;
                                      }
                                      return _buildRankTile(
                                        runners[listIndex],
                                        listIndex + 1,
                                        index,
                                        currentUserId,
                                      );
                                    }, childCount: runners.length - 3),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),

              if (!isUserVisible && currentUserData != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildMyRankFooter(
                    currentUserData,
                    _getCurrentUserRank(context, runners),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SEASON RANKINGS',
                style: GoogleFonts.bebasNeue(
                  fontSize: 28,
                  color: Colors.white,
                  letterSpacing: 2.0,
                ),
              ),
              Text(
                'Ranked by flip points',
                style: GoogleFonts.sora(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CONSOLIDATED FILTER BAR
  // ---------------------------------------------------------------------------

  Widget _buildConsolidatedFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                // Team Filters
                _buildTeamFilterIcon(Team.red, 'RED'),
                const SizedBox(width: 4),
                _buildTeamFilterIcon(Team.blue, 'BLUE'),
                const SizedBox(width: 4),
                _buildTeamFilterIcon(Team.purple, 'PURPLE'),
                const SizedBox(width: 4),
                _buildAllTeamFilter(),

                // Divider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    width: 1,
                    height: 20,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),

                // Scope Filter
                Expanded(child: _buildScopeDropdown()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamFilterIcon(Team team, String filterValue) {
    final isSelected = _teamFilter == filterValue;
    return GestureDetector(
      onTap: () => setState(() => _teamFilter = filterValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected
              ? team.color.withValues(alpha: 0.2)
              : Colors.transparent,
          border: isSelected
              ? Border.all(color: team.color, width: 1.5)
              : Border.all(color: Colors.transparent),
        ),
        child: Center(
          child: Text(team.emoji, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }

  Widget _buildAllTeamFilter() {
    final isSelected = _teamFilter == 'ALL';
    return GestureDetector(
      onTap: () => setState(() => _teamFilter = 'ALL'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isSelected
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.transparent,
        ),
        child: Text(
          'ALL',
          style: GoogleFonts.bebasNeue(
            fontSize: 16,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildScopeDropdown() {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_scopeFilter == GeographicScope.all) {
            _scopeFilter = GeographicScope.city;
          } else if (_scopeFilter == GeographicScope.city) {
            _scopeFilter = GeographicScope.zone;
          } else {
            _scopeFilter = GeographicScope.all;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              _scopeFilter.label.toUpperCase(),
              style: GoogleFonts.sora(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down_rounded,
              color: Colors.white.withValues(alpha: 0.5),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PODIUM (Top 3)
  // ---------------------------------------------------------------------------

  Widget _buildPodium(List<LeaderboardRunner> runners, bool isLandscape) {
    return SizedBox(
      height: isLandscape ? 200 : 280,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // 2nd Place (Left)
          if (runners.length > 1)
            Positioned(
              left: isLandscape ? 40 : 20,
              bottom: 0,
              child: _buildPodiumCard(runners[1], 2, isLandscape),
            ),

          // 3rd Place (Right)
          if (runners.length > 2)
            Positioned(
              right: isLandscape ? 40 : 20,
              bottom: 0,
              child: _buildPodiumCard(runners[2], 3, isLandscape),
            ),

          // 1st Place (Center - Z-index highest)
          Positioned(
            bottom: isLandscape ? 10 : 20,
            child: _buildPodiumCard(runners[0], 1, isLandscape),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumCard(
    LeaderboardRunner runner,
    int rank,
    bool isLandscape,
  ) {
    final isFirst = rank == 1;
    final scale = isLandscape ? 0.7 : 1.0;
    final width = (isFirst ? 140.0 : 110.0) * scale;
    final height =
        (isFirst ? 240.0 : 200.0) * scale; // Reduced to prevent overflow
    final teamColor = runner.team.color;

    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _entranceController,
        curve: Interval(
          isFirst ? 0.0 : 0.2,
          isFirst ? 0.6 : 0.8,
          curve: Curves.elasticOut,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24 * scale),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: width,
            height: height,
            padding: EdgeInsets.symmetric(vertical: 8 * scale),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(24 * scale),
              border: Border.all(
                color: isFirst
                    ? teamColor.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
                if (isFirst)
                  BoxShadow(
                    color: teamColor.withValues(alpha: 0.1),
                    blurRadius: 30,
                    spreadRadius: -5,
                  ),
              ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Rank Number
                  Text(
                    '$rank',
                    style: GoogleFonts.bebasNeue(
                      fontSize: isFirst ? 64 : 48,
                      height: 1.0,
                      color: Colors.white.withValues(alpha: 0.9),
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Avatar
                  Text(
                    runner.avatar,
                    style: TextStyle(fontSize: isFirst ? 48 : 36),
                  ),

                  const SizedBox(height: 4),

                  // Name
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      runner.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sora(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  // Points
                  Text(
                    '${runner.flipPoints}',
                    style: GoogleFonts.sora(
                      fontSize: isFirst ? 28 : 20,
                      fontWeight: FontWeight.w700,
                      color: teamColor,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Secondary stats row: distance + stability
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Distance
                      Text(
                        '${runner.totalDistanceKm.toStringAsFixed(0)}km',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.white54,
                        ),
                      ),
                      if (runner.stabilityScore != null) ...[
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 2,
                          height: 2,
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                        ),
                        // Stability badge
                        Text(
                          '${runner.stabilityScore}%',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _getStabilityColor(runner.stabilityScore!),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RANK LIST (4th+)
  // ---------------------------------------------------------------------------

  Widget _buildRankTile(
    LeaderboardRunner runner,
    int rank,
    int index,
    String? currentUserId,
  ) {
    final isCurrentUser = runner.id == currentUserId;
    final teamColor = runner.team.color;
    final isPurple = runner.team == Team.purple;
    final showPurpleGlow = isPurple && _teamFilter == 'ALL';

    // Staggered entrance
    final startInterval = 0.4 + (index * 0.05).clamp(0.0, 0.4);
    final endInterval = (startInterval + 0.4).clamp(0.0, 1.0);

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
          .animate(
            CurvedAnimation(
              parent: _entranceController,
              curve: Interval(
                startInterval,
                endInterval,
                curve: Curves.easeOutQuad,
              ),
            ),
          ),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _entranceController,
          curve: Interval(startInterval, endInterval, curve: Curves.easeOut),
        ),
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final glowOpacity = showPurpleGlow
                ? 0.1 + (_pulseController.value * 0.15)
                : 0.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? teamColor.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: showPurpleGlow
                    ? Border.all(
                        color: teamColor.withValues(alpha: 0.4),
                        width: 1,
                      )
                    : isCurrentUser
                    ? Border.all(
                        color: teamColor.withValues(alpha: 0.2),
                        width: 1,
                      )
                    : null,
                boxShadow: showPurpleGlow
                    ? [
                        BoxShadow(
                          color: teamColor.withValues(alpha: glowOpacity),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  // Rank
                  SizedBox(
                    width: 32,
                    child: Text(
                      '$rank',
                      style: GoogleFonts.sora(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isCurrentUser
                            ? teamColor
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),

                  // Avatar
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      runner.avatar,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Name
                  Expanded(
                    child: Text(
                      runner.name,
                      style: GoogleFonts.sora(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Distance (matching podium format)
                  if (runner.totalDistanceKm > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '${runner.totalDistanceKm.toStringAsFixed(0)}km',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.white54,
                        ),
                      ),
                    ),

                  // Stability badge (if available)
                  if (runner.stabilityScore != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getStabilityColor(
                          runner.stabilityScore!,
                        ).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${runner.stabilityScore}%',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _getStabilityColor(runner.stabilityScore!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Points
                  Text(
                    '${runner.flipPoints}',
                    style: GoogleFonts.sora(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Team Dot
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: teamColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: teamColor.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STICKY FOOTER
  // ---------------------------------------------------------------------------

  Widget _buildMyRankFooter(LeaderboardRunner user, int rank) {
    final teamColor = user.team.color;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.8),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Text(
                  'YOUR RANK',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 24,
                    color: AppTheme.textSecondary,
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                Text(
                  rank > 0 ? '#$rank' : '—',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 24,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 24),
                Text(
                  '${user.flipPoints}',
                  style: GoogleFonts.sora(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: teamColor,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'pts',
                  style: GoogleFonts.sora(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Get color for stability score badge
  /// Green = high stability (>80), Yellow = medium (50-80), Red = low (<50)
  Color _getStabilityColor(int score) {
    if (score >= 80) return const Color(0xFF22C55E); // Green
    if (score >= 50) return const Color(0xFFF59E0B); // Amber
    return const Color(0xFFEF4444); // Red
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),
          Text(
            'No runners found',
            style: GoogleFonts.sora(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DATA MODEL
// ---------------------------------------------------------------------------

class LeaderboardRunner {
  final String id;
  final String name;
  final Team team;
  final int flipPoints;
  final double totalDistanceKm;
  final String avatar;
  final String? crewName;
  final String? lastHexId;
  final String? zoneHexId;
  final String? cityHexId;

  /// Average pace in min/km (null if no runs)
  final double? avgPaceMinPerKm;

  /// Stability score (0-100, higher = more consistent pace)
  final int? stabilityScore;

  const LeaderboardRunner({
    required this.id,
    required this.name,
    required this.team,
    required this.flipPoints,
    required this.totalDistanceKm,
    required this.avatar,
    this.crewName,
    this.lastHexId,
    this.zoneHexId,
    this.cityHexId,
    this.avgPaceMinPerKm,
    this.stabilityScore,
  });

  /// Format pace as "X'XX" (e.g., "5'30")
  String get formattedPace {
    if (avgPaceMinPerKm == null ||
        avgPaceMinPerKm!.isInfinite ||
        avgPaceMinPerKm!.isNaN ||
        avgPaceMinPerKm == 0) {
      return "-'--";
    }
    final min = avgPaceMinPerKm!.floor();
    final sec = ((avgPaceMinPerKm! - min) * 60).round();
    return "$min'${sec.toString().padLeft(2, '0')}";
  }
}
