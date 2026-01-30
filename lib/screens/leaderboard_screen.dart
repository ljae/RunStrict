import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/h3_config.dart';
import '../theme/app_theme.dart';
import '../models/team.dart';
import '../providers/leaderboard_provider.dart';
import '../providers/app_state_provider.dart';

/// Period filter for leaderboard rankings
enum RankingPeriod { total, week, month, year }

/// Leaderboard Screen - Rankings by Flip Points
/// Redesigned: Minimal design matching History screen
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with TickerProviderStateMixin {
  RankingPeriod _selectedPeriod = RankingPeriod.total;
  GeographicScope _scopeFilter = GeographicScope.all;
  late AnimationController _pulseController;
  late AnimationController _entranceController;
  final bool _useMockData = false;

  // Range-based navigation state
  DateTime _rangeStart = DateTime.now();
  DateTime _rangeEnd = DateTime.now();

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

    // Initialize range based on current date and default period
    _calculateRange(DateTime.now(), _selectedPeriod);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeaderboardProvider>().fetchLeaderboard();
    });
  }

  /// Calculate range boundaries based on anchor date and period
  void _calculateRange(DateTime anchorDate, RankingPeriod period) {
    switch (period) {
      case RankingPeriod.total:
        // Total = all time, no range needed
        _rangeStart = DateTime(2020, 1, 1); // Arbitrary early date
        _rangeEnd = DateTime.now().add(const Duration(days: 1));
        break;
      case RankingPeriod.week:
        // Week starts Sunday (weekday % 7 gives Sunday = 0)
        final dayOfWeek = anchorDate.weekday % 7;
        _rangeStart = DateTime(
          anchorDate.year,
          anchorDate.month,
          anchorDate.day - dayOfWeek,
        );
        _rangeEnd = _rangeStart.add(const Duration(days: 6));
        break;
      case RankingPeriod.month:
        // First to last day of month
        _rangeStart = DateTime(anchorDate.year, anchorDate.month, 1);
        _rangeEnd = DateTime(anchorDate.year, anchorDate.month + 1, 0);
        break;
      case RankingPeriod.year:
        // Jan 1 to Dec 31
        _rangeStart = DateTime(anchorDate.year, 1, 1);
        _rangeEnd = DateTime(anchorDate.year, 12, 31);
        break;
    }
  }

  /// Navigate to previous range (week/month/year)
  void _navigatePrevious() {
    if (_selectedPeriod == RankingPeriod.total) return;
    DateTime newAnchor;
    switch (_selectedPeriod) {
      case RankingPeriod.total:
        return;
      case RankingPeriod.week:
        newAnchor = _rangeStart.subtract(const Duration(days: 7));
        break;
      case RankingPeriod.month:
        newAnchor = DateTime(_rangeStart.year, _rangeStart.month - 1, 1);
        break;
      case RankingPeriod.year:
        newAnchor = DateTime(_rangeStart.year - 1, 1, 1);
        break;
    }
    setState(() {
      _calculateRange(newAnchor, _selectedPeriod);
    });
  }

  /// Navigate to next range (week/month/year)
  void _navigateNext() {
    if (_selectedPeriod == RankingPeriod.total) return;
    DateTime newAnchor;
    switch (_selectedPeriod) {
      case RankingPeriod.total:
        return;
      case RankingPeriod.week:
        newAnchor = _rangeStart.add(const Duration(days: 7));
        break;
      case RankingPeriod.month:
        newAnchor = DateTime(_rangeStart.year, _rangeStart.month + 1, 1);
        break;
      case RankingPeriod.year:
        newAnchor = DateTime(_rangeStart.year + 1, 1, 1);
        break;
    }
    setState(() {
      _calculateRange(newAnchor, _selectedPeriod);
    });
  }

  /// Format range display based on period
  String _formatRangeDisplay() {
    switch (_selectedPeriod) {
      case RankingPeriod.total:
        return 'ALL TIME';
      case RankingPeriod.week:
        // "Jan 26 - Feb 1" or "Dec 28 - Jan 3, 2027" if years differ
        final startFormat = DateFormat('MMM d');
        if (_rangeStart.year != _rangeEnd.year) {
          return '${startFormat.format(_rangeStart)} - ${DateFormat('MMM d, yyyy').format(_rangeEnd)}';
        } else if (_rangeStart.month != _rangeEnd.month) {
          return '${startFormat.format(_rangeStart)} - ${DateFormat('MMM d').format(_rangeEnd)}';
        } else {
          return '${startFormat.format(_rangeStart)} - ${_rangeEnd.day}';
        }
      case RankingPeriod.month:
        // "JANUARY 2026"
        return DateFormat('MMMM yyyy').format(_rangeStart).toUpperCase();
      case RankingPeriod.year:
        // "2026"
        return _rangeStart.year.toString();
    }
  }

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
      // Use mock data for development/testing
      runners = List<LeaderboardRunner>.from(_allRunners);

      // Apply mock scope filtering (no team filter - all teams shown)
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
    } else {
      // Use real data with home-hex-anchored scope filtering (no team filter)
      final filteredEntries = leaderboardProvider.filterByTeamAndScope(
        null, // No team filter - show all teams
        _scopeFilter,
      );

      runners = filteredEntries
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
                  const SizedBox(height: 8),
                  _buildPeriodToggle(),
                  const SizedBox(height: 12),
                  _buildRangeNavigation(),
                  const SizedBox(height: 8),
                  _buildFilterBar(),
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
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Text(
        'RANKINGS',
        style: GoogleFonts.sora(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CONSOLIDATED FILTER BAR
  // ---------------------------------------------------------------------------

  /// Period toggle: TOTAL | WEEK | MONTH | YEAR
  Widget _buildPeriodToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: RankingPeriod.values.map((period) {
            final isSelected = _selectedPeriod == period;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPeriod = period;
                    _calculateRange(DateTime.now(), period);
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    period.name.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.white38,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Range navigation: < Jan 26 - Feb 1 >
  Widget _buildRangeNavigation() {
    final isTotal = _selectedPeriod == RankingPeriod.total;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous arrow
          GestureDetector(
            onTap: isTotal ? null : _navigatePrevious,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              child: Icon(
                Icons.chevron_left_rounded,
                color: isTotal ? Colors.white12 : Colors.white54,
                size: 24,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Range display
          Expanded(
            child: Text(
              _formatRangeDisplay(),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
                letterSpacing: 0.5,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Next arrow
          GestureDetector(
            onTap: isTotal ? null : _navigateNext,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              child: Icon(
                Icons.chevron_right_rounded,
                color: isTotal ? Colors.white12 : Colors.white54,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Combined filter bar: Scope dropdown only (team filter removed)
  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [_buildScopeDropdown()],
      ),
    );
  }

  /// Get the icon for a geographic scope (matching MapScreen's _ZoomLevelSelector)
  IconData _getScopeIcon(GeographicScope scope) {
    return switch (scope) {
      GeographicScope.zone => Icons.grid_view_rounded,
      GeographicScope.city => Icons.location_city_rounded,
      GeographicScope.all => Icons.public_rounded,
    };
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
            Icon(
              _getScopeIcon(_scopeFilter),
              color: AppTheme.electricBlue,
              size: 18,
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
    // Always show purple glow since all teams are displayed (no team filter)
    final showPurpleGlow = isPurple;

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
