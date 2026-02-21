import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../data/models/team.dart';
import '../../auth/providers/app_state_provider.dart';
import '../providers/team_stats_provider.dart';
import '../../../core/providers/user_repository_provider.dart';
import '../../../core/config/h3_config.dart';
import '../../../core/services/hex_service.dart';
import '../../../core/services/prefetch_service.dart';
import '../../../core/services/season_service.dart';
import '../../../core/services/sync_retry_service.dart';
import '../../../core/providers/points_provider.dart';
import '../../../theme/app_theme.dart';

class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key});

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isGuest = ref.read(appStateProvider).isGuest;
      if (!isGuest) _loadData();
    });
  }

  Future<void> _loadData() async {
    final user = ref.read(userRepositoryProvider);
    final userId = user?.id;
    final userTeam = user?.team.name;
    // Server data always uses home hex (Snapshot Domain)
    final cityHex = PrefetchService().homeHexCity;
    if (userId != null) {
      // Ensure pending runs are synced before reading server data.
      // This prevents yesterday's points from showing less than local SQLite.
      try {
        final syncedPoints = await SyncRetryService().retryUnsyncedRuns();
        if (syncedPoints > 0) {
          ref.read(pointsProvider.notifier).onRunSynced(syncedPoints);
          debugPrint('TeamScreen: Synced $syncedPoints pending points before load');
        }
      } catch (e) {
        debugPrint('TeamScreen: Sync retry failed: $e');
      }

      await ref.read(teamStatsProvider.notifier).loadTeamData(
        userId,
        cityHex: cityHex,
        userTeam: userTeam,
        userName: user?.name,
      );
      _syncTerritoryBalance();
    }
  }

  void _syncTerritoryBalance() {
    final stats = ref.read(teamStatsProvider);
    final dominance = stats.dominance;
    if (dominance == null) return;
    final total = dominance.allRange.total;
    if (total == 0) return;
    final red = (dominance.allRange.redHexCount / total) * 100;
    final blue = (dominance.allRange.blueHexCount / total) * 100;
    ref.read(appStateProvider.notifier).updateTerritoryBalance(red, blue);
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = ref.watch(appStateProvider.select((s) => s.isGuest));
    if (isGuest) return _buildGuestOverlay(context);

    final userTeam = ref.watch(userRepositoryProvider)?.team;
    final stats = ref.watch(teamStatsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Builder(
            builder: (context) {
              if (stats.isLoading) {
                return const Center(
                  child: CircularProgressIndicator.adaptive(),
                );
              }

              if (stats.error != null) {
                return _buildErrorState();
              }

              return RefreshIndicator(
                onRefresh: () async => _loadData(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. YESTERDAY - keep as is
                      _buildYesterdaySection(),
                      const SizedBox(height: 24),
                      // Purple team has its own flow
                      if (userTeam == Team.purple) ...[
                        _buildPurpleBuffSection(),
                      ] else ...[
                        // 2. TERRITORY
                        _buildTerritorySection(),
                        const SizedBox(height: 24),
                        // 3. YOUR BUFF - simplified (no breakdown pills)
                        _buildSimplifiedUserBuff(),
                        const SizedBox(height: 24),
                        // 4. FLAME RANKINGS - only for red team
                        if (userTeam == Team.red) ...[
                          _buildRankingsSection(userTeam),
                          const SizedBox(height: 24),
                        ],
                        // 5. BUFF COMPARISON - restored original
                        _buildBuffComparisonOnly(),
                        const SizedBox(height: 32),
                        _buildPurpleGateSection(userTeam!),
                      ],
                      const SizedBox(height: 40),
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

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loadData,
              child: Text(
                'RETRY',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.electricBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _yesterdayLabel() {
    // Show the actual server-timezone date being queried
    final stats = ref.read(teamStatsProvider).yesterdayStats;
    final date = stats?.date;
    final months = [
      '', 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    final dateStr = date != null
        ? '${months[date.month]} ${date.day}'
        : 'YESTERDAY';

    final season = SeasonService();
    final remaining = season.daysRemaining;
    final yesterdayDDay = remaining + 1;
    if (remaining >= 0 && yesterdayDDay <= SeasonService.seasonDurationDays) {
      return '$dateStr · D-$yesterdayDDay';
    }
    return dateStr;
  }

  Widget _buildYesterdaySection() {
    final stats = ref.read(teamStatsProvider).yesterdayStats;
    final hasData = stats?.hasData ?? false;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _yesterdayLabel(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white30,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          if (!hasData)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No runs yesterday',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${stats!.flipPoints ?? 0}',
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
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Flexible(
                          child: _buildMiniStat(
                            stats.distanceKm?.toStringAsFixed(1) ?? '--',
                            'km',
                          ),
                        ),
                        Flexible(
                          child: _buildMiniStat(
                            _formatPace(stats.avgPaceMinPerKm),
                            '/km',
                          ),
                        ),
                        Flexible(
                          child: stats.stabilityScore != null
                              ? _buildMiniStatColored(
                                  '${stats.stabilityScore}%',
                                  'stab',
                                  _getStabilityColor(stats.stabilityScore!),
                                )
                              : _buildMiniStat('--', 'stab'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTerritorySection() {
    final dominance = ref.read(teamStatsProvider).dominance;
    // Server data always uses home hex (Snapshot Domain)
    final homeHex = PrefetchService().homeHex;

    // Use deterministic hex-based naming (consistent across all users/seasons)
    final territoryName = homeHex != null
        ? HexService().getTerritoryName(homeHex)
        : (dominance?.territoryName ?? 'Unknown');
    final districtNumber = homeHex != null
        ? HexService().getCityNumber(homeHex)
        : (dominance?.districtNumber ?? 1);

    final provinceHexCount = H3Config.childrenPerParent(
      H3Config.baseResolution - H3Config.allResolution,
    );
    final districtHexCount = H3Config.childrenPerParent(
      H3Config.baseResolution - H3Config.cityResolution,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'TERRITORY',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white30,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
            _buildSnapshotBadge(),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTerritoryCard(
                territoryName,
                _formatHexCount(provinceHexCount),
                dominance?.allRange,
                totalHexCount: provinceHexCount,
                isTerritory: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTerritoryCard(
                'District $districtNumber',
                _formatHexCount(districtHexCount),
                dominance?.cityRange,
                totalHexCount: districtHexCount,
                isTerritory: false,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatHexCount(int count) {
    if (count >= 1000) {
      final thousands = count ~/ 1000;
      final remainder = count % 1000;
      return '$thousands,${remainder.toString().padLeft(3, '0')} hexes';
    }
    return '$count hexes';
  }

  /// Badge showing data is from yesterday's snapshot
  Widget _buildSnapshotBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule,
            size: 10,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(width: 3),
          Text(
            "Yesterday's snapshot",
            style: GoogleFonts.inter(
              fontSize: 8,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerritoryCard(
    String title,
    String subtitle,
    HexDominanceScope? scope, {
    required int totalHexCount,
    required bool isTerritory,
  }) {
    final redCount = scope?.redHexCount ?? 0;
    final blueCount = scope?.blueHexCount ?? 0;
    final purpleCount = scope?.purpleHexCount ?? 0;
    final claimed = redCount + blueCount + purpleCount;
    final unclaimed = (totalHexCount - claimed).clamp(0, totalHexCount);

    return _buildCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title: Territory name or District number
          Text(
            title,
            style: GoogleFonts.sora(
              fontSize: isTerritory ? 16 : 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Subtitle: hex count
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
          ),
          const SizedBox(height: 14),
          // Progress bar (always show — unclaimed fills the rest)
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  if (redCount > 0)
                    Expanded(
                      flex: redCount,
                      child: Container(color: AppTheme.athleticRed),
                    ),
                  if (blueCount > 0)
                    Expanded(
                      flex: blueCount,
                      child: Container(color: AppTheme.electricBlue),
                    ),
                  if (purpleCount > 0)
                    Expanded(
                      flex: purpleCount,
                      child: Container(color: AppTheme.chaosPurple),
                    ),
                  if (unclaimed > 0)
                    Expanded(
                      flex: unclaimed,
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Team counts
          if (claimed > 0)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTeamCount(redCount, AppTheme.athleticRed),
                  const SizedBox(width: 10),
                  _buildTeamCount(blueCount, AppTheme.electricBlue),
                  const SizedBox(width: 10),
                  _buildTeamCount(purpleCount, AppTheme.chaosPurple),
                ],
              ),
            )
          else
            Center(
              child: Text(
                'No data',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white24),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTeamCount(int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: GoogleFonts.sora(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildRankingsSection(Team? userTeam) {
    final rankings = ref.read(teamStatsProvider).rankings;
    final teamName = userTeam?.displayName ?? 'TEAM';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$teamName RANKINGS',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white30,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
            _buildSnapshotBadge(),
          ],
        ),
        const SizedBox(height: 12),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (userTeam == Team.red) ...[
                // Show Elite top 3 only
                _buildRankingGroup(
                  'ELITE',
                  rankings?.redEliteTop3 ?? [],
                  AppTheme.athleticRed,
                ),
                // Elite cutline info (instead of Common's top 3)
                if (rankings != null) ...[
                  const SizedBox(height: 12),
                  _buildEliteCutlineInfo(rankings.eliteThreshold),
                ],
              ] else ...[
                Center(
                  child: Text(
                    'CHAOS has no rankings',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.chaosPurple.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
              if (rankings != null && userTeam != Team.purple) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (ref.read(teamStatsProvider).yesterdayStats?.hasData == true
                                ? userTeam?.color
                                : Colors.white)
                            ?.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          (ref.read(teamStatsProvider).yesterdayStats?.hasData == true
                                  ? userTeam?.color
                                  : Colors.white)
                              ?.withValues(alpha: 0.2) ??
                          Colors.white12,
                    ),
                  ),
                  child: rankings.userRank > 0
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Your rank: ',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                            Text(
                              '#${rankings.userRank}',
                              style: GoogleFonts.sora(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: userTeam?.color ?? Colors.white,
                              ),
                            ),
                            if (rankings.userIsElite && userTeam == Team.red)
                              Text(
                                ' in Elite',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                          ],
                        )
                      : Text(
                          'No record yesterday',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Shows Elite threshold cutline (top 20% requirement)
  Widget _buildEliteCutlineInfo(int threshold) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.trending_up,
            size: 14,
            color: AppTheme.athleticRed.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 6),
          Text(
            'Top 20% = Elite',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '(≥$threshold pts)',
            style: GoogleFonts.sora(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.athleticRed.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingGroup(
    String title,
    List<RankingEntry> entries,
    Color accentColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.bebasNeue(
            fontSize: 12,
            color: accentColor,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          Text(
            'No entries',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          )
        else
          ...entries.map((entry) => _buildRankingEntry(entry, accentColor)),
      ],
    );
  }

  Widget _buildRankingEntry(RankingEntry entry, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '#${entry.rank}',
              style: GoogleFonts.sora(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: accentColor.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.name,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${entry.yesterdayPoints}',
            style: GoogleFonts.sora(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          Text(
            ' pts',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  /// Simplified user buff - just the big multiplier, no breakdown pills
  Widget _buildSimplifiedUserBuff() {
    final userTeam = ref.read(userRepositoryProvider)?.team;
    final comparison = ref.read(teamStatsProvider).buffComparison;

    if (comparison == null) {
      return const SizedBox.shrink();
    }

    final teamColor = userTeam?.color ?? Colors.white;

    return _buildCard(
      child: Column(
        children: [
          Text(
            'YOUR BUFF',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white30,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${comparison.userTotalMultiplier}',
                style: GoogleFonts.sora(
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  color: teamColor,
                  height: 1.0,
                ),
              ),
              Text(
                'x',
                style: GoogleFonts.sora(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: teamColor.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Buff comparison only (VS structure without Your Buff section)
  Widget _buildBuffComparisonOnly() {
    final userTeam = ref.read(userRepositoryProvider)?.team;
    final tsState = ref.read(teamStatsProvider);
    final comparison = tsState.buffComparison;
    final dominance = tsState.dominance;

    if (comparison == null) {
      return const SizedBox.shrink();
    }

    // Determine territory winners from server dominance data (midnight snapshot).
    // dominantTeam returns null on ties, so no team gets a false win badge.
    final provinceDominant = dominance?.allRange.dominantTeam;
    final provinceWinner = provinceDominant == 'red'
        ? Team.red
        : provinceDominant == 'blue'
        ? Team.blue
        : null;

    final districtDominant = dominance?.cityRange?.dominantTeam;
    final districtWinner = districtDominant == 'red'
        ? Team.red
        : districtDominant == 'blue'
        ? Team.blue
        : null;

    // Left side team (user's team)
    final leftTeam = userTeam == Team.red ? Team.red : Team.blue;
    // Right side team (opponent)
    final rightTeam = userTeam == Team.red ? Team.blue : Team.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BUFF COMPARISON',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white30,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        // Split screen: User's team on LEFT, opponent on RIGHT
        // IntrinsicHeight ensures both panels have equal height
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // LEFT SIDE - User's team with badges
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: userTeam == Team.red
                          ? _buildRedTeamBuffPanel(comparison, isUserTeam: true)
                          : _buildBlueTeamBuffPanel(
                              comparison,
                              isUserTeam: true,
                            ),
                    ),
                    const SizedBox(height: 8),
                    // Territory badges for left team
                    _buildTeamTerritoryBadges(
                      team: leftTeam,
                      hasProvinceWin: provinceWinner == leftTeam,
                      hasDistrictWin: districtWinner == leftTeam,
                      dominance: dominance,
                    ),
                  ],
                ),
              ),
              // Center divider with VS
              _buildVsDivider(),
              // RIGHT SIDE - Opponent team with badges
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: userTeam == Team.red
                          ? _buildBlueTeamBuffPanel(
                              comparison,
                              isUserTeam: false,
                            )
                          : _buildRedTeamBuffPanel(
                              comparison,
                              isUserTeam: false,
                            ),
                    ),
                    const SizedBox(height: 8),
                    // Territory badges for right team
                    _buildTeamTerritoryBadges(
                      team: rightTeam,
                      hasProvinceWin: provinceWinner == rightTeam,
                      hasDistrictWin: districtWinner == rightTeam,
                      dominance: dominance,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Territory badges for buff calculation understanding
  Widget _buildTeamTerritoryBadges({
    required Team team,
    required bool hasProvinceWin,
    required bool hasDistrictWin,
    HexDominance? dominance,
  }) {
    final teamColor = team.color;

    // If no wins, show empty placeholder for alignment
    if (!hasProvinceWin && !hasDistrictWin) {
      return const SizedBox(height: 24);
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: [
        if (hasDistrictWin)
          _buildBuffBadge(
            label: 'Dist.',
            bonus: '+1',
            color: teamColor,
            icon: Icons.location_city_outlined,
          ),
        if (hasProvinceWin)
          _buildBuffBadge(
            label: 'Prov.',
            bonus: '+1',
            color: teamColor,
            icon: Icons.public_outlined,
          ),
      ],
    );
  }

  /// Small badge showing buff bonus from territory
  Widget _buildBuffBadge({
    required String label,
    required String bonus,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color.withValues(alpha: 0.8)),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            bonus,
            style: GoogleFonts.sora(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Red team buff panel showing Elite/Common tiers with CURRENT values
  Widget _buildRedTeamBuffPanel(
    TeamBuffComparison comparison, {
    required bool isUserTeam,
  }) {
    final redBuff = comparison.redBuff;

    return _buildCard(
      child: Column(
        children: [
          // Team header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isUserTeam)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: const BoxDecoration(
                    color: AppTheme.athleticRed,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                'FLAME',
                style: GoogleFonts.bebasNeue(
                  fontSize: 18,
                  color: AppTheme.athleticRed,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // City runner stats - show total runners and elite cutline
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.athleticRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.group,
                      size: 12,
                      color: AppTheme.athleticRed.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${redBuff.redRunnerCountCity}',
                      style: GoogleFonts.sora(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.athleticRed,
                      ),
                    ),
                    Text(
                      ' in City',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Top ${redBuff.eliteCutoffRank} = Elite',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.athleticRed.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ELITE tier card - show current elite multiplier
          _buildCurrentTierCard(
            tierName: 'ELITE',
            currentMultiplier: redBuff.eliteMultiplier,
            isActive: redBuff.isElite && isUserTeam,
            description: 'Top 20% daily',
            color: AppTheme.athleticRed,
            icon: Icons.stars_rounded,
          ),
          const SizedBox(height: 8),
          // COMMON tier card - always 1x
          _buildCurrentTierCard(
            tierName: 'COMMON',
            currentMultiplier: redBuff.commonMultiplier,
            isActive: !redBuff.isElite && isUserTeam,
            description: 'Base tier',
            color: !redBuff.isElite && isUserTeam
                ? AppTheme.athleticRed
                : Colors.white.withValues(alpha: 0.5),
            icon: Icons.person_outline,
          ),
        ],
      ),
    );
  }

  /// Blue team buff panel showing Union system with CURRENT value
  Widget _buildBlueTeamBuffPanel(
    TeamBuffComparison comparison, {
    required bool isUserTeam,
  }) {
    final blueMultiplier = comparison.blueUnionMultiplier;

    return _buildCard(
      child: Column(
        children: [
          // Team header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isUserTeam)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: const BoxDecoration(
                    color: AppTheme.electricBlue,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                'WAVE',
                style: GoogleFonts.bebasNeue(
                  fontSize: 18,
                  color: AppTheme.electricBlue,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // UNION - single tier with current value
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isUserTeam
                  ? AppTheme.electricBlue.withValues(alpha: 0.12)
                  : AppTheme.electricBlue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isUserTeam
                    ? AppTheme.electricBlue.withValues(alpha: 0.3)
                    : AppTheme.electricBlue.withValues(alpha: 0.1),
                width: isUserTeam ? 1.5 : 0.5,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people,
                      size: 14,
                      color: AppTheme.electricBlue.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'UNION',
                      style: GoogleFonts.bebasNeue(
                        fontSize: 14,
                        color: AppTheme.electricBlue,
                        letterSpacing: 2,
                      ),
                    ),
                    if (isUserTeam) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.electricBlue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          'YOU',
                          style: GoogleFonts.inter(
                            fontSize: 7,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.electricBlue,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                // Current multiplier - big display
                Text(
                  '${blueMultiplier}x',
                  style: GoogleFonts.sora(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: isUserTeam
                        ? AppTheme.electricBlue
                        : AppTheme.electricBlue.withValues(alpha: 0.6),
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 10),
                // Description
                Text(
                  'Equal for all',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Equality message
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.balance,
                size: 12,
                color: Colors.white.withValues(alpha: 0.25),
              ),
              const SizedBox(width: 4),
              Text(
                'No hierarchy',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.25),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Single tier card with current multiplier value
  Widget _buildCurrentTierCard({
    required String tierName,
    required int currentMultiplier,
    required bool isActive,
    required String description,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isActive
            ? color.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? color.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.05),
          width: isActive ? 1.5 : 0.5,
        ),
      ),
      child: Row(
        children: [
          // Tier icon
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isActive
                  ? color.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 16,
                color: isActive ? color : Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Tier info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        tierName,
                        style: GoogleFonts.bebasNeue(
                          fontSize: 12,
                          color: isActive
                              ? color
                              : Colors.white.withValues(alpha: 0.4),
                          letterSpacing: 1.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          'YOU',
                          style: GoogleFonts.inter(
                            fontSize: 6,
                            fontWeight: FontWeight.w700,
                            color: color,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Current multiplier
          Text(
            '${currentMultiplier}x',
            style: GoogleFonts.sora(
              fontSize: isActive ? 20 : 16,
              fontWeight: FontWeight.w700,
              color: isActive ? color : Colors.white.withValues(alpha: 0.35),
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVsDivider() {
    return Container(
      width: 32,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 1,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.1),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Text(
              'VS',
              style: GoogleFonts.bebasNeue(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.25),
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 1,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.1),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurpleBuffSection() {
    final participation = ref.read(teamStatsProvider).purpleParticipation;
    final percent = participation?.participationPercent ?? 0;
    final runnersRan = participation?.runnersRanYesterday ?? 0;
    final totalPurple = participation?.totalPurpleInCity ?? 0;

    // Calculate buff multiplier based on participation rate
    // 0-29% = 1x, 30-59% = 2x, 60-100% = 3x
    final buffMultiplier = _calculatePurpleBuff(percent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'RAN YESTERDAY',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white30,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
            _buildSnapshotBadge(),
          ],
        ),
        const SizedBox(height: 12),
        _buildCard(
          child: Column(
            children: [
              // Big percentage display
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$percent',
                    style: GoogleFonts.sora(
                      fontSize: 64,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.chaosPurple,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    '%',
                    style: GoogleFonts.sora(
                      fontSize: 32,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.chaosPurple.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Runner count breakdown
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.chaosPurple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.chaosPurple.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.directions_run,
                      size: 16,
                      color: AppTheme.chaosPurple.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$runnersRan',
                      style: GoogleFonts.sora(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.chaosPurple,
                      ),
                    ),
                    Text(
                      ' / $totalPurple',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    Text(
                      ' CHAOS in district',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Progress bar with tier markers
              _buildParticipationProgressBar(percent),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // YOUR BUFF section
        Text(
          'YOUR BUFF',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white30,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        _buildCard(
          child: Column(
            children: [
              // Big multiplier display
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$buffMultiplier',
                    style: GoogleFonts.sora(
                      fontSize: 56,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.chaosPurple,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    'x',
                    style: GoogleFonts.sora(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.chaosPurple.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Buff breakdown pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.chaosPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.chaosPurple.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.groups,
                      size: 14,
                      color: AppTheme.chaosPurple.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Participation',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${buffMultiplier}x',
                      style: GoogleFonts.sora(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.chaosPurple,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Motivational message
              Text(
                _getParticipationMessage(percent),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.4),
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Returns a motivational message based on participation percentage
  String _getParticipationMessage(int percent) {
    if (percent >= 80) return 'CHAOS runs strong.';
    if (percent >= 60) return 'The movement grows.';
    if (percent >= 40) return 'We answer to no one.';
    if (percent >= 20) return 'Every run counts.';
    return 'The path awaits.';
  }

  /// Calculate purple buff multiplier based on participation rate
  /// 0-29% = 1x, 30-59% = 2x, 60-100% = 3x
  int _calculatePurpleBuff(int percent) {
    if (percent >= 60) return 3;
    if (percent >= 30) return 2;
    return 1;
  }

  /// Progress bar with tier markers for purple participation
  Widget _buildParticipationProgressBar(int percent) {
    return Column(
      children: [
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            width: double.infinity,
            child: Stack(
              children: [
                // Background with tier sections
                Row(
                  children: [
                    Expanded(
                      flex: 30,
                      child: Container(
                        color: AppTheme.chaosPurple.withValues(alpha: 0.1),
                      ),
                    ),
                    Container(width: 1, color: Colors.white24),
                    Expanded(
                      flex: 30,
                      child: Container(
                        color: AppTheme.chaosPurple.withValues(alpha: 0.15),
                      ),
                    ),
                    Container(width: 1, color: Colors.white24),
                    Expanded(
                      flex: 40,
                      child: Container(
                        color: AppTheme.chaosPurple.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
                // Filled portion
                FractionallySizedBox(
                  widthFactor: (percent / 100).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.chaosPurple.withValues(alpha: 0.8),
                          AppTheme.chaosPurple,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Tier labels
        Row(
          children: [
            Expanded(
              flex: 30,
              child: Center(
                child: Text(
                  '1x',
                  style: GoogleFonts.sora(
                    fontSize: 10,
                    fontWeight: percent < 30
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: percent < 30
                        ? AppTheme.chaosPurple
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 30,
              child: Center(
                child: Text(
                  '2x',
                  style: GoogleFonts.sora(
                    fontSize: 10,
                    fontWeight: percent >= 30 && percent < 60
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: percent >= 30 && percent < 60
                        ? AppTheme.chaosPurple
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 40,
              child: Center(
                child: Text(
                  '3x',
                  style: GoogleFonts.sora(
                    fontSize: 10,
                    fontWeight: percent >= 60
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: percent >= 60
                        ? AppTheme.chaosPurple
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPurpleGateSection(Team userTeam) {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              context.push('/traitor-gate');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.chaosPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.chaosPurple.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'CHAOS AWAITS',
                style: GoogleFonts.bebasNeue(
                  fontSize: 18,
                  color: AppTheme.chaosPurple,
                  letterSpacing: 3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No return to ${userTeam.displayName}',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
        ],
      ),
    );
  }

  /// Container styled to match run_history_screen ALL TIME panel
  Widget _buildCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: child,
    );
  }

  Widget _buildMiniStat(String value, String label) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10, color: Colors.white30),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatColored(String value, String label, Color valueColor) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: valueColor,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10, color: Colors.white30),
          ),
        ],
      ),
    );
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
                'Sign up to track team stats and compete',
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

  String _formatPace(double? pace) {
    if (pace == null) return "-'--";
    final minutes = pace.floor();
    final seconds = ((pace - minutes) * 60).round();
    return "$minutes'${seconds.toString().padLeft(2, '0')}";
  }

  Color _getStabilityColor(int stability) {
    if (stability >= 80) return const Color(0xFF22C55E);
    if (stability >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}
