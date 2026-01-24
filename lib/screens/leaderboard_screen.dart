import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/team.dart';

/// Leaderboard Screen - Season Rankings by Flip Points
/// Per DEVELOPMENT_SPEC §3.2.5 & §2.6:
/// - Team Tabs: [ALL] / [RED] / [BLUE] / [PURPLE]
/// - Scope Tabs: [ALL] / [City] / [Zone]
/// - Top rankings for selected scope
/// - Sticky Footer: "My Rank" (if user outside top displayed)
/// - Purple Users: Glowing border in [ALL] tab
/// - Per User: Avatar, Name, Flip Points
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  String _teamFilter = 'ALL';
  String _scopeFilter = 'ALL';
  late AnimationController _pulseController;

  // Mock current user ID for highlighting
  static const String _currentUserId = 'user_1';

  // Mock Data - In production, fetched via Supabase RPC: get_leaderboard()
  final List<LeaderboardRunner> _allRunners = [
    LeaderboardRunner(
      id: 'user_1',
      name: 'SpeedKing',
      team: Team.red,
      flipPoints: 2847,
      totalDistanceKm: 154.2,
      avatar: '🦊',
      crewName: 'Phoenix Squad',
    ),
    LeaderboardRunner(
      id: 'user_2',
      name: 'AquaDash',
      team: Team.blue,
      flipPoints: 2654,
      totalDistanceKm: 148.5,
      avatar: '🐬',
      crewName: 'Tidal Force',
    ),
    LeaderboardRunner(
      id: 'user_3',
      name: 'CrimsonBlur',
      team: Team.red,
      flipPoints: 2412,
      totalDistanceKm: 142.8,
      avatar: '🔥',
      crewName: 'Phoenix Squad',
    ),
    LeaderboardRunner(
      id: 'user_4',
      name: 'WaveRider',
      team: Team.blue,
      flipPoints: 2198,
      totalDistanceKm: 135.0,
      avatar: '🌊',
      crewName: 'Ocean Runners',
    ),
    LeaderboardRunner(
      id: 'user_5',
      name: 'ChaosAgent',
      team: Team.purple,
      flipPoints: 2156,
      totalDistanceKm: 68.2,
      avatar: '💀',
      crewName: 'Void Walkers',
    ),
    LeaderboardRunner(
      id: 'user_6',
      name: 'NightOwl',
      team: Team.red,
      flipPoints: 1987,
      totalDistanceKm: 128.4,
      avatar: '🦉',
      crewName: 'Night Runners',
    ),
    LeaderboardRunner(
      id: 'user_7',
      name: 'StormChaser',
      team: Team.blue,
      flipPoints: 1845,
      totalDistanceKm: 122.1,
      avatar: '⚡',
      crewName: 'Thunder Crew',
    ),
    LeaderboardRunner(
      id: 'user_8',
      name: 'VoidWalker',
      team: Team.purple,
      flipPoints: 1756,
      totalDistanceKm: 44.5,
      avatar: '🌀',
      crewName: 'Void Walkers',
    ),
    LeaderboardRunner(
      id: 'user_9',
      name: 'BlazeRunner',
      team: Team.red,
      flipPoints: 1634,
      totalDistanceKm: 115.7,
      avatar: '🌟',
      crewName: 'Blaze Squad',
    ),
    LeaderboardRunner(
      id: 'user_10',
      name: 'OceanSpirit',
      team: Team.blue,
      flipPoints: 1523,
      totalDistanceKm: 109.3,
      avatar: '🐋',
      crewName: 'Ocean Runners',
    ),
    LeaderboardRunner(
      id: 'user_11',
      name: 'PhoenixRise',
      team: Team.red,
      flipPoints: 1412,
      totalDistanceKm: 105.0,
      avatar: '🦅',
      crewName: 'Phoenix Squad',
    ),
    LeaderboardRunner(
      id: 'user_12',
      name: 'DeepDive',
      team: Team.blue,
      flipPoints: 1298,
      totalDistanceKm: 98.6,
      avatar: '🐙',
      crewName: 'Tidal Force',
    ),
    LeaderboardRunner(
      id: 'user_13',
      name: 'ShadowTraitor',
      team: Team.purple,
      flipPoints: 1245,
      totalDistanceKm: 32.1,
      avatar: '👁️',
      crewName: 'Shadow Protocol',
    ),
    LeaderboardRunner(
      id: 'user_14',
      name: 'SparkPlug',
      team: Team.red,
      flipPoints: 1156,
      totalDistanceKm: 95.2,
      avatar: '✨',
      crewName: 'Blaze Squad',
    ),
    LeaderboardRunner(
      id: 'user_15',
      name: 'TidalWave',
      team: Team.blue,
      flipPoints: 1087,
      totalDistanceKm: 92.1,
      avatar: '🌊',
      crewName: 'Thunder Crew',
    ),
  ];

  List<LeaderboardRunner> get _filteredRunners {
    var runners = List<LeaderboardRunner>.from(_allRunners);

    // Team filter
    if (_teamFilter != 'ALL') {
      final teamFilter = _teamFilter == 'RED'
          ? Team.red
          : _teamFilter == 'BLUE'
          ? Team.blue
          : Team.purple;
      runners = runners.where((r) => r.team == teamFilter).toList();
    }

    // Scope filter (mock: reduce list for City/Zone)
    // In production, this queries different geographic scopes via Supabase
    if (_scopeFilter == 'CITY') {
      runners = runners.take(10).toList();
    } else if (_scopeFilter == 'ZONE') {
      runners = runners.take(6).toList();
    }

    return runners;
  }

  /// Check if current user is visible in the displayed list
  bool get _isCurrentUserVisible {
    return _filteredRunners.any((r) => r.id == _currentUserId);
  }

  /// Get current user's rank (1-based)
  int get _currentUserRank {
    final allRanked = _filteredRunners;
    final index = allRanked.indexWhere((r) => r.id == _currentUserId);
    return index >= 0 ? index + 1 : -1;
  }

  /// Get current user's data
  LeaderboardRunner? get _currentUserData {
    try {
      return _allRunners.firstWhere((r) => r.id == _currentUserId);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final runners = _filteredRunners;

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildTeamFilterTabs(),
              const SizedBox(height: 12),
              _buildScopeFilterTabs(),
              const SizedBox(height: 20),
              Expanded(
                child: runners.isEmpty
                    ? _buildEmptyState()
                    : CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          // Top 3 Podium
                          if (runners.isNotEmpty)
                            SliverToBoxAdapter(child: _buildPodium(runners)),
                          // Divider
                          if (runners.length > 3)
                            SliverToBoxAdapter(child: _buildDivider()),
                          // Rank List (4th onwards)
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final listIndex = index + 3;
                                  if (listIndex >= runners.length) return null;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _buildRankTile(
                                      runners[listIndex],
                                      listIndex + 1,
                                    ),
                                  );
                                },
                                childCount: runners.length > 3
                                    ? runners.length - 3
                                    : 0,
                              ),
                            ),
                          ),
                          // Bottom spacing for sticky footer
                          const SliverToBoxAdapter(child: SizedBox(height: 80)),
                        ],
                      ),
              ),

              // Sticky Footer: My Rank (when user outside visible list)
              if (!_isCurrentUserVisible && _currentUserData != null)
                _buildMyRankFooter(),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Ranked by flip points',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Icon(
              Icons.insights_rounded,
              color: AppTheme.electricBlue,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TEAM FILTER TABS: [ALL] / [FLAME] / [WAVE] / [CHAOS]
  // ---------------------------------------------------------------------------

  Widget _buildTeamFilterTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          _buildTeamTab('ALL', 'ALL', null),
          _buildTeamTab('FLAME', 'RED', Team.red),
          _buildTeamTab('WAVE', 'BLUE', Team.blue),
          _buildTeamTab('CHAOS', 'PURPLE', Team.purple),
        ],
      ),
    );
  }

  Widget _buildTeamTab(String label, String value, Team? team) {
    final isSelected = _teamFilter == value;
    final Color activeColor = team?.color ?? Colors.white;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _teamFilter = value),
        child: AnimatedContainer(
          duration: AppTheme.fastDuration,
          curve: AppTheme.defaultCurve,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: activeColor.withOpacity(0.3))
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isSelected ? activeColor : AppTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SCOPE FILTER TABS: [ALL] / [City] / [Zone]
  // ---------------------------------------------------------------------------

  Widget _buildScopeFilterTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _buildScopeChip('ALL', 'ALL'),
          const SizedBox(width: 8),
          _buildScopeChip('City', 'CITY'),
          const SizedBox(width: 8),
          _buildScopeChip('Zone', 'ZONE'),
          const Spacer(),
          // Runner count
          Text(
            '${_filteredRunners.length} runners',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white24,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeChip(String label, String value) {
    final isSelected = _scopeFilter == value;

    return GestureDetector(
      onTap: () => setState(() => _scopeFilter = value),
      child: AnimatedContainer(
        duration: AppTheme.fastDuration,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.white.withOpacity(0.2)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: isSelected ? Colors.white : Colors.white38,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PODIUM (Top 3)
  // ---------------------------------------------------------------------------

  Widget _buildPodium(List<LeaderboardRunner> runners) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: SizedBox(
        height: 250,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 2nd Place
            if (runners.length > 1)
              Expanded(child: _buildPodiumCard(runners[1], 2))
            else
              const Expanded(child: SizedBox()),

            const SizedBox(width: 10),

            // 1st Place
            Expanded(flex: 1, child: _buildPodiumCard(runners[0], 1)),

            const SizedBox(width: 10),

            // 3rd Place
            if (runners.length > 2)
              Expanded(child: _buildPodiumCard(runners[2], 3))
            else
              const Expanded(child: SizedBox()),
          ],
        ),
      ),
    );
  }

  Widget _buildPodiumCard(LeaderboardRunner runner, int rank) {
    final isFirst = rank == 1;
    final isPurple = runner.team == Team.purple;
    final showPurpleGlow = isPurple && _teamFilter == 'ALL';
    final teamColor = runner.team.color;

    final medalColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
        ? const Color(0xFFC0C0C0)
        : const Color(0xFFCD7F32);

    final cardHeight = isFirst ? 230.0 : (rank == 2 ? 200.0 : 180.0);

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseOpacity = showPurpleGlow
            ? 0.3 + (_pulseController.value * 0.2)
            : 0.0;

        return Container(
          height: cardHeight,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: showPurpleGlow
                  ? teamColor.withOpacity(0.6)
                  : teamColor.withOpacity(isFirst ? 0.4 : 0.2),
              width: showPurpleGlow ? 2 : (isFirst ? 1.5 : 1),
            ),
            boxShadow: [
              if (showPurpleGlow)
                BoxShadow(
                  color: teamColor.withOpacity(pulseOpacity),
                  blurRadius: 24,
                  spreadRadius: -4,
                ),
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Medal Badge
              Container(
                width: isFirst ? 34 : 26,
                height: isFirst ? 34 : 26,
                decoration: BoxDecoration(
                  color: medalColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: medalColor.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: GoogleFonts.sora(
                      fontSize: isFirst ? 15 : 11,
                      fontWeight: FontWeight.w700,
                      color: medalColor,
                    ),
                  ),
                ),
              ),

              SizedBox(height: isFirst ? 10 : 6),

              // Avatar
              Container(
                width: isFirst ? 52 : 42,
                height: isFirst ? 52 : 42,
                decoration: BoxDecoration(
                  color: teamColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: teamColor.withOpacity(0.4),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    runner.avatar,
                    style: TextStyle(fontSize: isFirst ? 22 : 17),
                  ),
                ),
              ),

              SizedBox(height: isFirst ? 10 : 6),

              // Name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  runner.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: isFirst ? 13 : 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 2),

              // Crew Name
              if (runner.crewName != null)
                Text(
                  runner.crewName!,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: teamColor.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),

              SizedBox(height: isFirst ? 8 : 4),

              // Flip Points
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: teamColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${runner.flipPoints} pts',
                  style: GoogleFonts.sora(
                    fontSize: isFirst ? 13 : 10,
                    fontWeight: FontWeight.w700,
                    color: teamColor,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // RANK LIST (4th+)
  // ---------------------------------------------------------------------------

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(height: 1, color: Colors.white.withOpacity(0.05)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'ALL RUNNERS',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white24,
                letterSpacing: 2.0,
              ),
            ),
          ),
          Expanded(
            child: Container(height: 1, color: Colors.white.withOpacity(0.05)),
          ),
        ],
      ),
    );
  }

  Widget _buildRankTile(LeaderboardRunner runner, int rank) {
    final isCurrentUser = runner.id == _currentUserId;
    final isPurple = runner.team == Team.purple;
    final showPurpleGlow = isPurple && _teamFilter == 'ALL';
    final teamColor = runner.team.color;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseOpacity = showPurpleGlow
            ? 0.08 + (_pulseController.value * 0.08)
            : 0.0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isCurrentUser
                ? teamColor.withOpacity(0.08)
                : AppTheme.surfaceColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: showPurpleGlow
                  ? teamColor.withOpacity(0.4)
                  : isCurrentUser
                  ? teamColor.withOpacity(0.3)
                  : Colors.white.withOpacity(0.05),
              width: showPurpleGlow ? 1.5 : 1,
            ),
            boxShadow: showPurpleGlow
                ? [
                    BoxShadow(
                      color: teamColor.withOpacity(pulseOpacity),
                      blurRadius: 16,
                      spreadRadius: -4,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Rank Number
              SizedBox(
                width: 30,
                child: Text(
                  '$rank',
                  style: GoogleFonts.sora(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isCurrentUser ? teamColor : Colors.white38,
                  ),
                ),
              ),

              // Team Color Bar
              Container(
                width: 3,
                height: 30,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: teamColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Avatar
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: teamColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: teamColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    runner.avatar,
                    style: const TextStyle(fontSize: 17),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Name & Crew
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            runner.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (isCurrentUser) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: teamColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'YOU',
                              style: GoogleFonts.inter(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: teamColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      runner.crewName ?? 'No Crew',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: teamColor.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Flip Points
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${runner.flipPoints}',
                    style: GoogleFonts.sora(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isCurrentUser ? teamColor : Colors.white,
                    ),
                  ),
                  Text(
                    'pts',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.white38,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // STICKY FOOTER: MY RANK
  // ---------------------------------------------------------------------------

  Widget _buildMyRankFooter() {
    final user = _currentUserData!;
    final teamColor = user.team.color;
    final rank = _currentUserRank;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          top: BorderSide(color: teamColor.withOpacity(0.2), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Rank
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: teamColor.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: teamColor.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  rank > 0 ? '#$rank' : '—',
                  style: GoogleFonts.sora(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: teamColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Avatar
            Text(user.avatar, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),

            // Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        user.name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: teamColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          'YOU',
                          style: GoogleFonts.inter(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: teamColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    user.crewName ?? 'No Crew',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Points
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${user.flipPoints}',
                  style: GoogleFonts.sora(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: teamColor,
                  ),
                ),
                Text(
                  'pts',
                  style: GoogleFonts.inter(fontSize: 10, color: Colors.white38),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EMPTY STATE
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.1),
          ),
          const SizedBox(height: 16),
          Text(
            'No runners found',
            style: GoogleFonts.inter(fontSize: 16, color: Colors.white38),
          ),
          const SizedBox(height: 8),
          Text(
            'Start running to appear on the leaderboard',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white24),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DATA MODEL
// ---------------------------------------------------------------------------

/// Leaderboard runner data model
/// Ranked by flipPoints (season cumulative Flip Points)
/// In production: fetched via Supabase RPC get_leaderboard()
class LeaderboardRunner {
  final String id;
  final String name;
  final Team team;
  final int flipPoints;
  final double totalDistanceKm;
  final String avatar; // Emoji avatar (overridden by crew image when in crew)
  final String? crewName;

  const LeaderboardRunner({
    required this.id,
    required this.name,
    required this.team,
    required this.flipPoints,
    required this.totalDistanceKm,
    required this.avatar,
    this.crewName,
  });
}
