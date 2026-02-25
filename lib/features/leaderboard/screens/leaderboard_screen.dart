import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/config/h3_config.dart';
import '../../../theme/app_theme.dart';
import '../providers/leaderboard_provider.dart';
import '../../../core/providers/user_repository_provider.dart';
import '../../../core/services/prefetch_service.dart';
import '../../../core/services/season_service.dart';
import '../../auth/providers/app_state_provider.dart';

/// League scope for leaderboard rankings
enum LeagueScope { myLeague, globalTop100 }

/// Leaderboard Screen - Rankings by Flip Points (Season-based)
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _entranceController;
  LeagueScope _selectedScope = LeagueScope.myLeague;
  late int _currentSeason;
  late int _totalSeasons;

  @override
  void initState() {
    super.initState();
    final seasonService = SeasonService();
    _currentSeason = seasonService.seasonNumber;
    _totalSeasons = seasonService.seasonNumber;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isGuest = ref.read(appStateProvider).isGuest;
      if (!isGuest) {
        ref.read(leaderboardProvider.notifier).fetchLeaderboard(limit: _scopeLimit);
      }
    });
  }

  bool get _isViewingCurrentSeason => _currentSeason == _totalSeasons;

  void _navigatePreviousSeason() {
    if (_currentSeason > 1) {
      setState(() => _currentSeason--);
      _fetchForSeason();
    }
  }

  void _navigateNextSeason() {
    if (_currentSeason < _totalSeasons) {
      setState(() => _currentSeason++);
      _fetchForSeason();
    }
  }

  int get _scopeLimit =>
      _selectedScope == LeagueScope.myLeague ? 50 : 100;

  void _fetchForSeason() {
    final notifier = ref.read(leaderboardProvider.notifier);
    if (_isViewingCurrentSeason) {
      notifier.clearHistorical();
      notifier.fetchLeaderboard(limit: _scopeLimit, forceRefresh: true);
    } else {
      notifier.fetchScopedSeasonLeaderboard(
        _currentSeason,
        limit: _scopeLimit,
      );
    }
    // Replay entrance animation on season switch
    _entranceController.forward(from: 0);
  }

  String _formatSeasonDisplay() {
    if (_isViewingCurrentSeason) return 'SEASON $_currentSeason';
    return 'SEASON $_currentSeason  ❄️';
  }

  List<LeaderboardEntry> _getFilteredRunners(BuildContext context) {
    final limit = _scopeLimit;
    final state = ref.watch(leaderboardProvider);
    final notifier = ref.read(leaderboardProvider.notifier);
    List<LeaderboardEntry> results;
    if (_isViewingCurrentSeason) {
      if (_selectedScope == LeagueScope.myLeague) {
        // Province-scoped leaderboard from PrefetchService
        results = PrefetchService().getLeaderboardForScope(GeographicScope.all);
      } else {
        results = state.entries;
      }
    } else {
      // Historical: snapshot data, filtered client-side for MY LEAGUE
      if (_selectedScope == LeagueScope.myLeague) {
        results = notifier.filterByScope(GeographicScope.all);
      } else {
        results = state.entries;
      }
    }
    // Cap to scope limit: 50 for province, 100 for global
    if (results.length > limit) {
      return results.sublist(0, limit);
    }
    return results;
  }

  String? _getCurrentUserId(BuildContext context) {
    return ref.read(userRepositoryProvider)?.id;
  }

  bool _isCurrentUserVisible(
    BuildContext context,
    List<LeaderboardEntry> runners,
  ) {
    final userId = _getCurrentUserId(context);
    if (userId == null) return false;
    return runners.any((r) => r.id == userId);
  }

  int _getCurrentUserRank(
    BuildContext context,
    List<LeaderboardEntry> runners,
  ) {
    final userId = _getCurrentUserId(context);
    if (userId == null) return -1;
    final index = runners.indexWhere((r) => r.id == userId);
    return index >= 0 ? index + 1 : -1;
  }

  LeaderboardEntry? _getCurrentUserData(BuildContext context) {
    final currentUser = ref.read(userRepositoryProvider);
    if (currentUser == null) return null;

    // Always create from user repository (current season live data)
    // Rank is computed from the currently displayed list in the footer
    return LeaderboardEntry(user: currentUser, rank: 0);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Widget _buildGuestOverlay(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Registration needed',
                style: GoogleFonts.sora(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign up to view leaderboard rankings',
                textAlign: TextAlign.center,
                style: GoogleFonts.sora(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(appStateProvider.notifier).endGuestSession();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.electricBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'SIGN UP',
                    style: GoogleFonts.sora(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = ref.watch(appStateProvider.select((s) => s.isGuest));
    if (isGuest) return _buildGuestOverlay(context);

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
              isLandscape
                  // Landscape: everything scrolls together
                  ? runners.isEmpty
                      ? _buildEmptyState()
                      : CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: _buildSeasonStatsSection(context),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: _buildLeagueToggle(),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: _buildSeasonNavigation(),
                              ),
                            ),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 16),
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
                        )
                  // Portrait: stats pinned at top, list scrolls below
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        _buildSeasonStatsSection(context),
                        const SizedBox(height: 12),
                        _buildLeagueToggle(),
                        const SizedBox(height: 8),
                        _buildSeasonNavigation(),
                        const SizedBox(height: 16),
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
                                        child: _buildPodium(
                                          runners,
                                          isLandscape,
                                        ),
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
                                          delegate:
                                              SliverChildBuilderDelegate((
                                                context,
                                                index,
                                              ) {
                                                final listIndex = index + 3;
                                                if (listIndex >=
                                                    runners.length) {
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

              if (currentUserData != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildMyRankFooter(
                    currentUserData,
                    _getCurrentUserRank(context, runners),
                    showStats: !isUserVisible,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SEASON STATS & CONTROLS (Matching History Screen Design)
  // ---------------------------------------------------------------------------

  String _seasonRecordLabel() {
    final season = SeasonService();
    final remaining = season.daysRemaining;
    final yesterdayDDay = remaining + 1;
    if (remaining >= 0 && yesterdayDDay <= SeasonService.seasonDurationDays) {
      return 'SEASON RECORD  until D-$yesterdayDDay';
    }
    return 'SEASON RECORD';
  }

  /// Season stats section - "SEASON RECORD until D-XX"
  /// Shows cumulative stats through YESTERDAY (midnight GMT+2), not live.
  /// Points = totalSeasonPoints - todayFlipPoints (subtracts today's contribution).
  /// Rank derived from leaderboard entries (live users table).
  Widget _buildSeasonStatsSection(BuildContext context) {
    final currentUser = ref.watch(userRepositoryProvider);

    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    // Season record shows data through yesterday (midnight GMT+2).
    // get_leaderboard RPC already excludes today's points, so use the
    // leaderboard entry for all stats (points, distance, pace, rank).
    // If the user isn't in the leaderboard (no yesterday data), show zeros.
    final currentSeasonRunners =
        PrefetchService().getLeaderboardForScope(GeographicScope.all);
    final rank = _getCurrentUserRank(context, currentSeasonRunners);
    final userId = _getCurrentUserId(context);
    final leaderboardEntry = userId != null
        ? currentSeasonRunners
            .where((e) => e.id == userId)
            .firstOrNull
        : null;

    final seasonRecordPoints = leaderboardEntry?.seasonPoints ?? 0;
    final liveDistance = leaderboardEntry?.totalDistanceKm ?? 0.0;
    final livePace = leaderboardEntry?.avgPaceMinPerKm;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.03)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Season label (matching ALL TIME style)
            Text(
              _seasonRecordLabel(),
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.2),
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 12),
            // Stats in a row with separators (matching ALL TIME layout)
            Row(
              children: [
                // Points - primary highlight (white like distance in ALL TIME)
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$seasonRecordPoints',
                            style: GoogleFonts.sora(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'pts',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white30,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Vertical divider
                Container(
                  width: 1,
                  height: 32,
                  color: Colors.white.withOpacity(0.06),
                ),
                // Secondary stats (matching ALL TIME: 4 items with flex: 4)
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSeasonMiniStat(
                          _formatCompact(liveDistance),
                          'km',
                        ),
                        _buildSeasonMiniStat(
                          _formatPace(livePace),
                          '/km',
                        ),
                        _buildSeasonMiniStat(rank > 0 ? '#$rank' : '—', 'rank'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Mini stat for season stats panel
  Widget _buildSeasonMiniStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.sora(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: Colors.white24,
          ),
        ),
      ],
    );
  }

  /// League toggle: MY LEAGUE | GLOBAL TOP 100
  Widget _buildLeagueToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor.withOpacity(0.3),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: LeagueScope.values.map((scope) {
            final isSelected = _selectedScope == scope;
            final icon = scope == LeagueScope.myLeague
                ? Icons.people_rounded
                : Icons.public_rounded;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_selectedScope == scope) return;
                  setState(() => _selectedScope = scope);
                  // Re-fetch with scope-appropriate limit (50 province / 100 global)
                  _fetchForSeason();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: 18,
                    color: isSelected ? Colors.white : Colors.white38,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Season navigation with prev/next controls
  Widget _buildSeasonNavigation() {
    final canGoPrevious = _currentSeason > 1;
    final canGoNext = _currentSeason < _totalSeasons;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous arrow
          GestureDetector(
            onTap: canGoPrevious ? _navigatePreviousSeason : null,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              child: Icon(
                Icons.chevron_left_rounded,
                color: canGoPrevious ? Colors.white54 : Colors.white12,
                size: 24,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Season display
          Expanded(
            child: Text(
              _formatSeasonDisplay(),
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
            onTap: canGoNext ? _navigateNextSeason : null,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              child: Icon(
                Icons.chevron_right_rounded,
                color: canGoNext ? Colors.white54 : Colors.white12,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Format pace as "X'XX" (e.g., "5'30")
  String _formatPace(double? paceMinPerKm) {
    if (paceMinPerKm == null ||
        paceMinPerKm.isInfinite ||
        paceMinPerKm.isNaN ||
        paceMinPerKm == 0) {
      return "-'--";
    }
    final min = paceMinPerKm.floor();
    final sec = ((paceMinPerKm - min) * 60).round();
    return "$min'${sec.toString().padLeft(2, '0')}";
  }

  /// Format large numbers with K suffix (e.g., 10232 → "10.2K")
  String _formatCompact(num value) {
    if (value >= 1000) {
      final k = value / 1000;
      return '${k.toStringAsFixed(1)}K';
    }
    return value is double ? value.toStringAsFixed(1) : value.toString();
  }

  // ---------------------------------------------------------------------------
  // PODIUM (Top 3)
  // ---------------------------------------------------------------------------

  Widget _buildPodium(List<LeaderboardEntry> runners, bool isLandscape) {
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
    LeaderboardEntry runner,
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

                  // Name + Flag
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (runner.nationalityFlag != null) ...[
                          Text(
                            runner.nationalityFlag!,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
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
                      ],
                    ),
                  ),

                  // Province name (GLOBAL TOP 100 only)
                  if (_selectedScope == LeagueScope.globalTop100 &&
                      runner.provinceName != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        runner.provinceName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: Colors.white30,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),

                  // Manifesto
                  if (runner.manifesto != null &&
                      runner.manifesto!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _ElectricManifesto(
                        manifesto: runner.manifesto!,
                        teamColor: teamColor,
                        fontSize: 10,
                        isCentered: true,
                      ),
                    ),
                  ],

                  const SizedBox(height: 4),

                  // Points
                  Text(
                    '${runner.seasonPoints}',
                    style: GoogleFonts.sora(
                      fontSize: isFirst ? 28 : 20,
                      fontWeight: FontWeight.w700,
                      color: teamColor,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Secondary stats row: distance + pace
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Distance
                      Text(
                        '${_formatCompact(runner.totalDistanceKm)}km',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.white54,
                        ),
                      ),
                      if (runner.avgPaceMinPerKm != null &&
                          runner.avgPaceMinPerKm! > 0) ...[
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 2,
                          height: 2,
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                        ),
                        // Pace
                        Text(
                          '${runner.formattedPace}/km',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.white54,
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
    LeaderboardEntry runner,
    int rank,
    int index,
    String? currentUserId,
  ) {
    final isCurrentUser = runner.id == currentUserId;
    final teamColor = runner.team.color;

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
            final glowOpacity = true
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
                border: true
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
                boxShadow: true
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

                  const SizedBox(width: 12),

                  // Name & Manifesto
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if (runner.nationalityFlag != null) ...[
                              Text(
                                runner.nationalityFlag!,
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Flexible(
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
                          ],
                        ),
                        // Province name (GLOBAL TOP 100 only)
                        if (_selectedScope == LeagueScope.globalTop100 &&
                            runner.provinceName != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(
                              runner.provinceName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.white24,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        if (runner.manifesto != null &&
                            runner.manifesto!.isNotEmpty)
                          _ElectricManifesto(
                            manifesto: runner.manifesto!,
                            teamColor: teamColor,
                            fontSize: 11,
                            isCentered: false,
                          ),
                      ],
                    ),
                  ),

                  // Distance + Pace (matching podium format)
                  if (runner.totalDistanceKm > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_formatCompact(runner.totalDistanceKm)}km',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.white54,
                            ),
                          ),
                          if (runner.avgPaceMinPerKm != null &&
                              runner.avgPaceMinPerKm! > 0) ...[
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 2,
                              height: 2,
                              decoration: const BoxDecoration(
                                color: Colors.white24,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Text(
                              '${runner.formattedPace}/km',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                  // Points
                  Text(
                    '${runner.seasonPoints}',
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

  Widget _buildMyRankFooter(
    LeaderboardEntry user,
    int rank, {
    bool showStats = true,
  }) {
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
                // Profile button (always visible)
                GestureDetector(
                  onTap: () {
                    context.push('/profile');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: teamColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: teamColor.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_outline, color: teamColor, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'PROFILE',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: teamColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                if (showStats) ...[
                  Text(
                    rank > 0 ? '#$rank' : '—',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 24,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Text(
                    '${user.seasonPoints}',
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
              ],
            ),
          ),
        ),
      ),
    );
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
// ELECTRIC MANIFESTO WIDGET
// ---------------------------------------------------------------------------

class _ElectricManifesto extends StatefulWidget {
  final String manifesto;
  final Color teamColor;
  final double fontSize;
  final bool isCentered;

  const _ElectricManifesto({
    required this.manifesto,
    required this.teamColor,
    this.fontSize = 10.0,
    this.isCentered = false,
  });

  @override
  State<_ElectricManifesto> createState() => _ElectricManifestoState();
}

class _ElectricManifestoState extends State<_ElectricManifesto>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.white54, widget.teamColor, Colors.white54],
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ],
              tileMode: TileMode.clamp,
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: Text(
            widget.manifesto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sora(
              fontSize: widget.fontSize,
              fontStyle: FontStyle.italic,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: widget.teamColor.withValues(alpha: 0.6),
                  blurRadius: 8,
                ),
              ],
            ),
            textAlign: widget.isCentered ? TextAlign.center : TextAlign.start,
          ),
        );
      },
    );
  }
}

