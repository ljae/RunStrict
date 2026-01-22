import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/team.dart';

/// Leaderboard Screen - Season Rankings by Flip Points
/// Displays runners ranked by flip points (not distance)
/// Shows: name, total distance, sponsor (avatar), crew, team color
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  String _filter = 'ALL';
  late AnimationController _pulseController;

  // Mock current user ID for highlighting
  static const String _currentUserId = 'user_1';

  // Mock Data - In production, fetch from Firestore and sort by flipPoints
  final List<LeaderboardRunner> _allRunners = [
    LeaderboardRunner(
      id: 'user_1',
      name: 'SpeedKing',
      team: Team.red,
      flipPoints: 2847,
      totalDistanceKm: 154.2,
      sponsor: '🦊',
      crewName: 'Phoenix Squad',
    ),
    LeaderboardRunner(
      id: 'user_2',
      name: 'AquaDash',
      team: Team.blue,
      flipPoints: 2654,
      totalDistanceKm: 148.5,
      sponsor: '🐬',
      crewName: 'Tidal Force',
    ),
    LeaderboardRunner(
      id: 'user_3',
      name: 'CrimsonBlur',
      team: Team.red,
      flipPoints: 2412,
      totalDistanceKm: 142.8,
      sponsor: '🔥',
      crewName: 'Phoenix Squad',
    ),
    LeaderboardRunner(
      id: 'user_4',
      name: 'WaveRider',
      team: Team.blue,
      flipPoints: 2198,
      totalDistanceKm: 135.0,
      sponsor: '🌊',
      crewName: 'Ocean Runners',
    ),
    LeaderboardRunner(
      id: 'user_5',
      name: 'ChaosAgent',
      team: Team.purple,
      flipPoints: 2156,
      totalDistanceKm: 68.2,
      sponsor: '💀',
      crewName: 'Void Walkers',
    ),
    LeaderboardRunner(
      id: 'user_6',
      name: 'NightOwl',
      team: Team.red,
      flipPoints: 1987,
      totalDistanceKm: 128.4,
      sponsor: '🦉',
      crewName: 'Night Runners',
    ),
    LeaderboardRunner(
      id: 'user_7',
      name: 'StormChaser',
      team: Team.blue,
      flipPoints: 1845,
      totalDistanceKm: 122.1,
      sponsor: '⚡',
      crewName: 'Thunder Crew',
    ),
    LeaderboardRunner(
      id: 'user_8',
      name: 'VoidWalker',
      team: Team.purple,
      flipPoints: 1756,
      totalDistanceKm: 44.5,
      sponsor: '🌀',
      crewName: 'Void Walkers',
    ),
    LeaderboardRunner(
      id: 'user_9',
      name: 'BlazeRunner',
      team: Team.red,
      flipPoints: 1634,
      totalDistanceKm: 115.7,
      sponsor: '🌟',
      crewName: 'Blaze Squad',
    ),
    LeaderboardRunner(
      id: 'user_10',
      name: 'OceanSpirit',
      team: Team.blue,
      flipPoints: 1523,
      totalDistanceKm: 109.3,
      sponsor: '🐋',
      crewName: 'Ocean Runners',
    ),
    LeaderboardRunner(
      id: 'user_11',
      name: 'PhoenixRise',
      team: Team.red,
      flipPoints: 1412,
      totalDistanceKm: 105.0,
      sponsor: '🦅',
      crewName: 'Phoenix Squad',
    ),
    LeaderboardRunner(
      id: 'user_12',
      name: 'DeepDive',
      team: Team.blue,
      flipPoints: 1298,
      totalDistanceKm: 98.6,
      sponsor: '🐙',
      crewName: 'Tidal Force',
    ),
    LeaderboardRunner(
      id: 'user_13',
      name: 'ShadowTraitor',
      team: Team.purple,
      flipPoints: 1245,
      totalDistanceKm: 32.1,
      sponsor: '👁️',
      crewName: 'Shadow Protocol',
    ),
    LeaderboardRunner(
      id: 'user_14',
      name: 'SparkPlug',
      team: Team.red,
      flipPoints: 1156,
      totalDistanceKm: 95.2,
      sponsor: '✨',
      crewName: 'Blaze Squad',
    ),
    LeaderboardRunner(
      id: 'user_15',
      name: 'TidalWave',
      team: Team.blue,
      flipPoints: 1087,
      totalDistanceKm: 92.1,
      sponsor: '🌊',
      crewName: 'Thunder Crew',
    ),
  ];

  List<LeaderboardRunner> get _filteredRunners {
    if (_filter == 'ALL') return _allRunners;
    final teamFilter = _filter == 'RED'
        ? Team.red
        : _filter == 'BLUE'
            ? Team.blue
            : Team.purple;
    return _allRunners.where((r) => r.team == teamFilter).toList();
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
              const SizedBox(height: 20),
              _buildFilterTabs(),
              const SizedBox(height: 24),
              Expanded(
                child: runners.isEmpty
                    ? _buildEmptyState()
                    : CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          // Top 3 Podium
                          if (runners.length >= 1)
                            SliverToBoxAdapter(
                              child: _buildPodium(runners),
                            ),
                          // Divider
                          if (runners.length > 3)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        height: 1,
                                        color: Colors.white.withOpacity(0.05),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
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
                                      child: Container(
                                        height: 1,
                                        color: Colors.white.withOpacity(0.05),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
                          // Bottom spacing
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 100),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
                style: GoogleFonts.sora(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
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

  Widget _buildFilterTabs() {
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
          _buildTab('ALL', 'ALL', null),
          _buildTab('FLAME', 'RED', Team.red),
          _buildTab('WAVE', 'BLUE', Team.blue),
          _buildTab('CHAOS', 'PURPLE', Team.purple),
        ],
      ),
    );
  }

  Widget _buildTab(String label, String value, Team? team) {
    final isSelected = _filter == value;
    final Color activeColor = team?.color ?? Colors.white;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = value),
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

  Widget _buildPodium(List<LeaderboardRunner> runners) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: SizedBox(
        height: 260,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 2nd Place
            if (runners.length > 1)
              Expanded(child: _buildPodiumCard(runners[1], 2))
            else
              const Expanded(child: SizedBox()),

            const SizedBox(width: 12),

            // 1st Place
            Expanded(
              flex: 1,
              child: _buildPodiumCard(runners[0], 1),
            ),

            const SizedBox(width: 12),

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
    final teamColor = runner.team.color;

    // Medal colors
    final medalColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
            ? const Color(0xFFC0C0C0)
            : const Color(0xFFCD7F32);

    // Heights based on rank
    final cardHeight = isFirst ? 240.0 : (rank == 2 ? 210.0 : 190.0);

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseOpacity = isPurple
            ? 0.3 + (_pulseController.value * 0.2)
            : 0.0;

        return Container(
          height: cardHeight,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: teamColor.withOpacity(isFirst ? 0.5 : 0.3),
              width: isFirst ? 1.5 : 1,
            ),
            boxShadow: [
              if (isPurple)
                BoxShadow(
                  color: teamColor.withOpacity(pulseOpacity),
                  blurRadius: 20,
                  spreadRadius: -5,
                ),
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Medal/Rank Badge
              Container(
                width: isFirst ? 36 : 28,
                height: isFirst ? 36 : 28,
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
                      fontSize: isFirst ? 16 : 12,
                      fontWeight: FontWeight.w700,
                      color: medalColor,
                    ),
                  ),
                ),
              ),

              SizedBox(height: isFirst ? 12 : 8),

              // Sponsor Avatar
              Container(
                width: isFirst ? 56 : 44,
                height: isFirst ? 56 : 44,
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
                    runner.sponsor,
                    style: TextStyle(fontSize: isFirst ? 24 : 18),
                  ),
                ),
              ),

              SizedBox(height: isFirst ? 12 : 8),

              // Name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  runner.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: isFirst ? 14 : 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 2),

              // Crew Name
              Text(
                runner.crewName ?? 'No Crew',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: teamColor.withOpacity(0.8),
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
                    fontSize: isFirst ? 14 : 11,
                    fontWeight: FontWeight.w700,
                    color: teamColor,
                  ),
                ),
              ),

              if (isFirst) ...[
                const SizedBox(height: 4),
                Text(
                  '${runner.totalDistanceKm.toStringAsFixed(1)} km',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.white38,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRankTile(LeaderboardRunner runner, int rank) {
    final isCurrentUser = runner.id == _currentUserId;
    final isPurple = runner.team == Team.purple;
    final teamColor = runner.team.color;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseOpacity = isPurple ? 0.1 + (_pulseController.value * 0.1) : 0.0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isCurrentUser
                ? teamColor.withOpacity(0.08)
                : AppTheme.surfaceColor.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCurrentUser
                  ? teamColor.withOpacity(0.4)
                  : Colors.white.withOpacity(0.05),
            ),
            boxShadow: isPurple
                ? [
                    BoxShadow(
                      color: teamColor.withOpacity(pulseOpacity),
                      blurRadius: 15,
                      spreadRadius: -5,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Rank Number
              SizedBox(
                width: 32,
                child: Text(
                  '$rank',
                  style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isCurrentUser ? teamColor : Colors.white38,
                  ),
                ),
              ),

              // Team Color Indicator
              Container(
                width: 3,
                height: 32,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: teamColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Sponsor Avatar
              Container(
                width: 40,
                height: 40,
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
                    runner.sponsor,
                    style: const TextStyle(fontSize: 18),
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
                              color: isCurrentUser ? Colors.white : AppTheme.textPrimary,
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
                    Row(
                      children: [
                        Text(
                          runner.crewName ?? 'No Crew',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: teamColor.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          '${runner.totalDistanceKm.toStringAsFixed(1)} km',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white38,
                          ),
                        ),
                      ],
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
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.white38,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start running to appear on the leaderboard',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white24,
            ),
          ),
        ],
      ),
    );
  }
}

/// Data model for leaderboard runners
/// Ranked by flipPoints (not distance)
class LeaderboardRunner {
  final String id;
  final String name;
  final Team team;
  final int flipPoints;
  final double totalDistanceKm;
  final String sponsor; // Emoji avatar
  final String? crewName;

  const LeaderboardRunner({
    required this.id,
    required this.name,
    required this.team,
    required this.flipPoints,
    required this.totalDistanceKm,
    required this.sponsor,
    this.crewName,
  });
}
